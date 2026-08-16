defmodule BotTrader.StateTest do
  use ExUnit.Case, async: false

  alias BotTrader.State

  setup do
    dir =
      Path.join(System.tmp_dir!(), "bot_trader_state_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  test "round-trip preserves portfolio", %{dir: dir} do
    portfolio = %{
      cash: 900.0,
      positions: [
        %{symbol: "BTC", quantity: 0.1, entry_price: 1000.0},
        %{symbol: "AAPL", quantity: 2, entry_price: 200.0}
      ],
      realized_pnl: -5.5
    }

    assert :ok = State.write(dir, :portfolio, portfolio)
    assert {:ok, ^portfolio} = State.read(dir, :portfolio)
  end

  test "round-trip preserves trades and snapshots", %{dir: dir} do
    trades = [%{symbol: "BTC", side: "BUY", quantity: 0.1, price: 1000.0}]
    snapshots = [%{date: "2026-08-16", equity: 1000.0}]

    assert :ok = State.write(dir, :trades, trades)
    assert :ok = State.write(dir, :snapshots, snapshots)
    assert {:ok, ^trades} = State.read(dir, :trades)
    assert {:ok, ^snapshots} = State.read(dir, :snapshots)
  end

  test "corrupt file aborts without overwrite", %{dir: dir} do
    portfolio = %{cash: 1000.0, positions: [], realized_pnl: 0.0}
    assert :ok = State.write(dir, :portfolio, portfolio)

    file = State.path(dir, :portfolio)
    original = File.read!(file)
    File.write!(file, "{not valid json")

    assert {:error, :corrupt_state} = State.read(dir, :portfolio)
    assert File.read!(file) == "{not valid json"
    refute original == "{not valid json"
  end

  test "write is atomic and leaves no temp files", %{dir: dir} do
    assert :ok = State.write(dir, :portfolio, %{cash: 500.0})
    leftovers = File.ls!(dir) |> Enum.filter(&String.ends_with?(&1, ".tmp"))
    assert leftovers == []
  end

  test "missing file returns empty default", %{dir: dir} do
    assert {:ok, %{}} = State.read(dir, :portfolio, %{})
    assert {:ok, []} = State.read(dir, :trades, [])
  end
end
