defmodule BotTrader.Telegram.Poller do
  @moduledoc """
  Long-polling getUpdates loop. Persists the offset in the DB, dispatches
  slash commands, replies via the injected sender. Registers the bot
  command menu on start.
  """

  use GenServer

  alias BotTrader.{Store, Telegram}

  require Logger

  @commands [
    %{command: "status", description: "Current equity, positions, last run"},
    %{command: "hour", description: "Equity change over the last hour"},
    %{command: "day", description: "Today's trades, P&L and open positions"},
    %{command: "week", description: "Last 7 days summary"},
    %{command: "month", description: "Last 30 days summary"},
    %{command: "force", description: "Run the analysis pipeline now"},
    %{command: "positions", description: "Open positions and trade history"}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    set_commands_fun = opts[:set_commands_fun] || (&Telegram.set_my_commands/1)
    set_commands_fun.(@commands)

    send(self(), :poll)

    {:ok,
     %{
       fetch_fun: opts[:fetch_fun] || (&Telegram.get_updates/1),
       send_fun: opts[:send_fun] || (&Telegram.send_message_to_chat/2),
       ctx_builder: opts[:ctx_builder] || (&Telegram.Poller.build_ctx/1),
       poll_ms: opts[:poll_ms] || 25_000,
       poll_once: opts[:poll_once] || false
     }}
  end

  @impl true
  def handle_info(:poll, state) do
    unless state.poll_once do
      Process.send_after(self(), :poll, state.poll_ms)
    end

    case state.fetch_fun.(next_offset()) do
      {:ok, updates} ->
        Enum.each(updates, &process_update(&1, state))
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp process_update(update, state) do
    update_id = update["update_id"]

    try do
      handle_update_message(update, state)
      Store.put_poller_offset(update_id + 1)
    rescue
      e ->
        Logger.error("update #{update_id} processing failed: #{Exception.message(e)}")
    end
  end

  defp handle_update_message(update, state) do
    message = update["message"]

    if is_map(message) do
      chat_id = get_in(message, ["chat", "id"])
      text = message["text"]

      ctx = state.ctx_builder.(message)

      if is_binary(text) and is_map(ctx) do
        case Telegram.Commands.dispatch(text, ctx) do
          {:reply, reply} -> state.send_fun.(chat_id, reply)
          {:no_reply, _} -> :ok
        end
      end
    end
  end

  defp next_offset do
    case Store.get_poller_offset() do
      {:ok, nil} -> 0
      {:ok, offset} -> offset + 1
    end
  end

  def build_ctx(_message) do
    now = DateTime.utc_now()

    %{
      status: %{
        equity: latest_equity(),
        positions: open_positions(),
        last_run_minutes_ago: Store.last_run_age_minutes(now)
      },
      hour: Store.hourly_delta(now),
      day:
        Store.period_summary(DateTime.new!(DateTime.to_date(now), ~T[00:00:00], "Etc/UTC"), now),
      week: Store.period_summary(DateTime.add(now, -7 * 24 * 3600, :second), now),
      month: Store.period_summary(DateTime.add(now, -30 * 24 * 3600, :second), now),
      force: fn -> BotTrader.Scheduler.force(BotTrader.Scheduler) end,
      positions: fn page ->
        {open, trades, total_pages} = BotTrader.Store.positions_page(page, 20)
        {open, trades, total_pages, page}
      end
    }
  end

  defp latest_equity do
    import Ecto.Query

    case BotTrader.Repo.one(from(s in BotTrader.Snapshot, order_by: [desc: s.ts], limit: 1)) do
      nil -> 1000.0
      snapshot -> snapshot.equity
    end
  end

  defp open_positions do
    BotTrader.Store.open_positions() |> Enum.map(& &1.symbol)
  end
end
