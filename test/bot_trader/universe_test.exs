defmodule BotTrader.UniverseTest do
  use ExUnit.Case, async: false

  alias BotTrader.Universe

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  setup do
    BotTrader.Repo.delete_all(BotTrader.WatchlistEntry)
    :ok
  end

  test "loads universe with both asset classes" do
    {:ok, entries} = Universe.load_universe()
    assert length(entries) >= 500
    assert Enum.any?(entries, &(&1.asset_class == "stock-br"))
    assert Enum.any?(entries, &(&1.asset_class == "stock-us"))
  end

  test "picks highest mover not in watchlist" do
    quotes = [
      %{symbol: "AAA", day_change_pct: 6.5, volume: 5_000_000},
      %{symbol: "BBB", day_change_pct: 3.0, volume: 500_000},
      %{symbol: "CCC", day_change_pct: 8.0, volume: 1_000_000}
    ]

    assert {:ok, "BBB"} = Universe.pick_candidate(quotes, ["AAA", "CCC"])
  end

  test "volume bonus breaks near ties" do
    quotes = [
      %{symbol: "AAA", day_change_pct: 2.0, volume: 10_000_000},
      %{symbol: "BBB", day_change_pct: 2.5, volume: 100_000}
    ]

    assert {:ok, "AAA"} = Universe.pick_candidate(quotes, [])
  end

  test "returns none when all in watchlist" do
    quotes = [%{symbol: "AAA", day_change_pct: 6.5, volume: 5_000_000}]
    assert :none = Universe.pick_candidate(quotes, ["AAA"])
  end

  test "scan and add grows store" do
    quotes_fun = fn _symbols ->
      {:ok, [%{symbol: "ZZZZ", day_change_pct: 9.9, volume: 5_000_000}]}
    end

    assert {:ok, "ZZZZ"} = Universe.scan_and_add(quotes_fun: quotes_fun)

    watchlist = BotTrader.Store.get_watchlist()
    assert Enum.any?(watchlist, &(&1.symbol == "ZZZZ"))
  end

  test "scan failure non-fatal" do
    quotes_fun = fn _symbols -> {:error, :http_error} end

    assert :none = Universe.scan_and_add(quotes_fun: quotes_fun)
    assert BotTrader.Store.get_watchlist() == []
  end
end
