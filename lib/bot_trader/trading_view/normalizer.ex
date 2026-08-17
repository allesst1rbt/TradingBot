defmodule BotTrader.TradingView.Normalizer do
  @moduledoc "Normalizes extracted TradingView fields into compact snapshots."

  def normalize(data) do
    snapshot = %{
      symbol: symbol(data[:symbol]),
      asset_class: data[:asset_class],
      timestamp: parse_timestamp(data[:timestamp]),
      timeframe: data[:timeframe] || "15m",
      price: number(data[:price]),
      change_pct: number(data[:change_pct]),
      open: number(data[:open]),
      high: number(data[:high]),
      low: number(data[:low]),
      close: number(data[:close]),
      volume: number(data[:volume]),
      technical_rating:
        data[:technical_rating] && String.downcase(to_string(data[:technical_rating])),
      rsi: number(data[:rsi]),
      macd: number(data[:macd]),
      ema20: number(data[:ema20]),
      sma50: number(data[:sma50]),
      provider: "tradingview",
      stale: false
    }

    if valid?(snapshot), do: {:ok, snapshot}, else: {:stale, %{snapshot | stale: true}}
  end

  defp valid?(snapshot),
    do:
      is_binary(snapshot.symbol) and is_struct(snapshot.timestamp, DateTime) and
        is_number(snapshot.price)

  defp symbol("BMFBOVESPA:" <> symbol), do: symbol
  defp symbol(value), do: value

  defp parse_timestamp(value) do
    case DateTime.from_iso8601(to_string(value || "")) do
      {:ok, timestamp, _} -> timestamp
      _ -> nil
    end
  end

  defp number(nil), do: nil
  defp number(value) when is_number(value), do: value * 1.0

  defp number(value) do
    value
    |> to_string()
    |> String.replace(",", "")
    |> Float.parse()
    |> case do
      {number, _} -> number
      :error -> nil
    end
  end
end
