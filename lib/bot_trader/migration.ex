defmodule BotTrader.Migration do
  @moduledoc """
  One-time import of legacy JSON state (portfolio/trades/snapshots) into
  SQLite. Archives the JSON files after a successful import. Idempotent:
  no JSON files → no-op.
  """

  alias BotTrader.Repo

  def run(dir) do
    files = %{
      portfolio: Path.join(dir, "portfolio.json"),
      trades: Path.join(dir, "trades.json"),
      snapshots: Path.join(dir, "snapshots.json")
    }

    present = Map.filter(files, fn {_name, path} -> File.exists?(path) end)

    if present == %{} do
      :ok
    else
      with {:ok, data} <- read_all(present) do
        Repo.transaction(fn ->
          import_snapshots(data[:snapshots])
          import_trades(data[:trades])
          import_portfolio(data[:portfolio])
        end)

        Enum.each(present, fn {_name, path} -> File.rename(path, path <> ".archived") end)
        :ok
      end
    end
  end

  defp read_all(files) do
    Enum.reduce_while(files, {:ok, %{}}, fn {name, path}, {:ok, acc} ->
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, json} -> {:cont, {:ok, Map.put(acc, name, json)}}
            {:error, _} -> {:halt, {:error, :corrupt_state}}
          end

        {:error, _} ->
          {:halt, {:error, :corrupt_state}}
      end
    end)
  end

  defp import_snapshots(nil), do: :ok

  defp import_snapshots(snapshots) do
    Enum.each(snapshots, fn snap ->
      ts = parse_date(snap["date"])

      %BotTrader.Snapshot{}
      |> Ecto.Changeset.change(%{
        ts: ts,
        equity: snap["equity"] || 0.0,
        cash: snap["cash"] || 0.0,
        realized_pnl: snap["realized_pnl"] || 0.0
      })
      |> Repo.insert!()
    end)
  end

  defp import_trades(nil), do: :ok

  defp import_trades(trades) do
    Enum.each(trades, fn trade ->
      ts = parse_ts(trade["ts"])
      side = trade["side"]

      %BotTrader.Trade{}
      |> Ecto.Changeset.change(%{
        symbol: trade["symbol"],
        side: side,
        quantity: trade["quantity"],
        price: trade["price"],
        fee: trade["fee"] || 0.0,
        realized_pnl: trade["realized_pnl"],
        reason: to_string(trade["reason"] || ""),
        opened_at: if(side == "BUY", do: ts, else: nil),
        closed_at: if(side in ["SELL", "CLOSE"], do: ts, else: nil),
        ts: ts
      })
      |> Repo.insert!()
    end)
  end

  defp import_portfolio(nil), do: :ok

  defp import_portfolio(portfolio) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    %BotTrader.Snapshot{}
    |> Ecto.Changeset.change(%{
      ts: now,
      equity: equity(portfolio),
      cash: portfolio["cash"] || 0.0,
      realized_pnl: portfolio["realized_pnl"] || 0.0
    })
    |> Repo.insert!()

    Enum.each(portfolio["positions"] || [], fn pos ->
      %BotTrader.Trade{}
      |> Ecto.Changeset.change(%{
        symbol: pos["symbol"],
        side: "BUY",
        quantity: pos["quantity"],
        price: pos["entry_price"],
        fee: 0.0,
        opened_at: now,
        ts: now
      })
      |> Repo.insert!()
    end)
  end

  defp equity(portfolio) do
    positions_value =
      Enum.reduce(portfolio["positions"] || [], 0.0, fn pos, acc ->
        acc + pos["quantity"] * pos["entry_price"]
      end)

    (portfolio["cash"] || 0.0) + positions_value
  end

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
      {:error, _} -> now()
    end
  end

  defp parse_date(_), do: now()

  defp parse_ts(ts_string) when is_binary(ts_string) do
    case DateTime.from_iso8601(ts_string) do
      {:ok, ts, _} -> DateTime.truncate(ts, :second)
      {:error, _} -> now()
    end
  end

  defp parse_ts(_), do: now()

  defp now, do: DateTime.truncate(DateTime.utc_now(), :second)
end
