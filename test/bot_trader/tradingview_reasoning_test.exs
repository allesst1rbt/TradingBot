defmodule BotTrader.TradingViewReasoningTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Reasoning

  test "shortlist capped at ten" do
    snapshots =
      for i <- 1..20,
          do: %{symbol: "S#{i}", change_pct: i * 1.0, volume: 1_000_000.0, stale: false}

    result = Reasoning.shortlist(snapshots, 10)
    assert length(result) == 10
    assert hd(result).symbol == "S20"
  end

  test "prompt contains structured fields" do
    prompt =
      Reasoning.build_prompt(
        %{
          symbol: "VIVT3",
          price: 42.5,
          change_pct: 1.2,
          technical_rating: "buy",
          rsi: 55.0,
          macd: 0.2,
          ema20: 41.0,
          sma50: 40.0
        },
        nil
      )

    assert prompt =~ "VIVT3"
    assert prompt =~ "42.5"
    assert prompt =~ "technical_rating"
    assert prompt =~ "rsi"
  end
end
