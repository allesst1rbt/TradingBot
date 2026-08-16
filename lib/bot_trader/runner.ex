defmodule BotTrader.Runner do
  @moduledoc """
  Intraday pipeline orchestration: state load → market data → indicators →
  LLM signals → news → risk-checked paper orders → persistence (SQLite
  history + JSON portfolio) → report → Telegram. Runs are `standard`,
  `forced`, or `deep`; dependencies injectable.
  """

  alias BotTrader.{Config, LLM, MarketData, Portfolio, Research, Risk, State, Store}
  alias BotTrader.Portfolio.Position

  def run(deps \\ %{}, kind \\ :standard) do
    state_dir = deps[:state_dir] || Config.state_dir()
    date = deps[:date] || Date.utc_today()
    {:ok, run_row} = Store.start_run(kind)

    with {:ok, portfolio, trades, snapshots} <- load_state(state_dir),
         {:ok, watchlist} <- load_watchlist(deps) do
      portfolio = Portfolio.new_day(portfolio, date)

      telegram = deps[:telegram] || (&BotTrader.Telegram.send_message/1)

      signals = analyze_all(watchlist, portfolio, deps, kind)

      failed_symbols =
        Enum.flat_map(signals, fn s -> if s.llm_error, do: [s.symbol], else: [] end)

      if failed_symbols != [] do
        telegram.(
          BotTrader.Telegram.format_failure_alert(
            "LLM degraded for: " <> Enum.join(failed_symbols, ", ")
          )
        )
      end

      news_fun = deps[:news] || default_news()

      market_news =
        case news_fun.(:market) do
          {:ok, text} -> text
          text when is_binary(text) -> text
          _ -> ""
        end

      Store.insert_news(run_row, %{symbol: nil, trigger: nil, text: market_news})

      triggered_symbols =
        Enum.flat_map(signals, fn s -> if s.news_trigger, do: [s.symbol], else: [] end)

      triggered_news =
        if triggered_symbols == [] do
          %{}
        else
          case news_fun.(triggered_symbols) do
            {:ok, text} when is_binary(text) -> %{symbols: triggered_symbols, text: text}
            text when is_binary(text) -> %{symbols: triggered_symbols, text: text}
            _ -> %{}
          end
        end

      if map_size(triggered_news) > 0 do
        Enum.each(triggered_symbols, fn symbol ->
          Store.insert_news(run_row, %{
            symbol: symbol,
            trigger: Config.volatility_threshold(),
            text: triggered_news.text
          })
        end)
      end

      if deps[:universe_fun] || Config.universe_scan_enabled() do
        universe_fun = deps[:universe_fun] || (&BotTrader.Universe.scan_and_add/0)
        universe_fun.()
      end

      Enum.each(signals, fn signal ->
        if signal.signal do
          Store.insert_signal(run_row, %{
            symbol: signal.symbol,
            action: Atom.to_string(signal.effective),
            confidence: signal.signal.confidence,
            model: signal.model,
            price: signal.last_close,
            rationale: signal.rationale
          })
        end
      end)

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

      Enum.each(executed_trades, fn trade ->
        Store.insert_trade(%{
          run_id: run_row.id,
          symbol: trade.symbol,
          side: trade.side,
          quantity: trade.quantity,
          price: trade.price,
          fee: trade.fee,
          realized_pnl: trade[:realized_pnl],
          reason: trade[:reason] && to_string(trade.reason),
          ts: trade.ts
        })
      end)

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

      Store.insert_snapshot(run_row, %{
        ts: DateTime.utc_now(),
        equity: equity,
        cash: portfolio.cash,
        realized_pnl: portfolio.realized_pnl
      })

      calls = length(signals) + 1 + if(triggered_symbols == [], do: 0, else: 1)

      with :ok <- State.write(state_dir, :portfolio, portfolio_to_map(portfolio)),
           :ok <- State.write(state_dir, :trades, Enum.map(trades, & &1) ++ executed_trades),
           :ok <- State.write(state_dir, :snapshots, snapshots ++ [snapshot]) do
        report =
          BotTrader.Report.build(date, watchlist, signals, executed_trades, portfolio, equity)

        BotTrader.Report.write(state_dir, date, report)

        Store.finish_run(run_row, "ok", calls)

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

        if kind == :deep do
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
        end

        check_budget(telegram)

        {:ok,
         %{
           trades_executed: length(executed_trades),
           symbols_without_data:
             Enum.flat_map(signals, fn s -> if s.last_close == nil, do: [s.symbol], else: [] end)
         }}
      end
    else
      {:error, reason} ->
        Store.finish_run(run_row, "error", 0)

        telegram = deps[:telegram] || (&BotTrader.Telegram.send_message/1)
        _ = telegram.(BotTrader.Telegram.format_failure_alert(reason))
        {:error, reason}
    end
  end

  defp check_budget(telegram) do
    today = Date.to_iso8601(Date.utc_today())

    case Store.get_budget_alert() do
      {:ok, ^today} ->
        :ok

      _ ->
        if Store.calls_today() > Config.daily_call_budget() do
          telegram.("⚠️ LLM call budget exceeded today: #{Store.calls_today()} calls")
          Store.put_budget_alert(today)
        end
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
    entries = Store.get_watchlist()

    entries =
      if entries == [] do
        seed_watchlist_from_file()
        Store.get_watchlist()
      else
        entries
      end

    {:ok,
     Enum.map(entries, fn entry ->
       %{
         symbol: entry.symbol,
         asset_class: asset_class_atom(entry.asset_class),
         coin_id: entry.coin_id
       }
     end)}
  end

  defp seed_watchlist_from_file do
    with {:ok, body} <- File.read(Config.watchlist_path()),
         {:ok, json} <- Jason.decode(body) do
      entries =
        Enum.map(json["symbols"] || [], fn entry ->
          %{
            symbol: entry["symbol"],
            asset_class: entry["asset_class"],
            coin_id: entry["coin_id"]
          }
        end)

      Store.seed_watchlist(entries)
    else
      _ -> :ok
    end
  end

  defp asset_class_atom("stock-br"), do: :stock_br
  defp asset_class_atom("stock-us"), do: :stock_us
  defp asset_class_atom("crypto"), do: :crypto

  defp analyze_all(watchlist, portfolio, deps, kind) do
    Enum.map(watchlist, fn entry ->
      analyze(entry, portfolio, deps, kind)
    end)
  end

  defp analyze(entry, portfolio, deps, kind) do
    router = deps[:router] || (&MarketData.router/1)
    {provider, symbol} = router.(entry)
    candles_fun = deps[:candles] || fn symbol, days -> provider.candles(symbol, days) end
    llm_fun = deps[:llm] || default_llm()
    model = model_for(kind)

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
        cash_brl: portfolio.cash,
        rolling_summary: rolling_summary(entry.symbol)
      }

      prompt = Research.build_prompt(entry, context)

      {signal, llm_error} =
        case llm_fun.([%{role: "user", content: prompt}], model) do
          {:ok, body} ->
            content =
              body |> get_in(["choices"]) |> List.first() |> get_in(["message", "content"])

            case LLM.parse_signal(content) do
              {:ok, signal} -> {signal, false}
              _ -> {nil, false}
            end

          _ ->
            {nil, true}
        end

      %{
        symbol: entry.symbol,
        asset_class: entry.asset_class,
        last_close: context.last_close,
        signal: signal,
        llm_error: llm_error,
        effective:
          if(signal,
            do: LLM.Signal.effective_action(signal, Config.confidence_threshold()),
            else: :hold
          ),
        target_weight: if(signal, do: signal.target_weight, else: 0.0),
        qualitative: if(signal, do: signal.qualitative, else: ""),
        rationale: if(signal, do: signal.rationale, else: ""),
        model: model,
        news_trigger: news_trigger?(closes),
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
          llm_error: false,
          effective: :hold,
          target_weight: 0.0,
          qualitative: "",
          rationale: "",
          model: model,
          news_trigger: false,
          rsi: nil,
          ema20: nil,
          ema50: nil,
          daily_return: nil
        }
    end
  end

  defp news_trigger?(closes) do
    case Enum.take(closes, -2) do
      [a, b] when is_number(a) and is_number(b) and a != 0 ->
        abs(b - a) / a > Config.volatility_threshold()

      _ ->
        false
    end
  end

  defp rolling_summary(symbol) do
    context = Store.rolling_context(symbol, DateTime.utc_now())
    Research.build_rolling_summary(context)
  end

  defp model_for(:deep), do: Config.llm_model_pro()
  defp model_for(_), do: Config.llm_model_flash()

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
      "hermes" ->
        fn messages, model -> BotTrader.HermesMCP.analyze(messages, model: model) end

      _ ->
        fn messages, model -> LLM.chat(messages, model: model) end
    end
  end

  defp default_news do
    case Config.llm_backend() do
      "hermes" -> &BotTrader.HermesMCP.news/1
      _ -> fn _symbols -> "" end
    end
  end
end
