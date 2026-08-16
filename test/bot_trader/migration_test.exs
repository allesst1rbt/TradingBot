defmodule BotTrader.MigrationTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias BotTrader.{Migration, Repo, Store}

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  setup do
    Repo.delete_all(BotTrader.Signal)
    Repo.delete_all(BotTrader.News)
    Repo.delete_all(BotTrader.Snapshot)
    Repo.delete_all(BotTrader.Trade)
    Repo.delete_all(BotTrader.Run)
    :ok
  end

  test "imports legacy json and archives files" do
    dir = Path.join(System.tmp_dir!(), "migration_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    portfolio = %{
      "cash" => 950.0,
      "positions" => [
        %{
          "symbol" => "BTC",
          "asset_class" => "crypto",
          "quantity" => 0.05,
          "entry_price" => 1000.0
        }
      ],
      "realized_pnl" => -5.0
    }

    trades = [
      %{
        "symbol" => "BTC",
        "side" => "BUY",
        "quantity" => 0.05,
        "price" => 1000.0,
        "fee" => 0.05,
        "ts" => "2026-08-15T10:00:00Z"
      }
    ]

    snapshots = [
      %{"date" => "2026-08-15", "equity" => 995.0, "cash" => 950.0, "realized_pnl" => -5.0}
    ]

    File.write!(Path.join(dir, "portfolio.json"), Jason.encode!(portfolio))
    File.write!(Path.join(dir, "trades.json"), Jason.encode!(trades))
    File.write!(Path.join(dir, "snapshots.json"), Jason.encode!(snapshots))

    assert :ok = Migration.run(dir)

    refute File.exists?(Path.join(dir, "portfolio.json"))
    refute File.exists?(Path.join(dir, "trades.json"))
    refute File.exists?(Path.join(dir, "snapshots.json"))
    assert File.exists?(Path.join(dir, "portfolio.json.archived"))

    assert Repo.one(from(t in BotTrader.Snapshot, select: count(t.id))) == 2
    assert Repo.one(from(t in BotTrader.Trade, select: count(t.id))) == 2
  end

  test "second boot with no json is no-op" do
    dir = Path.join(System.tmp_dir!(), "migration_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    assert :ok = Migration.run(dir)
    assert Repo.one(from(t in BotTrader.Trade, select: count(t.id))) == 0
  end

  test "corrupt json aborts without archiving" do
    dir = Path.join(System.tmp_dir!(), "migration_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    File.write!(Path.join(dir, "portfolio.json"), "{corrupt")

    assert {:error, :corrupt_state} = Migration.run(dir)
    assert File.exists?(Path.join(dir, "portfolio.json"))
  end
end
