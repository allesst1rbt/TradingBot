defmodule BotTrader.NewsStore do
  @moduledoc "Structured TradingView news rows with dedup and pruning."

  import Ecto.Query

  alias BotTrader.{NewsRunnerRow, Repo}

  def insert(attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    hash = hash_for(attrs[:symbol], attrs[:headline])

    changeset =
      %NewsRunnerRow{}
      |> Ecto.Changeset.change(
        symbol: attrs[:symbol],
        headline: attrs[:headline],
        source: attrs[:source],
        timestamp: attrs[:timestamp] && DateTime.truncate(attrs[:timestamp], :second),
        sentiment: attrs[:sentiment] || "neutral",
        hash: hash,
        inserted_at: now
      )

    case Repo.insert(changeset, on_conflict: :nothing, conflict_target: [:hash]) do
      {:ok, row} ->
        if is_nil(row.id) do
          case Repo.get_by(NewsRunnerRow, hash: hash) do
            nil -> {:ok, row}
            existing -> {:ok, existing}
          end
        else
          {:ok, row}
        end

      {:error, _} ->
        {:error, :duplicate}
    end
  end

  def latest(symbol, limit) do
    from(n in NewsRunnerRow,
      where: n.symbol == ^symbol,
      order_by: [desc: n.timestamp],
      limit: ^limit
    )
    |> Repo.all()
  end

  def prune(symbol, keep) do
    ids =
      from(n in NewsRunnerRow,
        where: n.symbol == ^symbol,
        order_by: [desc: n.timestamp],
        limit: 10_000,
        offset: ^keep,
        select: n.id
      )
      |> Repo.all()

    if ids != [] do
      from(n in NewsRunnerRow, where: n.id in ^ids) |> Repo.delete_all()
    end

    :ok
  end

  defp hash_for(symbol, headline),
    do: :crypto.hash(:sha256, "#{symbol}|#{headline}") |> Base.encode16()
end
