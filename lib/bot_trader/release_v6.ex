defmodule BotTrader.Release.V6 do
  use Ecto.Migration

  def change do
    create table(:news_runner) do
      add(:symbol, :string, null: false)
      add(:headline, :string, null: false)
      add(:source, :string)
      add(:timestamp, :utc_datetime)
      add(:sentiment, :string)
      add(:hash, :string)
      add(:inserted_at, :utc_datetime, null: false)
    end

    create(index(:news_runner, [:symbol, :timestamp]))
    create(unique_index(:news_runner, [:hash]))
  end
end
