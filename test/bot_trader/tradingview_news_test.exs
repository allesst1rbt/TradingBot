defmodule BotTrader.TradingViewNewsTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Browser
  alias BotTrader.TradingView.Normalizer

  test "extracts headlines from fixture" do
    data = %{
      symbol: "BMFBOVESPA:VIVT3",
      asset_class: "stock-br",
      timestamp: "2026-08-17T13:00:00Z",
      price: "42.5",
      news: [
        %{"headline" => "VIVT3 earnings beat", "source" => "https://tradingview.com/news/a"},
        %{"headline" => "Telefonica expands 5G", "source" => "https://tradingview.com/news/b"}
      ]
    }

    assert {:ok, snapshot} = Normalizer.normalize(data)
    assert length(snapshot.news) == 2

    assert Enum.map(snapshot.news, & &1[:headline]) == [
             "VIVT3 earnings beat",
             "Telefonica expands 5G"
           ]
  end

  test "browser passes news through fetcher" do
    parent = self()

    fetcher = fn entry ->
      send(parent, {:fetch, entry.symbol})

      {:ok,
       %{
         symbol: entry.symbol,
         asset_class: entry.asset_class,
         timestamp: "2026-08-17T13:00:00Z",
         price: "10",
         news: [%{headline: "h", source: "s"}]
       }}
    end

    [result] =
      Browser.scrape_batch([%{symbol: "VIVT3", asset_class: "stock-br"}], fetcher: fetcher)

    assert result.news == [%{headline: "h", source: "s", timestamp: nil}]
    assert_received {:fetch, "VIVT3"}
  end

  test "empty on missing news" do
    data = %{
      symbol: "VIVT3",
      asset_class: "stock-br",
      timestamp: "2026-08-17T13:00:00Z",
      price: "42.5"
    }

    assert {:ok, snapshot} = Normalizer.normalize(data)
    assert snapshot.news == []
  end
end
