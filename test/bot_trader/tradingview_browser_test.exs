defmodule BotTrader.TradingViewBrowserTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Browser

  test "failed page does not abort batch" do
    entries = [
      %{symbol: "VIVT3", asset_class: "stock-br"},
      %{symbol: "PETR4", asset_class: "stock-br"}
    ]

    fetcher = fn
      %{symbol: "VIVT3"} ->
        {:error, :blocked}

      %{symbol: "PETR4"} ->
        {:ok,
         %{
           symbol: "PETR4",
           asset_class: "stock-br",
           timestamp: "2026-08-17T13:00:00Z",
           price: "42"
         }}
    end

    results = Browser.scrape_batch(entries, fetcher: fetcher)
    assert [%{stale: true}, %{stale: false}] = results
  end

  test "limits batch size" do
    entries = for i <- 1..5, do: %{symbol: "S#{i}", asset_class: "stock-us"}
    parent = self()

    fetcher = fn entry ->
      send(parent, {:fetch, entry.symbol})
      {:ok, Map.merge(entry, %{timestamp: "2026-08-17T13:00:00Z", price: "10"})}
    end

    results = Browser.scrape_batch(entries, fetcher: fetcher, max_concurrency: 2)
    assert length(results) == 5
    assert_receive {:fetch, _}, 100
  end
end
