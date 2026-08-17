defmodule BotTrader.TelegramCommandsTest do
  use ExUnit.Case, async: true

  alias BotTrader.Telegram.Commands

  defp summary_ctx do
    %{
      day: %{equity: 1000.0, trades: 3, realized: 5.0, unrealized: 1.2, open_positions: 2},
      week: %{trades: 4, realized: -2.5, unrealized: 0.4, open_positions: 2},
      month: %{trades: 15, realized: 12.0, unrealized: -1.0, open_positions: 2}
    }
  end

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

  test "positions page one with open section" do
    trades =
      for i <- 25..1//-1,
          do: %{
            symbol: "S#{i}",
            side: "BUY",
            quantity: 1.0,
            price: i * 1.0,
            fee: 0.0,
            ts: ~U[2026-08-16 12:00:00Z]
          }

    positions_ctx =
      Map.put(ctx(), :positions, fn page ->
        {[%{symbol: "BTC", quantity: 0.06, entry: 100.0, unrealized: 1.2}], Enum.take(trades, 20),
         2, page}
      end)

    assert {:reply, text} = Commands.dispatch("/positions", positions_ctx)
    assert text =~ "Open now"
    assert text =~ "BTC"
    assert text =~ "page 1/2"
    assert text =~ "S25"
    refute text =~ "S5"
  end

  test "positions page two" do
    trades =
      for i <- 25..1//-1,
          do: %{
            symbol: "S#{i}",
            side: "BUY",
            quantity: 1.0,
            price: i * 1.0,
            fee: 0.0,
            ts: ~U[2026-08-16 12:00:00Z]
          }

    positions_ctx =
      Map.put(ctx(), :positions, fn page ->
        {[], Enum.drop(trades, 20), 2, page}
      end)

    assert {:reply, text} = Commands.dispatch("/positions 2", positions_ctx)
    assert text =~ "page 2/2"
    assert text =~ "S5"
    refute text =~ "S25"
  end

  test "positions out of range" do
    positions_ctx =
      Map.put(ctx(), :positions, fn _page ->
        {[], [], 2, 9}
      end)

    assert {:reply, text} = Commands.dispatch("/positions 9", positions_ctx)
    assert text =~ "no such page"
  end

  test "positions handles ecto trade structs" do
    trade =
      struct(BotTrader.Trade, %{
        symbol: "PETR4",
        side: "BUY",
        quantity: 5.0,
        price: 42.0,
        fee: 5.0,
        realized_pnl: nil,
        ts: ~U[2026-08-16 12:00:00Z]
      })

    positions_ctx =
      Map.put(ctx(), :positions, fn _page ->
        {[], [trade], 1, 1}
      end)

    assert {:reply, text} = Commands.dispatch("/positions", positions_ctx)
    assert text =~ "PETR4"
    assert text =~ "page 1/1"
  end

  test "positions no open" do
    positions_ctx =
      Map.put(ctx(), :positions, fn _page ->
        {[], [], 1, 1}
      end)

    assert {:reply, text} = Commands.dispatch("/positions", positions_ctx)
    assert text =~ "No open positions"
  end

  test "day reply unified" do
    assert {:reply, text} = Commands.dispatch("/day", summary_ctx())
    assert text =~ "Trades: 3"
    assert text =~ "Realized: +5.00"
    assert text =~ "Unrealized: +1.20"
    assert text =~ "Open positions: 2"
    assert text =~ "1000"
  end

  test "week reply no equity" do
    assert {:reply, text} = Commands.dispatch("/week", summary_ctx())
    assert text =~ "Trades: 4"
    assert text =~ "Realized: -2.50"
    assert text =~ "Unrealized: +0.40"
    assert text =~ "Open positions: 2"
    refute text =~ "1000"
  end

  test "month summary only" do
    assert {:reply, text} = Commands.dispatch("/month", summary_ctx())
    assert text =~ "Trades: 15"
    assert text =~ "Realized: +12.00"
    assert text =~ "Unrealized: -1.00"
    assert text =~ "Open positions: 2"
    refute text =~ "Gate evaluation"
  end

  test "ignores non-command" do
    assert {:no_reply, _} = Commands.dispatch("hello there", ctx())
  end
end
