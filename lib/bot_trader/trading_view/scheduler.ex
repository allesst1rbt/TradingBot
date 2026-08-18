defmodule BotTrader.TradingView.Scheduler do
  @moduledoc "Round-robin TradingView batch scheduler with persisted cursor support."

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: opts[:name])

  @impl true
  def init(opts) do
    state = %{
      entries: opts[:entries] || [],
      batch_size: opts[:batch_size] || 25,
      cursor: opts[:cursor] || 0,
      scrape_fun: opts[:scrape_fun] || (&BotTrader.TradingView.Browser.scrape_batch/1),
      persist_fun: opts[:persist_fun] || fn _ -> :ok end,
      cursor_fun: opts[:cursor_fun] || fn _ -> :ok end,
      on_wrap: opts[:on_wrap] || fn -> :ok end,
      tick_ms: opts[:tick_ms] || 300_000
    }

    if opts[:auto_start], do: Process.send_after(self(), :tick, 0)

    {:ok, state}
  end

  @impl true
  def handle_info(:scrape, state) do
    {batch, next_cursor} = next_batch(state.entries, state.cursor, state.batch_size)
    result = state.scrape_fun.(batch)
    state.persist_fun.(result)

    if next_cursor == 0 do
      state.on_wrap.()
    end

    state.cursor_fun.(next_cursor)
    {:noreply, %{state | cursor: next_cursor}}
  end

  def handle_info(:tick, state) do
    send(self(), :scrape)
    Process.send_after(self(), :tick, state.tick_ms)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp next_batch([], _cursor, _size), do: {[], 0}

  defp next_batch(entries, cursor, size) do
    count = length(entries)
    batch_size = min(size, count - cursor)
    batch = Enum.slice(entries, cursor, batch_size)
    next_cursor = if cursor + batch_size >= count, do: 0, else: cursor + batch_size
    {batch, next_cursor}
  end
end
