defmodule BotTrader.Runner do
  @moduledoc """
  Daily pipeline orchestration: state load → market data → indicators →
  LLM signals → risk-checked paper orders → persistence → report →
  Telegram notifications. Run-and-exit, dependencies injectable.
  """

  alias BotTrader.{Config, LLM, MarketData, Portfolio, Research, Risk, State}
  alias BotTrader.Portfolio.Position

  def run(deps \\ %{}) do
    state_dir = deps[:state_dir] || Config.state_dir()
    date = deps[:date] || Date.utc_today()

    with {:ok, portfolio, trades, snapshots} <- load_state(state_dir),
         {:ok, watchlist} <- load_watchlist(deps) do
      portfolio = Portfolio.new_day(portfolio, date)

      signals = analyze_all(watchlist, portfolio, deps, date, [])

      stop_loss_orders =
        Risk.stop_loss_candidates(portfolio, last_prices(signals))
        |> Enum.map(fn {symbol, price} ->
          %{type: :close, symbol: symbol, price: price, reason: :stop_loss}
        end)

      signal_orders =
        Enum.flat_map(signals, fn signal ->
          case signal.effective do
            :buy ->
              [
                %{
                  type: :buy,
                  symbol: signal.symbol,
                  asset_class: signal.asset_class,
                  notional: signal.target_weight * portfolio.cash,
                  price: signal.last_close
                }
              ]

            action when action in [:sell, :close] ->
              [
                %{
                  type: :close,
                  symbol: signal.symbol,
                  asset_class: signal.asset_class,
                  price: signal.last_close,
                  reason: :signal
                }
              ]

            :hold ->
              []
          end
        end)

      orders = stop_loss_orders ++ signal_orders

      {portfolio, executed_trades} =
        Enum.reduce(orders, {portfolio, []}, fn order, {port, acc} ->
          with :ok <- Risk.precheck(port, order),
               {:ok, port, trade} <- Portfolio.apply(port, order) do
            {port, [trade | acc]}
          else
            _ -> {port, acc}
          end
        end)

      executed_trades = Enum.reverse(executed_trades)

      equity =
        portfolio.cash +
          Enum.reduce(signals, 0.0, fn signal, acc ->
            acc + position_value(portfolio, signal)
          end)

      snapshot = %{
        date: Date.to_iso8601(date),
        equity: equity,
        cash: portfolio.cash,
        realized_pnl: portfolio.realized_pnl
      }

      with :ok <- State.write(state_dir, :portfolio, portfolio_to_map(portfolio)),
           :ok <- State.write(state_dir, :trades, Enum.map(trades, & &1) ++ executed_trades),
           :ok <- State.write(state_dir, :snapshots, snapshots ++ [snapshot]) do
        report =
          BotTrader.Report.build(date, watchlist, signals, executed_trades, portfolio, equity)

        BotTrader.Report.write(state_dir, date, report)

        telegram = deps[:telegram] || (&BotTrader.Telegram.send_message/1)

        Enum.each(executed_trades, fn trade ->
          telegram.(
            BotTrader.Telegram.format_trade_announcement(trade, %{
              cash: portfolio.cash,
              positions: length(portfolio.positions)
            })
          )
        end)

        days_remaining = max(0, Config.gate_days() - length(snapshots) - 1)

        digest =
          BotTrader.Telegram.format_digest(%{
            pnl_today:
              Enum.reduce(executed_trades, 0.0, fn trade, acc ->
                acc + (trade[:realized_pnl] || 0.0)
              end),
            positions: Enum.map(portfolio.positions, & &1.symbol),
            risk_status: "OK",
            days_remaining: days_remaining
          })

        telegram.(
          if days_remaining == 0 do
            metrics =
              BotTrader.Evaluation.evaluate(
                snapshots ++ [snapshot],
                Enum.map(trades, & &1) ++ executed_trades
              )

            verdict = BotTrader.Evaluation.verdict(metrics)
            digest <> "\n\n" <> BotTrader.Evaluation.verdict_message(verdict, metrics, false)
          else
            digest
          end
        )

        {:ok,
         %{
           trades_executed: length(executed_trades),
           symbols_without_data:
             Enum.flat_map(signals, fn s -> if s.last_close == nil, do: [s.symbol], else: [] end)
         }}
      end
    else
      {:error, reason} ->
        telegram = deps[:telegram] || (&BotTrader.Telegram.send_message/1)
        _ = telegram.(BotTrader.Telegram.format_failure_alert(reason))
        {:error, reason}
    end
  end

  defp load_state(state_dir) do
    with {:ok, portfolio_map} <- State.read(state_dir, :portfolio, %{}),
         {:ok, trades} <- State.read(state_dir, :trades, []),
         {:ok, snapshots} <- State.read(state_dir, :snapshots, []) do
      {:ok, portfolio_from_map(portfolio_map), trades, snapshots}
    end
  end

  defp load_watchlist(%{watchlist: watchlist}) when is_list(watchlist), do: {:ok, watchlist}

  defp load_watchlist(_deps) do
    with {:ok, body} <- File.read(Config.watchlist_path()),
         {:ok, json} <- Jason.decode(body) do
      entries = json["symbols"] || []

      {:ok,
       Enum.map(entries, fn entry ->
         %{
           symbol: entry["symbol"],
           asset_class: asset_class_atom(entry["asset_class"]),
           coin_id: entry["coin_id"]
         }
       end)}
    else
      _ -> {:error, :watchlist_not_found}
    end
  end

  defp asset_class_atom("stock-br"), do: :stock_br
  defp asset_class_atom("stock-us"), do: :stock_us
  defp asset_class_atom("crypto"), do: :crypto

  defp analyze_all(watchlist, portfolio, deps, _date, _acc) do
    Enum.map(watchlist, fn entry ->
      analyze(entry, portfolio, deps)
    end)
  end

  defp analyze(entry, portfolio, deps) do
    router = deps[:router] || (&MarketData.router/1)
    {provider, symbol} = router.(entry)
    candles_fun = deps[:candles] || fn symbol, days -> provider.candles(symbol, days) end
    llm_fun = deps[:llm] || default_llm()

    with {:ok, candles} <- candles_fun.(symbol, 90),
         false <- candles == [] do
      closes = Enum.map(candles, & &1.close)

      context = %{
        rsi: BotTrader.Indicators.rsi(closes),
        ema20: BotTrader.Indicators.ema(closes, 20),
        ema50: BotTrader.Indicators.ema(closes, 50),
        last_close: List.last(closes),
        daily_return: BotTrader.Indicators.daily_return(Enum.take(closes, -2)),
        position: Enum.find(portfolio.positions, &(&1.symbol == entry.symbol)),
        cash_brl: portfolio.cash
      }

      prompt = Research.build_prompt(entry, context)

      signal =
        with {:ok, body} <- llm_fun.([%{role: "user", content: prompt}]),
             content <-
               body |> get_in(["choices"]) |> List.first() |> get_in(["message", "content"]),
             {:ok, signal} <- LLM.parse_signal(content) do
          signal
        else
          _ -> nil
        end

      %{
        symbol: entry.symbol,
        asset_class: entry.asset_class,
        last_close: context.last_close,
        signal: signal,
        effective:
          if(signal,
            do: LLM.Signal.effective_action(signal, Config.confidence_threshold()),
            else: :hold
          ),
        target_weight: if(signal, do: signal.target_weight, else: 0.0),
        qualitative: if(signal, do: signal.qualitative, else: ""),
        rationale: if(signal, do: signal.rationale, else: ""),
        rsi: context.rsi,
        ema20: context.ema20,
        ema50: context.ema50,
        daily_return: context.daily_return
      }
    else
      _ ->
        %{
          symbol: entry.symbol,
          asset_class: entry.asset_class,
          last_close: nil,
          signal: nil,
          effective: :hold,
          target_weight: 0.0,
          qualitative: "",
          rationale: "",
          rsi: nil,
          ema20: nil,
          ema50: nil,
          daily_return: nil
        }
    end
  end

  defp last_prices(signals) do
    Map.new(signals, fn s -> {s.symbol, s.last_close} end)
  end

  defp position_value(portfolio, signal) do
    case Enum.find(portfolio.positions, &(&1.symbol == signal.symbol)) do
      nil ->
        0.0

      %Position{quantity: qty, asset_class: :stock_us} ->
        qty * signal.last_close * Config.usd_brl_rate()

      %Position{quantity: qty} ->
        qty * signal.last_close
    end
  end

  defp portfolio_to_map(%Portfolio{} = p) do
    %{
      cash: p.cash,
      positions: Enum.map(p.positions, &Map.from_struct/1),
      realized_pnl: p.realized_pnl,
      day_realized_loss: p.day_realized_loss,
      start_of_day_cash: p.start_of_day_cash,
      day: if(p.day, do: Date.to_iso8601(p.day))
    }
  end

  defp portfolio_from_map(map) when map == %{}, do: Portfolio.init()

  defp portfolio_from_map(map) do
    %Portfolio{
      cash: map[:cash] || 0.0,
      positions: Enum.map(map[:positions] || [], fn pos -> struct(Position, pos) end),
      realized_pnl: map[:realized_pnl] || 0.0,
      day_realized_loss: map[:day_realized_loss] || 0.0,
      start_of_day_cash: map[:start_of_day_cash] || Config.start_capital_brl(),
      day: parse_day(map[:day])
    }
  end

  defp parse_day(nil), do: nil
  defp parse_day(iso), do: Date.from_iso8601!(iso)

  defp default_llm do
    case Config.llm_backend() do
      "hermes" -> &BotTrader.Hermes.chat/1
      _ -> &LLM.chat/1
    end
  end
end
