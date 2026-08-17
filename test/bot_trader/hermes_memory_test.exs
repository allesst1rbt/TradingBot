defmodule BotTrader.HermesMemoryTest do
  use ExUnit.Case, async: true

  alias BotTrader.HermesMemory

  setup do
    dir = Path.join(System.tmp_dir!(), "hermes_memory_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  defp trade do
    %{
      symbol: "BTC",
      side: "BUY",
      quantity: 0.1,
      price: 100.0,
      fee: 0.1,
      realized_pnl: nil,
      reason: :signal,
      ts: ~U[2026-08-16 12:00:00Z]
    }
  end

  test "appends trade with rationale", %{dir: dir} do
    path = Path.join(dir, "memory.md")

    assert :ok = HermesMemory.append_trade(trade(), "uptrend confirmed", path: path)

    content = File.read!(path)
    assert content =~ "BUY"
    assert content =~ "BTC"
    assert content =~ "0.1"
    assert content =~ "uptrend confirmed"
    assert content =~ "2026-08-16"
  end

  test "creates file when missing", %{dir: dir} do
    path = Path.join(dir, "nested/memory.md")

    assert :ok = HermesMemory.append_trade(trade(), "r", path: path)
    assert File.exists?(path)
  end

  test "atomic write leaves no tmp", %{dir: dir} do
    path = Path.join(dir, "memory.md")
    assert :ok = HermesMemory.append_trade(trade(), "r", path: path)

    leftovers = File.ls!(dir) |> Enum.filter(&String.contains?(&1, ".tmp"))
    assert leftovers == []
  end

  test "returns error on unwritable path" do
    assert {:error, _} = HermesMemory.append_trade(trade(), "r", path: "/dev/null/nope/mem.md")
  end

  test "closed trade includes pnl and reason", %{dir: dir} do
    path = Path.join(dir, "memory.md")
    closed = %{trade() | side: "CLOSE", realized_pnl: 12.5, reason: :stop_loss}

    assert :ok = HermesMemory.append_trade(closed, "r", path: path)
    content = File.read!(path)
    assert content =~ "CLOSE"
    assert content =~ "12.5"
    assert content =~ "stop_loss"
  end
end
