defmodule TestRepoBoot do
  def start! do
    case Process.whereis(BotTrader.Repo) do
      nil -> raise "Test Repo was not started by test_helper"
      _ -> :ok
    end

    :ok
  end
end
