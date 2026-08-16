defmodule BotTrader.TelegramPollerTest do
  use ExUnit.Case, async: false

  alias BotTrader.Telegram.Poller

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  setup do
    BotTrader.Repo.delete_all(BotTrader.PollerState)
    :ok
  end

  defp update(id, text, chat_id \\ "6767561953") do
    %{"update_id" => id, "message" => %{"text" => text, "chat" => %{"id" => chat_id}}}
  end

  test "polls and replies to commands" do
    parent = self()

    fetch_fun = fn offset ->
      send(parent, {:fetch_offset, offset})
      {:ok, [update(5, "/status", "111")]}
    end

    send_fun = fn chat_id, text ->
      send(parent, {:sent, chat_id, text})
      :ok
    end

    ctx_builder = fn _message ->
      %{
        status: %{equity: 1000.0, positions: [], last_run_minutes_ago: 1},
        hour: %{equity_delta: 0.0, trade_count: 0},
        day: %{equity: 1000.0, pnl: 0.0, trades: 0},
        month: [],
        force: fn -> :started end
      }
    end

    {:ok, pid} =
      Poller.start_link(
        fetch_fun: fetch_fun,
        send_fun: send_fun,
        ctx_builder: ctx_builder,
        set_commands_fun: fn _ -> :ok end,
        poll_ms: 10,
        poll_once: true,
        name: nil
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    assert_receive {:fetch_offset, offset} when is_integer(offset) or offset == 0, 500
    assert_receive {:sent, "111", text}, 500
    assert text =~ "1000"
    assert {:ok, 6} = BotTrader.Store.get_poller_offset()
  end

  test "offset persists across restart" do
    parent = self()
    BotTrader.Store.put_poller_offset(10)

    fetch_fun = fn offset ->
      send(parent, {:fetch_offset, offset})
      {:ok, []}
    end

    {:ok, pid} =
      Poller.start_link(
        fetch_fun: fetch_fun,
        send_fun: fn _, _ -> :ok end,
        ctx_builder: fn _ -> nil end,
        set_commands_fun: fn _ -> :ok end,
        poll_ms: 10,
        poll_once: true,
        name: nil
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    assert_receive {:fetch_offset, 11}, 500
  end

  test "registers bot commands on start" do
    parent = self()

    {:ok, pid} =
      Poller.start_link(
        fetch_fun: fn _ -> {:ok, []} end,
        send_fun: fn _, _ -> :ok end,
        ctx_builder: fn _ -> nil end,
        set_commands_fun: fn commands ->
          send(parent, {:commands, commands})
          :ok
        end,
        poll_ms: 3_600_000,
        poll_once: true,
        name: nil
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    assert_receive {:commands, commands}, 500
    names = Enum.map(commands, & &1.command)
    assert Enum.sort(names) == Enum.sort(["status", "hour", "day", "month", "force"])
  end

  test "ignores non-command messages" do
    parent = self()

    fetch_fun = fn _offset ->
      {:ok, [update(7, "random text", "222")]}
    end

    send_fun = fn chat_id, text ->
      send(parent, {:sent, chat_id, text})
      :ok
    end

    {:ok, pid} =
      Poller.start_link(
        fetch_fun: fetch_fun,
        send_fun: send_fun,
        ctx_builder: fn _ -> nil end,
        set_commands_fun: fn _ -> :ok end,
        poll_ms: 10,
        poll_once: true,
        name: nil
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    refute_receive {:sent, _, _}, 300
    assert {:ok, 8} = BotTrader.Store.get_poller_offset()
  end
end
