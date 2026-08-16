defmodule BotTrader.Scheduler do
  @moduledoc """
  In-app 5-minute ticker. Skips ticks while a run executes, collapses
  forced runs into one queued run, and fires the daily deep run at the
  configured UTC time.
  """

  use GenServer

  alias BotTrader.Config

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def force(pid) do
    GenServer.call(pid, :force)
  end

  @impl true
  def init(opts) do
    tick_ms = opts[:tick_ms] || Config.run_interval_ms()
    ref = Process.send_after(self(), :tick, tick_ms)

    {:ok,
     %{
       run_fun: opts[:run_fun] || fn kind -> BotTrader.Runner.run(%{}, kind) end,
       tick_ms: tick_ms,
       timer: ref,
       running: false,
       forced_pending: false,
       last_deep_date: nil,
       now: opts[:now] || (&DateTime.utc_now/0)
     }}
  end

  @impl true
  def handle_call(:force, _from, state) do
    if state.running do
      {:reply, :queued, %{state | forced_pending: true}}
    else
      {:reply, :started, start_run(state, :forced)}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    state = %{state | timer: Process.send_after(self(), :tick, state.tick_ms)}

    cond do
      state.running ->
        {:noreply, state}

      deep_due?(state) ->
        {:noreply, %{start_run(state, :deep) | last_deep_date: Date.utc_today()}}

      true ->
        {:noreply, start_run(state, :standard)}
    end
  end

  def handle_info({:run_done, _ref, _result}, state) do
    if state.forced_pending do
      {:noreply, %{start_run(%{state | running: false}, :forced) | forced_pending: false}}
    else
      {:noreply, %{state | running: false}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp start_run(state, kind) do
    run_fun = state.run_fun
    self_pid = self()
    ref = make_ref()

    Task.start(fn ->
      result =
        try do
          run_fun.(kind)
        catch
          kind, reason -> {:error, {kind, reason}}
        end

      send(self_pid, {:run_done, ref, result})
    end)

    %{state | running: true}
  end

  defp deep_due?(state) do
    now = state.now.()
    now_minutes = now.hour * 60 + now.minute
    deep_minutes = Config.deep_run_hour_utc() * 60 + Config.deep_run_minute_utc()

    now_minutes >= deep_minutes and DateTime.to_date(now) != state.last_deep_date
  end
end
