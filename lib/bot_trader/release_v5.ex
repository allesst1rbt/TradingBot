defmodule BotTrader.Release.V5 do
  use Ecto.Migration

  def change do
    create table(:tradingview_snapshots) do
      add(:symbol, :string, null: false)
      add(:asset_class, :string, null: false)
      add(:timestamp, :utc_datetime, null: false)
      add(:timeframe, :string, null: false)
      add(:price, :float)
      add(:change_pct, :float)
      add(:open, :float)
      add(:high, :float)
      add(:low, :float)
      add(:close, :float)
      add(:volume, :float)
      add(:technical_rating, :string)
      add(:rsi, :float)
      add(:macd, :float)
      add(:ema20, :float)
      add(:sma50, :float)
      add(:provider, :string, null: false)
      add(:stale, :boolean, default: false, null: false)
    end

    create(index(:tradingview_snapshots, [:symbol, :timestamp]))

    create table(:tradingview_cursors, primary_key: false) do
      add(:key, :string, primary_key: true)
      add(:position, :integer, null: false, default: 0)
      add(:updated_at, :utc_datetime, null: false)
    end
  end
end
