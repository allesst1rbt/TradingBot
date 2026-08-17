defmodule BotTrader.TradingViewSchedulerTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Scheduler

  test "advances round robin cursor" do
    parent = self()
    entries = for i <- 1..5, do: %{symbol: "S#{i}", asset_class: "stock-us"}

    {:ok, pid} =
      Scheduler.start_link(
        entries: entries,
        batch_size: 2,
        scrape_fun: fn batch ->
          send(parent, {:batch, Enum.map(batch, & &1.symbol)})
          []
        end,
        tick_ms: 3_600_000,
        cursor: 0,
        name: nil
      )

    send(pid, :scrape)
    assert_receive {:batch, ["S1", "S2"]}
    send(pid, :scrape)
    assert_receive {:batch, ["S3", "S4"]}
    send(pid, :scrape)
    assert_receive {:batch, ["S5"]}
  end

  test "wraps after final batch" do
    parent = self()
    entries = for i <- 1..3, do: %{symbol: "S#{i}", asset_class: "stock-us"}

    {:ok, pid} =
      Scheduler.start_link(
        entries: entries,
        batch_size: 2,
        scrape_fun: fn batch ->
          send(parent, {:batch, Enum.map(batch, & &1.symbol)})
          []
        end,
        tick_ms: 3_600_000,
        cursor: 0,
        name: nil
      )

    send(pid, :scrape)
    assert_receive {:batch, ["S1", "S2"]}
    send(pid, :scrape)
    assert_receive {:batch, ["S3"]}
    send(pid, :scrape)
    assert_receive {:batch, ["S1", "S2"]}
  end

  test "retains stale result when scrape returns an error" do
    parent = self()
    entries = [%{symbol: "VIVT3", asset_class: "stock-br"}]

    {:ok, pid} =
      Scheduler.start_link(
        entries: entries,
        batch_size: 1,
        scrape_fun: fn _ ->
          send(parent, :scraped)
          {:error, :blocked}
        end,
        persist_fun: fn result ->
          send(parent, {:persisted, result})
          :ok
        end,
        tick_ms: 3_600_000,
        cursor: 0,
        name: nil
      )

    send(pid, :scrape)
    assert_receive :scraped
    assert_receive {:persisted, {:error, :blocked}}
  end
end
