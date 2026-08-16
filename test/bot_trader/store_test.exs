defmodule BotTrader.StoreTest do
  use ExUnit.Case, async: false

  alias BotTrader.{Repo, Store}

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
    Repo.delete_all(BotTrader.PollerState)
    :ok
  end

  test "run lifecycle persists" do
    {:ok, run} = Store.start_run(:standard)
    assert run.kind == "standard"
    assert run.started_at != nil
    assert run.status == "running"

    assert :ok = Store.finish_run(run, "ok", 7)
    refreshed = Repo.get!(BotTrader.Run, run.id)
    assert refreshed.status == "ok"
    assert refreshed.finished_at != nil
    assert refreshed.calls == 7
  end

  test "signal rows link to run" do
    {:ok, run} = Store.start_run(:standard)

    {:ok, signal} =
      Store.insert_signal(run, %{
        symbol: "BTC",
        action: "BUY",
        confidence: 0.8,
        model: "deepseek-v4-flash",
        price: 100.0,
        rationale: "r"
      })

    assert signal.run_id == run.id
    assert signal.model == "deepseek-v4-flash"
  end

  test "hourly delta aggregate" do
    {:ok, run} = Store.start_run(:standard)
    now = DateTime.utc_now()

    Store.insert_snapshot(run, %{
      ts: DateTime.add(now, -90 * 60, :second),
      equity: 1000.0,
      cash: 1000.0,
      realized_pnl: 0.0
    })

    Store.insert_snapshot(run, %{
      ts: DateTime.add(now, -45 * 60, :second),
      equity: 1020.0,
      cash: 1020.0,
      realized_pnl: 0.0
    })

    Store.insert_snapshot(run, %{ts: now, equity: 1030.0, cash: 1030.0, realized_pnl: 0.0})

    {:ok, trade_run} = Store.start_run(:standard)

    Store.insert_trade(%{
      run_id: trade_run.id,
      symbol: "BTC",
      side: "BUY",
      quantity: 1.0,
      price: 100.0,
      fee: 0.1,
      ts: now
    })

    delta = Store.hourly_delta(now)
    assert_in_delta delta.equity_delta, 10.0, 1.0e-6
    assert delta.trade_count == 1
  end

  test "monthly diary rows" do
    {:ok, run} = Store.start_run(:standard)
    today = Date.utc_today()

    Enum.each(1..30, fn days_ago ->
      date = Date.add(today, -days_ago)
      ts = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")

      Store.insert_snapshot(run, %{
        ts: ts,
        equity: 1000.0 + (30 - days_ago),
        cash: 1000.0,
        realized_pnl: 0.0
      })
    end)

    rows = Store.month_diary(30, DateTime.utc_now())
    assert length(rows) == 30
    assert rows |> List.first() |> Map.has_key?(:date)
    assert rows |> List.first() |> Map.has_key?(:equity)
    assert rows |> List.first() |> Map.has_key?(:pnl)
    assert rows |> List.first() |> Map.has_key?(:trades)
  end

  test "call counter accumulates per day" do
    {:ok, run} = Store.start_run(:standard)
    Store.finish_run(run, "ok", 3)
    {:ok, run2} = Store.start_run(:standard)
    Store.finish_run(run2, "ok", 4)

    assert Store.calls_today(DateTime.utc_now()) == 7
  end

  test "poller offset persists" do
    assert {:ok, nil} = Store.get_poller_offset()
    assert :ok = Store.put_poller_offset(42)
    assert {:ok, 42} = Store.get_poller_offset()
  end

  test "last run age computed" do
    now = DateTime.utc_now()
    {:ok, run} = Store.start_run(:standard)
    Store.finish_run(run, "ok", 1)

    started = run.started_at
    age = Store.last_run_age_minutes(DateTime.add(started, 10 * 60, :second))
    assert age != nil
    assert age <= 10 and age >= 9
  end
end
