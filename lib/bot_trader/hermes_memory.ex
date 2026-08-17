defmodule BotTrader.HermesMemory do
  @moduledoc """
  Best-effort absorption of the bot's trade activity into Hermes memory.
  Appends facts + signal rationale to a markdown file (atomic temp+rename).
  Failures are returned as error tuples — the caller decides (runner treats
  them as non-fatal).
  """

  alias BotTrader.Config

  def append_trade(trade, rationale, opts \\ []) do
    path = opts[:path] || Config.hermes_memory_path()
    entry = format_entry(trade, rationale)

    try do
      File.mkdir_p!(Path.dirname(path))
      tmp = path <> ".tmp"
      existing = if File.exists?(path), do: File.read!(path), else: ""

      File.write!(tmp, existing <> entry <> "\n")
      File.rename!(tmp, path)
      :ok
    rescue
      e -> {:error, e}
    end
  end

  defp format_entry(trade, rationale) do
    ts = trade.ts |> DateTime.to_iso8601()
    pnl = if trade[:realized_pnl], do: " pnl=#{trade[:realized_pnl]}", else: ""
    reason = if trade[:reason], do: " reason=#{trade[:reason]}", else: ""

    """
    - Trade #{ts}: #{trade.side} #{trade.symbol} qty=#{trade.quantity} price=#{trade.price} fee=#{trade.fee}#{pnl}#{reason}
      Rationale: #{rationale}
    """
    |> String.trim_trailing()
  end
end
