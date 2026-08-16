defmodule BotTrader.Telegram.Poller do
  @moduledoc """
  Long-polling getUpdates loop. Persists the offset in the DB, dispatches
  slash commands, replies via the injected sender. Registers the bot
  command menu on start.
  """

  use GenServer

  alias BotTrader.{Store, Telegram}

  @commands [
    %{command: "status", description: "Current equity, positions, last run"},
    %{command: "hour", description: "Equity change over the last hour"},
    %{command: "day", description: "Today's diary"},
    %{command: "month", description: "30-day diary and gate countdown"},
    %{command: "force", description: "Run the analysis pipeline now"}
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
       poll_ms: opts[:poll_ms] || 25_000
     }}
  end

  @impl true
  def handle_info(:poll, state) do
    Process.send_after(self(), :poll, state.poll_ms)

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

    Store.put_poller_offset(update_id + 1)
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
      day: Store.day_diary(DateTime.to_date(now)),
      month: Store.month_diary(30, now),
      force: fn -> BotTrader.Scheduler.force(BotTrader.Scheduler) end
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
    with {:ok, portfolio} <- BotTrader.State.read(BotTrader.Config.state_dir(), :portfolio, %{}),
         positions <- portfolio[:positions] || [] do
      Enum.map(positions, & &1[:symbol])
    else
      _ -> []
    end
  end
end
