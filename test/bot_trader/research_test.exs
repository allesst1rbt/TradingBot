defmodule BotTrader.ResearchTest do
  use ExUnit.Case, async: true

  alias BotTrader.Research

  test "watchlist always included" do
    watchlist = [
      %{symbol: "PETR4", asset_class: :stock_br},
      %{symbol: "BTC", asset_class: :crypto}
    ]

    assert Research.universe(watchlist, [], 3) == watchlist
  end

  test "candidate cap enforced" do
    watchlist = [%{symbol: "AAPL", asset_class: :stock_us}]
    candidates = for i <- 1..5, do: %{symbol: "C#{i}", asset_class: :crypto}

    universe = Research.universe(watchlist, candidates, 3)
    assert length(universe) == 4
    assert Enum.take(universe, 1) == watchlist
    assert [%{symbol: "C1"}, %{symbol: "C2"}, %{symbol: "C3"}] = Enum.drop(universe, 1)
  end

  test "candidates below cap all included" do
    watchlist = []
    candidates = [%{symbol: "C1", asset_class: :crypto}]
    assert Research.universe(watchlist, candidates, 3) == candidates
  end

  test "report has qualitative section" do
    report =
      Research.render_qualitative(%{symbol: "BTC", qualitative: "strong adoption narrative"})

    assert report =~ "Qualitative analysis"
    assert report =~ "BTC"
    assert report =~ "strong adoption narrative"
    assert report =~ "non-deterministic"
  end

  test "prompt includes symbol and indicator context" do
    prompt =
      Research.build_prompt(%{symbol: "BTC", asset_class: :crypto}, %{
        rsi: 65.0,
        ema20: 100.0,
        ema50: 90.0,
        last_close: 105.0,
        daily_return: 0.05,
        position: nil,
        cash_brl: 900.0
      })

    assert prompt =~ "BTC"
    assert prompt =~ "RSI"
    assert prompt =~ "BUY"
  end

  test "rolling summary size stable regardless of run count" do
    summary1 =
      Research.build_rolling_summary(%{
        runs: 1,
        last_signal: "HOLD",
        position: nil,
        equity: 1000.0,
        news_count: 1
      })

    summary2 =
      Research.build_rolling_summary(%{
        runs: 10_000,
        last_signal: "BUY",
        position: nil,
        equity: 1000.0,
        news_count: 50
      })

    assert byte_size(summary1) > 0
    assert_in_delta byte_size(summary1), byte_size(summary2), byte_size(summary1) * 0.2
  end
end
