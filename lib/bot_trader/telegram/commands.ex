defmodule BotTrader.Telegram.Commands do
  @moduledoc """
  Pure slash-command dispatch. Handlers are functions of a prebuilt
  context map (built by the Poller from Store/State/Scheduler).
  """

  alias BotTrader.Config

  def dispatch("/status", ctx) do
    s = ctx.status
    positions = Enum.join(s.positions, ", ")

    {:reply,
     "📊 Status\nEquity: #{fmt(s.equity)} | Positions: #{positions} | Last run: #{s.last_run_minutes_ago || "?"} min ago"}
  end

  def dispatch("/hour", ctx) do
    h = ctx.hour

    {:reply,
     "⏱ Last hour: #{sign(h.equity_delta)}#{fmt(abs(h.equity_delta))} | #{h.trade_count} trades"}
  end

  def dispatch("/day", ctx) do
    d = ctx.day

    {:reply,
     "📅 Today: equity #{fmt(d.equity)} | P&L #{sign(d.pnl)}#{fmt(abs(d.pnl))} | #{d.trades} trades"}
  end

  def dispatch("/month", ctx) do
    rows =
      Enum.map_join(ctx.month, "\n", fn row ->
        "#{row.date} | #{fmt(row.equity)} | #{sign(row.pnl)}#{fmt(abs(row.pnl))} | #{row.trades} trades"
      end)

    gate_days = max(0, Config.gate_days() - length(ctx.month))

    {:reply, "📆 Month diary\n#{rows}\n\nGate evaluation in #{gate_days} days"}
  end

  def dispatch("/force", ctx) do
    case ctx.force.() do
      :started -> {:reply, "Forced run started"}
      :queued -> {:reply, "Forced run queued (a run is executing)"}
    end
  end

  def dispatch("/positions" <> rest, ctx) do
    page =
      case rest |> String.trim() do
        "" -> 1
        number -> String.to_integer(number)
      end

    {open, trades, total_pages, resolved_page} = ctx.positions.(page)

    if resolved_page > total_pages do
      {:reply, "no such page"}
    else
      open_section =
        case open do
          [] ->
            "No open positions"

          positions ->
            "Open now:\n" <>
              Enum.map_join(positions, "\n", fn p ->
                "  #{p.symbol} qty=#{p.quantity} entry=#{fmt(p.entry)} unrealized=#{fmt(p.unrealized)}"
              end)
        end

      history =
        Enum.map_join(trades, "\n", fn t ->
          pnl = if t[:realized_pnl], do: " pnl=#{fmt(t[:realized_pnl])}", else: ""

          "  #{t.symbol} #{t.side} qty=#{t.quantity} price=#{fmt(t.price)} fee=#{fmt(t.fee)}#{pnl}"
        end)

      {:reply, "#{open_section}\n\nHistory (page #{resolved_page}/#{total_pages}):\n#{history}"}
    end
  end

  def dispatch(_text, _ctx), do: {:no_reply, nil}

  defp fmt(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp fmt(value), do: to_string(value)

  defp sign(value) when value >= 0, do: "+"
  defp sign(_), do: "-"
end
