defmodule BotTrader.MarketData.YahooFinance do
  @moduledoc false
  @behaviour BotTrader.MarketData

  alias BotTrader.Config
  alias BotTrader.MarketData.Candle

  @impl true
  def candles(symbol, days, interval \\ "1d", opts \\ []) do
    url = Config.yahoo_base_url() <> "/v8/finance/chart/" <> symbol
    params = [range: range_for(days, interval), interval: interval]

    case Req.get(url, Keyword.merge([params: params], opts)) do
      {:ok, %Req.Response{status: 200, body: body}} -> parse(body, symbol)
      {:ok, _} -> {:error, :http_error, symbol}
      {:error, _} -> {:error, :http_error, symbol}
    end
  end

  defp parse(body, symbol) do
    case get_in(body, ["chart", "result"]) do
      nil ->
        {:error, :no_data, symbol}

      [result | _] ->
        case normalize(result) do
          [] -> {:error, :no_data, symbol}
          candles -> {:ok, candles}
        end
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
    |> Enum.reject(&(&1.close == nil))
  end

  def quotes(symbols, opts \\ []) do
    url = Config.yahoo_base_url() <> "/v7/finance/quote"
    chunk = opts[:chunk_size] || Config.universe_quote_chunk()
    interval = opts[:min_interval_ms] || 150
    retry_429 = Keyword.get(opts, :retry_429, true)

    results =
      symbols
      |> Enum.chunk_every(chunk)
      |> Enum.map(fn chunk_symbols ->
        result = fetch_quotes_chunk(url, chunk_symbols, opts)

        if retry_429 and result == :rate_limited do
          Process.sleep(interval * 2)
          fetch_quotes_chunk(url, chunk_symbols, opts)
        else
          result
        end
      end)
      |> Enum.flat_map(fn
        {:ok, quotes} -> quotes
        _ -> []
      end)

    {:ok, results}
  end

  defp fetch_quotes_chunk(url, chunk_symbols, opts) do
    params = [symbols: Enum.join(chunk_symbols, ",")]
    interval = opts[:min_interval_ms] || 150
    req_opts = Keyword.drop(opts, [:chunk_size, :min_interval_ms, :retry_429])

    case Req.get(url, Keyword.merge([params: params], req_opts)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, parse_quotes(body)}

      {:ok, %Req.Response{status: 429}} ->
        :rate_limited

      _ ->
        {:error, :http_error}
    end
    |> tap(fn _ -> Process.sleep(interval) end)
  end

  defp parse_quotes(body) do
    body
    |> get_in(["quoteResponse", "result"])
    |> Kernel.||([])
    |> Enum.map(&to_quote/1)
  end

  defp to_quote(q) do
    %{
      symbol: q["symbol"],
      price: q["regularMarketPrice"],
      day_change_pct: q["regularMarketChangePercent"] || 0.0,
      volume: q["regularMarketVolume"] || 0.0
    }
  end

  defp range_for(_days, interval) when interval in ["5m", "15m", "30m", "60m", "1h"], do: "1d"
  defp range_for(days, _interval) when days <= 30, do: "1mo"
  defp range_for(days, _interval) when days <= 90, do: "3mo"
  defp range_for(days, _interval) when days <= 365, do: "1y"
  defp range_for(_, _interval), do: "5y"
end
