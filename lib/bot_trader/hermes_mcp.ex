defmodule BotTrader.HermesMCP do
  @moduledoc """
  Analysis through the internal Hermes MCP child. Implements the same
  contract as `BotTrader.LLM.chat/1` (OpenAI-shaped body) so the pipeline
  can swap backends via `LLM_BACKEND`. No shell-out, no sockets.
  """

  alias BotTrader.{Config, HermesMCP.Client}

  def analyze(messages, opts \\ []) do
    bin = opts[:mcp_bin] || Config.hermes_mcp_bin()
    args = opts[:mcp_args] || Config.hermes_mcp_args()

    with {:ok, client} <- Client.start(bin, args) do
      result = Client.call_analysis(client, prompt(messages))
      stop_client(client)

      case result do
        {:ok, text} -> {:ok, %{"choices" => [%{"message" => %{"content" => strip_fences(text)}}]}}
        _ -> {:error, :mcp_unreachable}
      end
    else
      _ -> {:error, :mcp_unreachable}
    end
  end

  defp stop_client(pid) do
    try do
      GenServer.stop(pid)
    catch
      :exit, _ -> :ok
    end
  end

  defp prompt(messages) do
    Enum.map_join(messages, "\n\n", & &1.content)
  end

  defp strip_fences(output) do
    trimmed = String.trim(output)

    case Regex.run(~r/```(?:json)?\s*(.*?)```/s, trimmed) do
      [_, json] -> String.trim(json)
      nil -> trimmed
    end
  end
end
