defmodule BotTrader.TradingViewStore do
  import Ecto.Query

  alias BotTrader.{Repo, TradingViewCursor, TradingViewSnapshot}

  def insert_snapshot(attrs) do
    attrs =
      Map.update(
        attrs,
        :timestamp,
        DateTime.truncate(DateTime.utc_now(), :second),
        &DateTime.truncate(&1, :second)
      )

    Repo.insert(Ecto.Changeset.change(%TradingViewSnapshot{}, attrs))
  end

  def latest_snapshot(symbol) do
    from(s in TradingViewSnapshot,
      where: s.symbol == ^symbol,
      order_by: [desc: s.timestamp],
      limit: 1
    )
    |> Repo.one()
  end

  def recent_snapshots(symbol, limit) do
    from(s in TradingViewSnapshot,
      where: s.symbol == ^symbol,
      order_by: [desc: s.timestamp],
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_cursor(key) do
    case Repo.get(TradingViewCursor, key) do
      nil -> {:ok, 0}
      cursor -> {:ok, cursor.position}
    end
  end

  def put_cursor(key, position) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    %TradingViewCursor{key: key, position: position, updated_at: now}
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:key])
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
