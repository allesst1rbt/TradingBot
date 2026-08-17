defmodule BotTrader.Release.V4 do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:signals) do
      add(:source, :string, default: "watchlist")
    end
  end
end
