defmodule BotTrader.SchedulerTest do
  use ExUnit.Case, async: true

  alias BotTrader.Scheduler

  defp start_scheduler(opts) do
    parent = self()

    run_fun = fn kind ->
      send(parent, {:run_started, kind})
      {:ok, %{}}
    end

    Scheduler.start_link(
      Keyword.merge(
        [
          run_fun: run_fun,
          tick_ms: 3_600_000,
          name: nil
        ],
        opts
      )
    )
  end

  test "tick triggers standard run" do
    {:ok, pid} = start_scheduler(now: fn -> ~U[2026-08-16 10:00:00Z] end)

    send(pid, :tick)
    assert_receive {:run_started, :standard}
  end

  test "overlap skipped" do
    parent = self()

    run_fun = fn _kind ->
      send(parent, {:run_started, :standard})

      receive do
        :release -> :ok
      end
    end

    {:ok, pid} =
      Scheduler.start_link(
        run_fun: run_fun,
        tick_ms: 3_600_000,
        name: nil,
        now: fn -> ~U[2026-08-16 10:00:00Z] end
      )

    send(pid, :tick)
    assert_receive {:run_started, :standard}

    send(pid, :tick)
    refute_receive {:run_started, _}, 50
    send(pid, {:release_to_parent, parent})
    send(parent, :release)
    send(pid, {:run_done, make_ref(), {:ok, %{}}})
  end

  test "forced run queued during busy" do
    parent = self()

    run_fun = fn kind ->
      send(parent, {:run_started, kind})

      if kind == :standard do
        receive do
          :release -> :ok
        end
      end
    end

    {:ok, pid} =
      Scheduler.start_link(
        run_fun: run_fun,
        tick_ms: 3_600_000,
        name: nil,
        now: fn -> ~U[2026-08-16 10:00:00Z] end
      )

    send(pid, :tick)
    assert_receive {:run_started, :standard}

    assert :queued = Scheduler.force(pid)
    refute_receive {:run_started, :forced}, 50

    send(parent, :release)
    send(pid, {:run_done, make_ref(), {:ok, %{}}})
    assert_receive {:run_started, :forced}
  end

  test "forced run immediate when idle" do
    {:ok, pid} = start_scheduler(now: fn -> ~U[2026-08-16 10:00:00Z] end)

    assert :started = Scheduler.force(pid)
    assert_receive {:run_started, :forced}
  end

  test "deep run at 2130 utc" do
    {:ok, pid} = start_scheduler(now: fn -> ~U[2026-08-16 21:30:00Z] end)

    send(pid, :tick)
    assert_receive {:run_started, :deep}
  end

  test "only one deep run per day" do
    {:ok, pid} = start_scheduler(now: fn -> ~U[2026-08-16 21:31:00Z] end)

    send(pid, :tick)
    assert_receive {:run_started, :deep}
    send(pid, {:run_done, make_ref(), {:ok, %{}}})

    send(pid, :tick)
    assert_receive {:run_started, :standard}
  end
end
