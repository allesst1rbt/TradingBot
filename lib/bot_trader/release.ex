defmodule BotTrader.Release do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:runs) do
      add(:kind, :string)
      add(:started_at, :utc_datetime)
      add(:finished_at, :utc_datetime)
      add(:status, :string)
      add(:calls, :integer, default: 0)
    end

    create table(:signals) do
      add(:run_id, references(:runs, on_delete: :delete_all))
      add(:symbol, :string)
      add(:action, :string)
      add(:confidence, :float)
      add(:model, :string)
      add(:price, :float)
      add(:rationale, :text)
    end

    create table(:trades) do
      add(:run_id, references(:runs, on_delete: :nilify_all))
      add(:symbol, :string)
      add(:side, :string)
      add(:quantity, :float)
      add(:price, :float)
      add(:fee, :float)
      add(:realized_pnl, :float)
      add(:reason, :string)
      add(:opened_at, :utc_datetime)
      add(:closed_at, :utc_datetime)
      add(:ts, :utc_datetime)
    end

    create table(:snapshots) do
      add(:run_id, references(:runs, on_delete: :delete_all))
      add(:ts, :utc_datetime)
      add(:equity, :float)
      add(:cash, :float)
      add(:realized_pnl, :float)
    end

    create table(:news) do
      add(:run_id, references(:runs, on_delete: :delete_all))
      add(:symbol, :string)
      add(:trigger, :float)
      add(:text, :text)
    end

    create table(:poller_state, primary_key: false) do
      add(:key, :string, primary_key: true)
      add(:value, :string)
    end
  end
end
