defmodule BotTrader.MarketData.CoinGecko do
  @moduledoc false
  @behaviour BotTrader.MarketData

  alias BotTrader.Config
  alias BotTrader.MarketData.Candle

  @impl true
  def candles(coin_id, days, opts \\ []) do
    url = Config.coingecko_base_url() <> "/api/v3/coins/#{coin_id}/ohlc"
    params = [vs_currency: "usd", days: min(days, 365)]

    case Req.get(url, Keyword.merge([params: params], opts)) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, normalize(body)}

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
end
