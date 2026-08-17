defmodule BotTrader.TradingViewNormalizerTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Normalizer

  test "normalizes market and technical fixture" do
    fixture = %{
      symbol: "BMFBOVESPA:VIVT3",
      asset_class: "stock-br",
      timestamp: "2026-08-17T13:00:00Z",
      timeframe: "15m",
      price: "42.50",
      change_pct: "1.2",
      open: "42.00",
      high: "43.00",
      low: "41.80",
      close: "42.50",
      volume: "100000",
      technical_rating: "BUY",
      rsi: "55.0",
      macd: "0.2",
      ema20: "41.0",
      sma50: "40.0"
    }

    assert {:ok, snapshot} = Normalizer.normalize(fixture)
    assert snapshot.symbol == "VIVT3"
    assert snapshot.provider == "tradingview"
    assert snapshot.price == 42.5
    assert snapshot.technical_rating == "buy"
    assert snapshot.stale == false
  end

  test "missing fields mark stale" do
    assert {:stale, snapshot} =
             Normalizer.normalize(%{symbol: "VIVT3", asset_class: "stock-br", timestamp: "bad"})

    assert snapshot.symbol == "VIVT3"
    assert snapshot.stale == true
  end
end
