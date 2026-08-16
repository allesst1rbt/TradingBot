defmodule BotTrader.MarketData.CoinGecko do
  @moduledoc false
  @behaviour BotTrader.MarketData

  alias BotTrader.Config
  alias BotTrader.MarketData.Candle

  @impl true
  def candles(coin_id, days, interval \\ "1d", opts \\ []) do
    url = Config.coingecko_base_url() <> "/api/v3/coins/#{coin_id}/ohlc"
    params = [vs_currency: "usd", days: min(days, 365)]

    case Req.get(url, Keyword.merge([params: params], opts)) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        candles = normalize(body)

        cond do
          candles == [] -> {:error, :no_data, coin_id}
          intraday?(interval) -> {:ok, bucket(candles, bucket_size(interval))}
          true -> {:ok, candles}
        end

      {:ok, %Req.Response{status: 200}} ->
        {:error, :no_data, coin_id}

      {:ok, _} ->
        {:error, :http_error, coin_id}

      {:error, _} ->
        {:error, :http_error, coin_id}
    end
  end

  defp normalize(body) do
    Enum.map(body, fn [ts, open, high, low, close] ->
      %Candle{
        ts: DateTime.from_unix!(ts |> Kernel.div(1000)),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 0.0
      }
    end)
  end

  defp intraday?(interval), do: interval in ["5m", "15m", "30m", "60m"]

  defp bucket_size("5m"), do: 12
  defp bucket_size("15m"), do: 4
  defp bucket_size("30m"), do: 2
  defp bucket_size("60m"), do: 1

  defp bucket(candles, size) do
    Enum.flat_map(candles, fn candle ->
      step = 3600 / size

      for i <- 0..(size - 1) do
        %{candle | ts: DateTime.add(candle.ts, trunc(i * step), :second)}
      end
    end)
  end
end
