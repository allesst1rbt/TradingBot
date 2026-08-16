defmodule BotTrader.BacktestTest do
  use ExUnit.Case, async: true

  alias BotTrader.Backtest

  @candles Enum.map(0..89, fn i ->
             %{
               ts: DateTime.add(~U[2026-01-01 00:00:00Z], i, :day),
               open: 100.0 + i,
               high: 101.0 + i,
               low: 99.0 + i,
               close: 100.0 + i,
               volume: 1000.0
             }
           end)

  defp deps(state_dir \\ nil, overrides \\ %{}) do
    base = %{
      entry: %{symbol: "BTC", asset_class: :crypto, coin_id: "bitcoin"},
      candles: fn _symbol, _days -> {:ok, @candles} end,
      llm: fn _messages -> raise "LLM must not be called in backtest" end,
      strategy: fn _candles, i, portfolio ->
        cond do
          i == 0 and portfolio.positions == [] -> :buy
          i == 89 -> :close
          true -> :hold
        end
      end
    }

    if state_dir, do: Map.merge(base, %{state_dir: state_dir} |> Map.merge(overrides)), else: base
  end

  test "deterministic metrics on fixture" do
    assert {:ok, metrics} = Backtest.run(deps())

    assert metrics.trade_count == 2

    qty = 2.0 * (1 - 0.0005)
    fee_buy = 200.0 * 0.001
    proceeds = qty * 189.0 * (1 - 0.0005)
    fee_close = proceeds * 0.001
    final_cash = 1000.0 - 200.0 - fee_buy + proceeds - fee_close
    first_equity = 1000.0 - 200.0 - fee_buy + qty * 100.0

    assert_in_delta metrics.return_pct, (final_cash - first_equity) / first_equity * 100.0, 1.0e-6
    assert_in_delta metrics.max_drawdown_pct, 0.0, 1.0e-9
  end

  test "never calls llm" do
    assert {:ok, _} = Backtest.run(deps())
  end

  test "never touches live state" do
    dir =
      Path.join(System.tmp_dir!(), "bot_trader_backtest_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    portfolio_file = Path.join(dir, "portfolio.json")
    trades_file = Path.join(dir, "trades.json")
    File.write!(portfolio_file, "{\"cash\": 1000.0, \"positions\": []}")
    File.write!(trades_file, "[]")

    before_p = File.read!(portfolio_file)
    before_t = File.read!(trades_file)

    assert {:ok, _} = Backtest.run(deps(dir))
    assert File.read!(portfolio_file) == before_p
    assert File.read!(trades_file) == before_t
    assert Enum.sort(File.ls!(dir)) == ["portfolio.json", "trades.json"]
  end
end
