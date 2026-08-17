defmodule BotTrader.TradingView.Browser do
  @moduledoc """
  Batch browser boundary. The fetcher is injectable for tests and for the
  Playwright adapter; normalization and failure isolation stay deterministic.
  """

  alias BotTrader.TradingView.Normalizer

  def scrape_batch(entries, opts \\ []) do
    fetcher = opts[:fetcher] || (&fetch_with_playwright/1)
    max_concurrency = opts[:max_concurrency] || 2

    entries
    |> Task.async_stream(
      fn entry -> scrape_one(entry, fetcher) end,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: opts[:timeout] || 30_000
    )
    |> Enum.map(fn
      {:ok, snapshot} -> snapshot
      {:exit, reason} -> %{stale: true, error: reason}
    end)
  end

  defp scrape_one(entry, fetcher) do
    case fetcher.(entry) do
      {:ok, data} ->
        case Normalizer.normalize(data) do
          {:ok, snapshot} -> snapshot
          {:stale, snapshot} -> snapshot
        end

      {:error, reason} ->
        %{
          symbol: entry.symbol,
          asset_class: entry.asset_class,
          provider: "tradingview",
          stale: true,
          error: reason
        }
    end
  end

  defp fetch_with_playwright(entry) do
    script =
      Application.get_env(
        :bot_trader,
        :tradingview_script,
        System.get_env("TRADINGVIEW_SCRIPT", "/opt/tradingview/tradingview_scraper.mjs")
      )

    node = System.get_env("NODE_BIN", "node")
    url = tradingview_url(entry)
    args = [script, Jason.encode!(%{url: url, timeout: 30_000})]

    case System.cmd(node, args, stderr_to_stdout: true) do
      {output, 0} -> normalize_browser_output(output, entry)
      {output, _status} -> {:error, {:playwright_failed, String.slice(output, 0, 300)}}
    end
  rescue
    error -> {:error, {:playwright_failed, Exception.message(error)}}
  end

  defp normalize_browser_output(output, entry) do
    with {:ok, data} <- Jason.decode(String.trim(output)),
         true <- data["ok"] == true do
      {:ok,
       %{
         symbol: entry.symbol,
         asset_class: entry.asset_class,
         timestamp: DateTime.to_iso8601(DateTime.utc_now()),
         timeframe: "15m",
         price: data["price"],
         change_pct: data["change_pct"],
         volume: data["volume"]
       }}
    else
      _ -> {:error, :playwright_invalid_output}
    end
  end

  defp tradingview_url(%{symbol: symbol, asset_class: "stock-br"}),
    do: "https://br.tradingview.com/symbols/BMFBOVESPA-#{symbol}/"

  defp tradingview_url(%{symbol: symbol, asset_class: :stock_br}),
    do: "https://br.tradingview.com/symbols/BMFBOVESPA-#{symbol}/"

  defp tradingview_url(%{symbol: symbol, asset_class: _}),
    do: "https://www.tradingview.com/symbols/#{symbol}/"
end
