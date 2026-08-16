defmodule BotTrader.EvaluationTest do
  use ExUnit.Case, async: true

  alias BotTrader.Evaluation

  defp snapshots(equities) do
    equities
    |> Enum.with_index(1)
    |> Enum.map(fn {equity, day} -> %{date: "2026-08-#{pad(day)}", equity: equity} end)
  end

  defp pad(day), do: if(day < 10, do: "0#{day}", else: "#{day}")

  test "computes return, drawdown, and trade count" do
    equities = [1000.0, 1010.0, 967.58, 1031.0]
    trades = List.duplicate(%{symbol: "BTC", side: "BUY"}, 12)

    metrics = Evaluation.evaluate(snapshots(equities), trades)

    assert_in_delta metrics.return_pct, 3.1, 1.0e-6
    assert_in_delta metrics.max_drawdown_pct, 4.2, 1.0e-6
    assert metrics.trade_count == 12
  end

  test "passes all thresholds" do
    metrics = %{return_pct: 3.1, max_drawdown_pct: 4.2, trade_count: 11}
    assert Evaluation.verdict(metrics, 2.0, 5.0, 10) == :pass
  end

  test "fails on drawdown" do
    metrics = %{return_pct: 4.0, max_drawdown_pct: 7.0, trade_count: 15}
    assert Evaluation.verdict(metrics, 2.0, 5.0, 10) == :fail
  end

  test "fails on trade count" do
    metrics = %{return_pct: 2.5, max_drawdown_pct: 1.0, trade_count: 6}
    assert Evaluation.verdict(metrics, 2.0, 5.0, 10) == :fail
  end

  test "fails on low return" do
    metrics = %{return_pct: 1.5, max_drawdown_pct: 1.0, trade_count: 12}
    assert Evaluation.verdict(metrics, 2.0, 5.0, 10) == :fail
  end

  test "pass without broker stays paper" do
    metrics = %{return_pct: 3.0, max_drawdown_pct: 2.0, trade_count: 12}
    message = Evaluation.verdict_message(:pass, metrics, false)

    assert message =~ "PASS"
    assert message =~ "PAPER"
    assert message =~ "broker"
  end

  test "fail verdict lists failing metrics" do
    metrics = %{return_pct: 4.0, max_drawdown_pct: 7.0, trade_count: 6}
    message = Evaluation.verdict_message(:fail, metrics, false)

    assert message =~ "FAIL"
    assert message =~ "4.0"
    assert message =~ "7.0"
    assert message =~ "6"
  end
end
