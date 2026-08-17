defmodule BotTrader.Store do
  @moduledoc """
  All SQLite access for the bot. Compact typed rows via Ecto; aggregates
  for the command handlers; the poller offset; the per-day LLM call counter.
  """

  import Ecto.Query

  alias BotTrader.{News, PollerState, Repo, Run, Signal, Snapshot, Trade, WatchlistEntry}

  def start_run(kind) do
    run =
      %Run{kind: Atom.to_string(kind), started_at: now(), status: "running"}
      |> Repo.insert!()

    {:ok, run}
  end

  def finish_run(run, status, calls) do
    run
    |> Ecto.Changeset.change(status: status, calls: calls, finished_at: now())
    |> Repo.update!()

    :ok
  end

  def insert_signal(run, attrs) do
    {:ok, Repo.insert!(%Signal{} |> Ecto.Changeset.change(Map.merge(attrs, %{run_id: run.id})))}
  end

  def insert_trade(attrs) do
    {:ok, Repo.insert!(%Trade{} |> Ecto.Changeset.change(truncate_ts(attrs)))}
  end

  def insert_snapshot(run, attrs) do
    attrs = Map.merge(attrs, %{run_id: run.id}) |> truncate_ts()
    {:ok, Repo.insert!(%Snapshot{} |> Ecto.Changeset.change(attrs))}
  end

  def insert_news(run, attrs) do
    {:ok, Repo.insert!(%News{} |> Ecto.Changeset.change(Map.merge(attrs, %{run_id: run.id})))}
  end

  def hourly_delta(now) do
    cutoff = DateTime.add(now, -60 * 60, :second)

    current =
      from(s in Snapshot, where: s.ts <= ^now, order_by: [desc: s.ts], limit: 1)
      |> Repo.one()

    baseline =
      from(s in Snapshot,
        where: s.ts <= ^now,
        order_by: fragment("ABS(julianday(?) - julianday(?))", s.ts, ^cutoff),
        limit: 1
      )
      |> Repo.one()

    trade_count =
      from(t in Trade, where: t.ts >= ^cutoff and t.ts <= ^now, select: count(t.id))
      |> Repo.one()

    %{
      equity_delta: ((current && current.equity) || 0.0) - ((baseline && baseline.equity) || 0.0),
      trade_count: trade_count
    }
  end

  def day_diary(date) do
    day_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    last_snapshot =
      from(s in Snapshot,
        where: s.ts >= ^day_start and s.ts <= ^day_end,
        order_by: [desc: s.ts],
        limit: 1
      )
      |> Repo.one()

    pnl =
      from(t in Trade,
        where: t.ts >= ^day_start and t.ts <= ^day_end,
        select: coalesce(sum(t.realized_pnl), 0.0)
      )
      |> Repo.one()

    trades =
      from(t in Trade, where: t.ts >= ^day_start and t.ts <= ^day_end, select: count(t.id))
      |> Repo.one()

    %{equity: last_snapshot && last_snapshot.equity, pnl: pnl, trades: trades}
  end

  def month_diary(days \\ 30, now \\ DateTime.utc_now()) do
    today = DateTime.to_date(now)

    for offset <- (days - 1)..0//-1 do
      day_diary(Date.add(today, -offset))
      |> Map.put(:date, Date.add(today, -offset))
    end
  end

  def calls_today(now \\ DateTime.utc_now()) do
    day_start = DateTime.new!(DateTime.to_date(now), ~T[00:00:00], "Etc/UTC")

    from(r in Run, where: r.started_at >= ^day_start, select: coalesce(sum(r.calls), 0))
    |> Repo.one()
  end

  def put_poller_offset(offset) do
    %PollerState{key: "telegram_offset", value: Integer.to_string(offset)}
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: [:key])

    :ok
  end

  def get_poller_offset do
    case Repo.get(PollerState, "telegram_offset") do
      nil -> {:ok, nil}
      state -> {:ok, String.to_integer(state.value)}
    end
  end

  def put_budget_alert(date_iso) do
    %PollerState{key: "budget_alert", value: date_iso}
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: [:key])

    :ok
  end

  def get_budget_alert do
    case Repo.get(PollerState, "budget_alert") do
      nil -> {:ok, nil}
      state -> {:ok, state.value}
    end
  end

  def last_run_age_minutes(now) do
    case from(r in Run, where: r.status == "ok", order_by: [desc: r.started_at], limit: 1)
         |> Repo.one() do
      nil -> nil
      run -> DateTime.diff(now, run.started_at, :second) |> div(60)
    end
  end

  def count_runs do
    Repo.aggregate(Run, :count, :id)
  end

  def get_watchlist do
    from(w in WatchlistEntry, order_by: [asc: w.id])
    |> Repo.all()
  end

  def add_to_watchlist(symbol, asset_class, coin_id \\ nil, source \\ "candidate") do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    changeset =
      %WatchlistEntry{}
      |> Ecto.Changeset.change(%{
        symbol: symbol,
        asset_class: asset_class,
        coin_id: coin_id,
        added_at: now,
        source: source
      })
      |> Ecto.Changeset.unique_constraint(:symbol, name: :watchlist_symbol_index)

    case Repo.insert(changeset) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :duplicate}
    end
  end

  def seed_watchlist(entries) do
    if Repo.aggregate(WatchlistEntry, :count, :id) == 0 do
      Enum.each(entries, fn entry ->
        add_to_watchlist(entry.symbol, entry.asset_class, entry[:coin_id], "seed")
      end)
    end

    :ok
  end

  def note_run(run, note) do
    run
    |> Ecto.Changeset.change(note: note)
    |> Repo.update!()

    :ok
  end

  def open_positions do
    rows =
      from(t in Trade,
        select: {t.symbol, t.side, t.quantity, t.price, t.realized_pnl},
        order_by: [asc: t.id]
      )
      |> Repo.all()

    rows
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {symbol, trades} ->
      buy_qty =
        trades |> Enum.filter(&(elem(&1, 1) == "BUY")) |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      close_qty =
        trades
        |> Enum.filter(&(elem(&1, 1) in ["SELL", "CLOSE"]))
        |> Enum.map(&elem(&1, 2))
        |> Enum.sum()

      qty = buy_qty - close_qty

      buys = Enum.filter(trades, &(elem(&1, 1) == "BUY"))

      entry =
        if buys == [],
          do: 0.0,
          else:
            Enum.sum(Enum.map(buys, fn t -> elem(t, 2) * elem(t, 3) end)) /
              Enum.sum(Enum.map(buys, &elem(&1, 2)))

      case get_last_signal(symbol) do
        {:ok, %{price: price}} when is_number(price) ->
          %{symbol: symbol, quantity: qty, entry: entry, unrealized: qty * (price - entry)}

        _ ->
          %{symbol: symbol, quantity: qty, entry: entry, unrealized: 0.0}
      end
    end)
    |> Enum.filter(&(&1.quantity > 1.0e-9))
  end

  def list_trades_paginated(page, page_size \\ 20) do
    page = max(page, 1)
    total = Repo.aggregate(Trade, :count, :id)
    total_pages = max(div(total + page_size - 1, page_size), 1)

    trades =
      from(t in Trade,
        order_by: [desc: t.id],
        offset: ^((page - 1) * page_size),
        limit: ^page_size
      )
      |> Repo.all()

    {trades, total_pages}
  end

  def get_last_signal(symbol) do
    case from(s in Signal, where: s.symbol == ^symbol, order_by: [desc: s.id], limit: 1)
         |> Repo.one() do
      nil -> {:ok, nil}
      signal -> {:ok, signal}
    end
  end

  def rolling_context(symbol, now) do
    cutoff = DateTime.add(now, -24 * 3600, :second)

    runs = from(r in Run, where: r.started_at >= ^cutoff, select: count(r.id)) |> Repo.one()

    last_signal =
      from(s in Signal, where: s.symbol == ^symbol, order_by: [desc: s.id], limit: 1)
      |> Repo.one()

    news_count =
      from(n in News,
        join: r in assoc(n, :run),
        where: r.started_at >= ^cutoff,
        select: count(n.id)
      )
      |> Repo.one()

    %{
      runs: runs,
      last_signal: (last_signal && last_signal.action) || "none",
      position: nil,
      equity: 0.0,
      news_count: news_count
    }
  end

  defp now, do: DateTime.truncate(DateTime.utc_now(), :second)

  defp truncate_ts(attrs) do
    Enum.reduce([:ts, :opened_at, :closed_at], attrs, fn key, acc ->
      case acc[key] do
        %DateTime{} = dt -> Map.put(acc, key, DateTime.truncate(dt, :second))
        _ -> acc
      end
    end)
  end
end
