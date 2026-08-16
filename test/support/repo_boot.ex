defmodule TestRepoBoot do
  def start! do
    unless :persistent_term.get({__MODULE__, :migrated_v2}, false) do
      Ecto.Migrator.up(BotTrader.Repo, 1, BotTrader.Release.V2, log: false)
      :persistent_term.put({__MODULE__, :migrated_v2}, true)
    end

    case Process.whereis(BotTrader.Repo) do
      nil -> raise "Test Repo was not started by test_helper"
      _ -> :ok
    end

    :ok
  end
end
