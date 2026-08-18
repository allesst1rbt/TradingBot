defmodule BotTrader.PotentialsReportCycleTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Scheduler

  test "wrap triggers one report" do
    parent = self()

    entries = [
      %{symbol: "VIVT3", asset_class: :stock_br},
      %{symbol: "PETR4", asset_class: :stock_br}
    ]

    on_wrap_fn = fn ->
      send(parent, {:report, "wrapped"})
    end

    {:ok, pid} =
      Scheduler.start_link(
        entries: entries,
        batch_size: 2,
        scrape_fun: fn _batch ->
          [
            %{
              symbol: "VIVT3",
              price: 42.5,
              change_pct: 1.0,
              technical_rating: "buy",
              stale: false
            }
          ]
        end,
        persist_fun: fn _ -> :ok end,
        cursor_fun: fn _ -> :ok end,
        on_wrap: on_wrap_fn,
        tick_ms: 60_000,
        poll_once: true,
        name: nil
      )

    send(pid, :scrape)
    assert_receive {:report, _}, 1000
  end

  test "mid-cycle no report" do
    parent = self()

    entries = for i <- 1..5, do: %{symbol: "S#{i}", asset_class: :stock_br}

    on_wrap_fn = fn -> send(parent, {:report, "wrapped"}) end

    {:ok, pid} =
      Scheduler.start_link(
        entries: entries,
        batch_size: 2,
        scrape_fun: fn _batch ->
          [%{symbol: "S1", price: 10.0, change_pct: 0.5, technical_rating: "buy", stale: false}]
        end,
        persist_fun: fn _ -> :ok end,
        cursor_fun: fn _ -> :ok end,
        on_wrap: on_wrap_fn,
        tick_ms: 60_000,
        poll_once: true,
        name: nil
      )

    send(pid, :scrape)
    send(pid, :scrape)
    refute_received {:report, _}, 200
  end

  test "wrap fires on third scrape with five entries" do
    parent = self()

    entries = for i <- 1..5, do: %{symbol: "S#{i}", asset_class: :stock_br}

    on_wrap_fn = fn -> send(parent, {:report, "wrapped"}) end

    {:ok, pid} =
      Scheduler.start_link(
        entries: entries,
        batch_size: 2,
        scrape_fun: fn _batch ->
          [%{symbol: "S1", price: 10.0, change_pct: 0.5, technical_rating: "buy", stale: false}]
        end,
        persist_fun: fn _ -> :ok end,
        cursor_fun: fn _ -> :ok end,
        on_wrap: on_wrap_fn,
        tick_ms: 60_000,
        poll_once: true,
        name: nil
      )

    send(pid, :scrape)
    refute_received {:report, _}
    send(pid, :scrape)
    refute_received {:report, _}
    send(pid, :scrape)
    assert_receive {:report, _}, 1000
  end
end
