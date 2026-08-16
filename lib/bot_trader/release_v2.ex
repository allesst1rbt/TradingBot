defmodule BotTrader.Release.V2 do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:watchlist) do
      add(:symbol, :string)
      add(:asset_class, :string)
      add(:coin_id, :string)
      add(:added_at, :utc_datetime)
      add(:source, :string)
    end

    create(unique_index(:watchlist, [:symbol]))
  end
end
