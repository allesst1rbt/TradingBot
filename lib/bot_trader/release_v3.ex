defmodule BotTrader.Release.V3 do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add(:note, :string)
    end
  end
end
