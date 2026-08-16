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
    model = opts[:model] || Config.hermes_model()

    with {:ok, client} <- Client.start(bin, args),
         {:ok, text} <-
           Client.call_tool(client, "analyze", %{
             "prompt" => prompt(messages),
             "model" => model
           }) do
      stop_client(client)
      {:ok, %{"choices" => [%{"message" => %{"content" => strip_fences(text)}}]}}
    else
      _ -> {:error, :mcp_unreachable}
    end
  end

  def news(symbols, opts \\ []) do
    bin = opts[:mcp_bin] || Config.hermes_mcp_bin()
    args = opts[:mcp_args] || Config.hermes_mcp_args()

    with {:ok, client} <- Client.start(bin, args),
         {:ok, text} <- Client.call_tool(client, "news_search", %{"symbols" => symbols}) do
      stop_client(client)
      {:ok, text}
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
