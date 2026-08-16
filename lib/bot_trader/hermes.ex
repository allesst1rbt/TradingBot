defmodule BotTrader.Hermes do
  @moduledoc """
  Adapter for the Hermes Agent CLI in scripted one-shot mode
  (`hermes -z`), configured with the OpenCode Go provider. Implements
  the same contract as `BotTrader.LLM.chat/1` so the pipeline can swap
  backends via `LLM_BACKEND`.
  """

  alias BotTrader.Config

  def chat(messages, opts \\ []) do
    prompt = Enum.map_join(messages, "\n\n", & &1.content)
    bin = opts[:hermes_bin] || Config.hermes_bin()
    model = opts[:model] || Config.hermes_model()
    timeout = opts[:timeout] || Config.hermes_timeout_ms()
    env = opts[:env] || []

    args = ["-z", prompt, "--provider", "opencode-go", "--model", model]

    task =
      Task.async(fn ->
        System.cmd(bin, args, env: env, stderr_to_stdout: false)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} ->
        content = strip_fences(output)
        {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}}

      {:ok, _} ->
        {:error, :hermes_failed}

      nil ->
        {:error, :timeout}
    end
  end

  defp strip_fences(output) do
    trimmed = String.trim(output)

    case Regex.run(~r/```(?:json)?\s*(.*?)```/s, trimmed) do
      [_, json] -> String.trim(json)
      nil -> trimmed
    end
  end
end
