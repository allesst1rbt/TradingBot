defmodule BotTrader.HermesMCPTest do
  use ExUnit.Case, async: true

  alias BotTrader.HermesMCP

  defp fake_server_script(signal_json) do
    dir = Path.join(System.tmp_dir!(), "fake_mcp_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    script = Path.join(dir, "fake_mcp.exs")
    escaped = String.replace(signal_json, "\"", "\\\"")

    script_content = """
    defmodule FakeMCP do
      def main(signal_json) do
        loop(signal_json)
      end

      defp loop(signal_json) do
        case IO.binread(:stdio, :line) do
          :eof -> :ok
          {:error, _} -> :ok
          line ->
            id = extract_id(line)

            cond do
              String.contains?(line, "initialize") ->
                :file.write(:standard_io, "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":\#{id},\\"result\\":{\\"protocolVersion\\":\\"2025-06-18\\",\\"capabilities\\":{},\\"serverInfo\\":{\\"name\\":\\"fake\\",\\"version\\":\\"0.0.1\\"}}}\\n")

              String.contains?(line, "tools/list") ->
                :file.write(:standard_io, "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":\#{id},\\"result\\":{\\"tools\\":[{\\"name\\":\\"analyze\\",\\"description\\":\\"analyze\\",\\"inputSchema\\":{\\"type\\":\\"object\\",\\"properties\\":{\\"prompt\\":{\\"type\\":\\"string\\"}}}}]}}\\n")

              String.contains?(line, "tools/call") ->
                sig = String.replace(signal_json, "\\"", "\\\\\\"")
                :file.write(:standard_io, "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":\#{id},\\"result\\":{\\"content\\":[{\\"type\\":\\"text\\",\\"text\\":\\"\#{sig}\\"}]}}\\n")

              true ->
                :ok
            end

            loop(signal_json)
        end
      end

      defp extract_id(line) do
        case Regex.run(~r/"id":\\s*(\\d+)/, line) do
          [_, id] -> id
          nil -> "0"
        end
      end
    end

    FakeMCP.main(#{inspect(signal_json)})
    """

    File.write!(script, script_content)

    on_exit(fn -> File.rm_rf(dir) end)
    script
  end

  @signal_json ~s({"action":"BUY","confidence":0.8,"rationale":"r","target_weight":0.1,"qualitative":"q"})

  test "client completes mcp handshake and calls analysis tool" do
    script = fake_server_script(@signal_json)
    elixir = System.find_executable("elixir")

    {:ok, client} = HermesMCP.Client.start(elixir, [script])
    on_exit(fn -> GenServer.stop(client) end)

    assert {:ok, text} = HermesMCP.Client.call_analysis(client, "analyze BTC")
    assert text =~ "BUY"
  end

  test "parses signal from tool result with shared llm contract" do
    script = fake_server_script(@signal_json)
    elixir = System.find_executable("elixir")

    assert {:ok, openai_body} =
             HermesMCP.analyze([%{role: "user", content: "analyze BTC"}],
               mcp_bin: elixir,
               mcp_args: [script]
             )

    content = openai_body |> get_in(["choices"]) |> List.first() |> get_in(["message", "content"])
    assert {:ok, signal} = BotTrader.LLM.parse_signal(content)
    assert signal.action == :buy
    assert signal.confidence == 0.8
  end

  test "mcp failure returns error tuple" do
    assert {:error, :mcp_unreachable} =
             HermesMCP.analyze([%{role: "user", content: "hi"}],
               mcp_bin: "/nonexistent/binary"
             )
  end

  test "mcp handshake timeout returns error tuple without raising" do
    script =
      fake_server_script(
        ~s({"action":"BUY","confidence":0.8,"rationale":"r","target_weight":0.1,"qualitative":"q"})
      )

    # child never answers but exits when its stdin closes
    hang_script = script <> ".hang"

    File.write!(hang_script, """
    case IO.binread(:stdio, :line) do
      :eof -> :ok
      _ -> :ok
    end
    """)

    assert {:error, :mcp_unreachable} =
             HermesMCP.analyze([%{role: "user", content: "hi"}],
               mcp_bin: System.find_executable("elixir"),
               mcp_args: [hang_script],
               init_timeout: 200
             )
  end

  test "no shell-out adapter remains" do
    refute Code.ensure_loaded?(BotTrader.Hermes)
  end
end
