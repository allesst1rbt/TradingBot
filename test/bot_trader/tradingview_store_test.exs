defmodule BotTrader.TradingViewStoreTest do
  use ExUnit.Case, async: false

  alias BotTrader.{Repo, TradingViewStore}

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  setup do
    Repo.delete_all(BotTrader.TradingViewSnapshot)
    Repo.delete_all(BotTrader.TradingViewCursor)
    :ok
  end

  test "persists normalized snapshot" do
    attrs = %{
      symbol: "VIVT3",
      asset_class: "stock-br",
      timestamp: ~U[2026-08-17 13:00:00Z],
      timeframe: "15m",
      price: 42.5,
      change_pct: 1.2,
      open: 42.0,
      high: 43.0,
      low: 41.8,
      close: 42.5,
      volume: 100_000.0,
      technical_rating: "buy",
      rsi: 55.0,
      macd: 0.2,
      ema20: 41.0,
      sma50: 40.0,
      provider: "tradingview",
      stale: false
    }

    assert {:ok, snapshot} = TradingViewStore.insert_snapshot(attrs)
    assert snapshot.symbol == "VIVT3"
    assert TradingViewStore.latest_snapshot("VIVT3").price == 42.5
  end

  test "advances batch cursor" do
    assert {:ok, 0} = TradingViewStore.get_cursor("stocks")
    assert :ok = TradingViewStore.put_cursor("stocks", 3)
    assert {:ok, 3} = TradingViewStore.get_cursor("stocks")
  end

  test "retains latest compact history" do
    for minute <- 0..4 do
      TradingViewStore.insert_snapshot(%{
        symbol: "VIVT3",
        asset_class: "stock-br",
        timestamp: DateTime.add(~U[2026-08-17 13:00:00Z], minute * 900, :second),
        timeframe: "15m",
        price: 40.0 + minute,
        provider: "tradingview",
        stale: false
      })
    end

    snapshots = TradingViewStore.recent_snapshots("VIVT3", 3)
    assert length(snapshots) == 3
    assert hd(snapshots).price == 44.0
  end
end
