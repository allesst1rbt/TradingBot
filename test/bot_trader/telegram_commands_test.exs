defmodule BotTrader.TelegramCommandsTest do
  use ExUnit.Case, async: true

  alias BotTrader.Telegram.Commands

  defp ctx do
    %{
      status: %{equity: 1030.0, positions: ["BTC"], last_run_minutes_ago: 2},
      hour: %{equity_delta: 5.0, trade_count: 1},
      day: %{equity: 1030.0, pnl: 12.0, trades: 3},
      month: [
        %{date: ~D[2026-08-16], equity: 1030.0, pnl: 12.0, trades: 3},
        %{date: ~D[2026-08-15], equity: 1018.0, pnl: -2.0, trades: 1}
      ],
      force: fn -> :started end
    }
  end

  test "dispatches /status reply" do
    assert {:reply, text} = Commands.dispatch("/status", ctx())
    assert text =~ "1030"
    assert text =~ "BTC"
    assert text =~ "2"
  end

  test "/hour returns delta from store" do
    assert {:reply, text} = Commands.dispatch("/hour", ctx())
    assert text =~ "5.0"
    assert text =~ "1"
  end

  test "/day returns diary" do
    assert {:reply, text} = Commands.dispatch("/day", ctx())
    assert text =~ "12.0"
    assert text =~ "3"
  end

  test "/month lists rows with gate countdown" do
    assert {:reply, text} = Commands.dispatch("/month", ctx())
    assert text =~ "2026-08-16"
    assert text =~ "2026-08-15"
    assert text =~ "Gate"
  end

  test "/force acks and triggers" do
    parent = self()

    ctx =
      ctx()
      |> Map.put(:force, fn ->
        send(parent, :forced)
        :started
      end)

    assert {:reply, text} = Commands.dispatch("/force", ctx)
    assert text =~ "Forced run started"
    assert_received :forced
  end

  test "force ack when queued" do
    ctx = Map.put(ctx(), :force, fn -> :queued end)
    assert {:reply, text} = Commands.dispatch("/force", ctx)
    assert text =~ "queued"
  end

  test "ignores non-command" do
    assert {:no_reply, _} = Commands.dispatch("hello there", ctx())
  end
end
