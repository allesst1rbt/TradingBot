defmodule BotTrader.MarketData.YahooFinance do
  @moduledoc false
  @behaviour BotTrader.MarketData

  alias BotTrader.Config
  alias BotTrader.MarketData.Candle

  @impl true
  def candles(symbol, days, opts \\ []) do
    url = Config.yahoo_base_url() <> "/v8/finance/chart/" <> symbol
    params = [range: range_for(days), interval: "1d"]

    case Req.get(url, Keyword.merge([params: params], opts)) do
      {:ok, %Req.Response{status: 200, body: body}} -> parse(body, symbol)
      {:ok, _} -> {:error, :http_error, symbol}
      {:error, _} -> {:error, :http_error, symbol}
    end
  end

  defp parse(body, symbol) do
    case get_in(body, ["chart", "result"]) do
      nil -> {:error, :no_data, symbol}
      [result | _] -> {:ok, normalize(result)}
    end
  end

  defp normalize(result) do
    quote = get_in(result, ["indicators", "quote"]) |> List.first() || %{}

    result["timestamp"]
    |> Enum.with_index()
    |> Enum.map(fn {ts, i} ->
      %Candle{
        ts: DateTime.from_unix!(ts),
        open: Enum.at(quote["open"] || [], i),
        high: Enum.at(quote["high"] || [], i),
        low: Enum.at(quote["low"] || [], i),
        close: Enum.at(quote["close"] || [], i),
        volume: Enum.at(quote["volume"] || [], i) || 0.0
      }
    end)
  end

  defp range_for(days) when days <= 30, do: "1mo"
  defp range_for(days) when days <= 90, do: "3mo"
  defp range_for(days) when days <= 365, do: "1y"
  defp range_for(_), do: "5y"
end
