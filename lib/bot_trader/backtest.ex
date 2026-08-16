defmodule BotTrader.Backtest do
  @moduledoc """
  Brief historical replay: ~90 days of daily candles through a signal
  strategy and the same paper portfolio engine used live. No LLM calls,
  no writes to live state.
  """

  alias BotTrader.{Indicators, Portfolio, Risk}

  def run(deps) do
    entry = deps.entry
    candles_fun = deps.candles
    strategy = deps[:strategy] || (&default_strategy/3)

    with {:ok, candles} <- candles_fun.(entry.symbol, 90),
         false <- candles == [] do
      portfolio = Portfolio.init()

      {_final_portfolio, trades, equities} =
        Enum.with_index(candles)
        |> Enum.reduce({portfolio, [], []}, fn {candle, i}, {port, trades, equities} ->
          action = strategy.(candles, i, port)

          {port, trades} =
            case action do
              :buy ->
                execute(port, trades, %{
                  type: :buy,
                  symbol: entry.symbol,
                  asset_class: entry.asset_class,
                  notional: 0.2 * port.cash,
                  price: candle.close,
                  ts: candle.ts
                })

              :close ->
                execute(port, trades, %{
                  type: :close,
                  symbol: entry.symbol,
                  asset_class: entry.asset_class,
                  price: candle.close,
                  reason: :backtest,
                  ts: candle.ts
                })

              :hold ->
                {port, trades}
            end

          {port, trades, equities ++ [equity(port, candle)]}
        end)

      {:ok,
       %{
         return_pct: return_pct(equities),
         max_drawdown_pct: max_drawdown_pct(equities),
         trade_count: length(trades),
         mode: :indicator_only
       }}
    else
      _ -> {:error, :no_data}
    end
  end

  def default_strategy(candles, i, portfolio) do
    closes = Enum.map(candles, & &1.close)
    rsi = Indicators.rsi(Enum.take(closes, i + 1))

    daily_return =
      if i > 0,
        do: (Enum.at(closes, i) - Enum.at(closes, i - 1)) / Enum.at(closes, i - 1),
        else: 0.0

    cond do
      portfolio.positions != [] and daily_return < 0 -> :close
      portfolio.positions == [] and daily_return > 0 and rsi < 70 -> :buy
      true -> :hold
    end
  end

  defp execute(port, trades, order) do
    with :ok <- Risk.precheck(port, order),
         {:ok, port, trade} <- Portfolio.apply(port, order) do
      {port, [trade | trades]}
    else
      _ -> {port, trades}
    end
  end

  defp equity(portfolio, candle) do
    position_value =
      case portfolio.positions do
        [] -> 0.0
        [position | _] -> position.quantity * candle.close
      end

    portfolio.cash + position_value
  end

  defp return_pct([first | _] = equities), do: (List.last(equities) - first) / first * 100.0

  defp max_drawdown_pct(equities) do
    {_peak, max_dd} =
      Enum.reduce(equities, {nil, 0.0}, fn equity, {peak, max_dd} ->
        peak = if peak == nil, do: equity, else: max(peak, equity)
        {peak, max((peak - equity) / peak * 100.0, max_dd)}
      end)

    max_dd
  end
end
