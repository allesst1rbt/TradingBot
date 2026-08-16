defmodule BotTrader.Indicators do
  @moduledoc """
  Deterministic technical indicators computed from close price series.
  """

  def rsi(closes, period \\ 14) do
    closes = Enum.reject(closes, &is_nil/1)

    diffs = Enum.chunk_every(closes, 2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)

    gains = Enum.map(diffs, &max(&1, 0))
    losses = Enum.map(diffs, &max(-&1, 0))

    initial_g = gains |> Enum.take(period) |> average()
    initial_l = losses |> Enum.take(period) |> average()

    {avg_g, avg_l} = smooth(gains, losses, period, initial_g, initial_l)

    cond do
      avg_l == 0.0 and avg_g == 0.0 -> 50.0
      avg_l == 0.0 -> 100.0
      true -> 100.0 - 100.0 / (1.0 + avg_g / avg_l)
    end
  end

  def ema(closes, period) do
    closes = Enum.reject(closes, &is_nil/1)
    k = 2.0 / (period + 1)
    seed = closes |> Enum.take(period) |> average()

    closes
    |> Enum.drop(period)
    |> Enum.reduce(seed, fn close, prev -> k * close + (1 - k) * prev end)
  end

  def daily_return([a, b | _]), do: (b - a) / a
  def daily_return(_), do: 0.0

  defp smooth(gains, losses, period, avg_g, avg_l) do
    gains
    |> Enum.drop(period)
    |> Enum.zip(Enum.drop(losses, period))
    |> Enum.reduce({avg_g, avg_l}, fn {g, l}, {ag, al} ->
      {(ag * (period - 1) + g) / period, (al * (period - 1) + l) / period}
    end)
  end

  defp average([]), do: 0.0
  defp average(list), do: Enum.sum(list) / length(list)
end
