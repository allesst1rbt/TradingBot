defmodule BotTrader.Potentials.Report do
  @moduledoc "Compact once-per-cycle Telegram report of screened potentials."

  def build(snapshots) do
    lines =
      snapshots
      |> Enum.reject(&Map.get(&1, :stale, false))
      |> Enum.reject(&is_nil(&1.price))
      |> Enum.map_join("\n", fn s ->
        rating = Map.get(s, :technical_rating) || "n/a"
        "  #{s.symbol} #{s.price} #{s.change_pct}% #{rating}"
      end)

    if lines == "" do
      "No potentials available this cycle."
    else
      "Observed potentials:\n#{lines}"
    end
  end
end
