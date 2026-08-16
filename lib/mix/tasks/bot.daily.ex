defmodule Mix.Tasks.Bot.Daily do
  @moduledoc """
  Runs the daily trading pipeline once and exits.

      mix bot.daily
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case BotTrader.Runner.run() do
      {:ok, summary} ->
        Mix.shell().info("bot.daily complete: #{inspect(summary)}")

      {:error, reason} ->
        _ = send_failure_alert(reason)
        Mix.raise("bot.daily failed: #{inspect(reason)}")
    end
  end

  defp send_failure_alert(reason) do
    if System.get_env("TELEGRAM_BOT_TOKEN") do
      BotTrader.Telegram.send_failure_alert(reason)
    else
      :no_token
    end
  end
end
