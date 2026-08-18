defmodule BotTrader.PotentialsReportTest do
  use ExUnit.Case, async: true

  alias BotTrader.Potentials.Report

  test "formats one line per valid symbol" do
    snapshots = [
      %{symbol: "VIVT3", price: 42.5, change_pct: 1.2, technical_rating: "buy", stale: false},
      %{symbol: "PETR4", price: 40.0, change_pct: -0.5, technical_rating: "sell", stale: false}
    ]

    text = Report.build(snapshots)
    assert text =~ "VIVT3"
    assert text =~ "42.5"
    assert text =~ "1.2"
    assert text =~ "buy"
    assert text =~ "PETR4"
  end

  test "excludes stale symbols" do
    snapshots = [
      %{symbol: "VIVT3", price: 42.5, change_pct: 1.2, technical_rating: "buy", stale: false},
      %{symbol: "STALE", price: nil, change_pct: nil, technical_rating: nil, stale: true}
    ]

    text = Report.build(snapshots)
    assert text =~ "VIVT3"
    refute text =~ "STALE"
  end
end
