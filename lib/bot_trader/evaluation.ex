defmodule BotTrader.Evaluation do
  @moduledoc """
  30-day go/no-go evaluation: total return, max drawdown, and trade count
  from persisted snapshots and trades, with hard thresholds.
  """

  alias BotTrader.Config

  def evaluate(snapshots, trades) do
    equities = Enum.map(snapshots, & &1.equity)

    %{
      return_pct: return_pct(equities),
      max_drawdown_pct: max_drawdown_pct(equities),
      trade_count: length(trades)
    }
  end

  def verdict(metrics, min_return, max_drawdown, min_trades) do
    if metrics.return_pct >= min_return and
         metrics.max_drawdown_pct <= max_drawdown and
         metrics.trade_count >= min_trades do
      :pass
    else
      :fail
    end
  end

  def verdict(metrics) do
    verdict(
      metrics,
      Config.gate_min_return(),
      Config.gate_max_drawdown(),
      Config.gate_min_trades()
    )
  end

  def verdict_message(:pass, metrics, broker_configured) do
    if broker_configured do
      """
      ✅ GATE PASS — return #{format(metrics.return_pct)}%, drawdown #{format(metrics.max_drawdown_pct)}%, #{metrics.trade_count} trades.
      Real mode enabled.
      """
    else
      """
      ✅ GATE PASS — return #{format(metrics.return_pct)}%, drawdown #{format(metrics.max_drawdown_pct)}%, #{metrics.trade_count} trades.
      Staying in PAPER mode: attach a broker adapter before real trading.
      """
    end
  end

  def verdict_message(:fail, metrics, _broker_configured) do
    """
    ❌ GATE FAIL — return #{format(metrics.return_pct)}% (min #{Config.gate_min_return()}%), drawdown #{format(metrics.max_drawdown_pct)}% (max #{Config.gate_max_drawdown()}%), #{metrics.trade_count} trades (min #{Config.gate_min_trades()}).
    Staying in PAPER mode.
    """
  end

  defp return_pct([]), do: 0.0

  defp return_pct([first | _] = equities) do
    (List.last(equities) - first) / first * 100.0
  end

  defp max_drawdown_pct(equities) do
    {_peak, max_dd} =
      Enum.reduce(equities, {nil, 0.0}, fn equity, {peak, max_dd} ->
        peak = if peak == nil, do: equity, else: max(peak, equity)
        dd = (peak - equity) / peak * 100.0
        {peak, max(dd, max_dd)}
      end)

    max_dd
  end

  defp format(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 2)

  defp format(value), do: to_string(value)
end
