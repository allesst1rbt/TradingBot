defmodule BotTrader.NewsStoreTest do
  use ExUnit.Case, async: false

  alias BotTrader.{NewsStore, Repo}

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  setup do
    Repo.delete_all(BotTrader.NewsRunner)
    :ok
  end

  test "dedup by hash" do
    now = DateTime.utc_now()

    assert {:ok, first} =
             NewsStore.insert(%{
               symbol: "VIVT3",
               headline: "VIVT3 earnings beat",
               source: "TradingView",
               timestamp: now,
               sentiment: "neutral"
             })

    assert {:ok, _second} =
             NewsStore.insert(%{
               symbol: "VIVT3",
               headline: "VIVT3 earnings beat",
               source: "TradingView",
               timestamp: now,
               sentiment: "positive"
             })

    rows = NewsStore.latest("VIVT3", 50)
    assert length(rows) == 1
    assert hd(rows).id == first.id
  end

  test "prune keeps latest fifty" do
    now = DateTime.utc_now()

    for i <- 1..60 do
      NewsStore.insert(%{
        symbol: "VIVT3",
        headline: "headline #{i}",
        source: "TradingView",
        timestamp: DateTime.add(now, -i, :second),
        sentiment: "neutral"
      })
    end

    NewsStore.prune("VIVT3", 50)
    assert length(NewsStore.latest("VIVT3", 100)) == 50
  end
end
