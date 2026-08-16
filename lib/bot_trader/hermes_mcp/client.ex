defmodule BotTrader.HermesMCP.Client do
  @moduledoc """
  Minimal MCP stdio client over a Port. Newline-delimited JSON-RPC:
  initialize → tools/list → tools/call. Talks to the Hermes MCP child
  via stdin/stdout only — no sockets, nothing exposed.
  """

  use GenServer

  def start(bin, args, init_timeout \\ 30_000) do
    case GenServer.start(__MODULE__, {bin, args}) do
      {:ok, pid} ->
        case GenServer.call(pid, :initialize, init_timeout) do
          :ok ->
            {:ok, pid}

          {:error, reason} ->
            try do
              GenServer.stop(pid)
            catch
              :exit, _ -> :ok
            end

            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def call_analysis(pid, prompt) do
    GenServer.call(pid, {:tools_call, "analyze", %{"prompt" => prompt}}, 120_000)
  end

  def call_tool(pid, name, arguments) do
    GenServer.call(pid, {:tools_call, name, arguments}, 120_000)
  end

  @impl true
  def init({bin, args}) do
    port =
      Port.open({:spawn_executable, bin}, [
        :binary,
        {:args, args},
        {:line, 65_536},
        :exit_status
      ])

    {:ok, %{port: port, next_id: 1, pending: %{}}}
  end

  @impl true
  def handle_call(:initialize, from, state) do
    send_request(state.port, state.next_id, "initialize", %{})

    {:noreply,
     %{
       state
       | next_id: state.next_id + 1,
         pending: Map.put(state.pending, state.next_id, {:init, from})
     }}
  end

  def handle_call({:tools_call, name, arguments}, from, state) do
    send_request(state.port, state.next_id, "tools/call", %{
      "name" => name,
      "arguments" => arguments
    })

    {:noreply,
     %{
       state
       | next_id: state.next_id + 1,
         pending: Map.put(state.pending, state.next_id, {:call, from})
     }}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    state = dispatch_line(line, state)
    {:noreply, state}
  end

  def handle_info({port, {:data, {:noeol, line}}}, %{port: port} = state) do
    state = dispatch_line(line, state)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, _status}}, %{port: port} = state) do
    Enum.each(state.pending, fn {_id, {_kind, from}} ->
      GenServer.reply(from, {:error, :mcp_unreachable})
    end)

    {:stop, :normal, %{state | pending: %{}}}
  end

  def handle_info({_port, _}, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if is_port(state.port) do
      Port.close(state.port)
    end

    :ok
  end

  defp dispatch_line(line, state) do
    case Jason.decode(line) do
      {:ok, %{"id" => id, "result" => result}} ->
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{:init, from}, pending} ->
            GenServer.reply(from, :ok)
            %{state | pending: pending}

          {{:call, from}, pending} ->
            text =
              case result do
                %{"content" => [%{"type" => "text", "text" => text} | _]} -> text
                _ -> ""
              end

            GenServer.reply(from, {:ok, text})
            %{state | pending: pending}
        end

      {:ok, %{"id" => id, "error" => error}} ->
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{_kind, from}, pending} ->
            GenServer.reply(from, {:error, {:mcp_error, error}})
            %{state | pending: pending}
        end

      _ ->
        state
    end
  end

  defp send_request(port, id, method, params) do
    message =
      Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params})

    Port.command(port, message <> "\n")
  end
end
