defmodule BotTrader.LLMTest do
  use ExUnit.Case, async: true

  alias BotTrader.LLM
  alias BotTrader.LLM.Signal

  setup do
    System.put_env("DEEPSEEK_API_KEY", "test-key")
    on_exit(fn -> System.delete_env("DEEPSEEK_API_KEY") end)
    :ok
  end

  test "parses valid signal" do
    json = ~s({"action":"BUY","confidence":0.8,"rationale":"uptrend","target_weight":0.2})

    assert {:ok, signal} = LLM.parse_signal(json)
    assert signal.action == :buy
    assert signal.confidence == 0.8
    assert signal.rationale == "uptrend"
    assert signal.target_weight == 0.2
  end

  test "rejects malformed json" do
    assert {:error, :invalid_signal} = LLM.parse_signal("{not valid json")
  end

  test "rejects unknown action" do
    json = ~s({"action":"MOON","confidence":0.9,"rationale":"x","target_weight":0.1})
    assert {:error, :invalid_signal} = LLM.parse_signal(json)
  end

  test "rejects out of range confidence" do
    json = ~s({"action":"BUY","confidence":1.5,"rationale":"x","target_weight":0.1})
    assert {:error, :invalid_signal} = LLM.parse_signal(json)
  end

  test "low confidence becomes hold" do
    signal = %Signal{action: :buy, confidence: 0.5, rationale: "x", target_weight: 0.1}
    assert Signal.effective_action(signal, 0.6) == :hold
  end

  test "high confidence keeps action" do
    signal = %Signal{action: :sell, confidence: 0.7, rationale: "x", target_weight: 0.0}
    assert Signal.effective_action(signal, 0.6) == :sell
  end

  test "close and hold are not confidence-gated" do
    hold = %Signal{action: :hold, confidence: 0.1, rationale: "x", target_weight: 0.0}
    close = %Signal{action: :close, confidence: 0.1, rationale: "x", target_weight: 0.0}
    assert Signal.effective_action(hold, 0.6) == :hold
    assert Signal.effective_action(close, 0.6) == :close
  end

  test "chat posts to endpoint with json mode and returns content" do
    req_opts = [plug: {Req.Test, LLM}]

    Req.Test.stub(LLM, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/chat/completions"
      assert conn.body_params["model"] == BotTrader.Config.deepseek_model()
      assert conn.body_params["response_format"] == %{"type" => "json_object"}
      assert conn.body_params["messages"] == [%{"role" => "user", "content" => "hi"}]

      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"content" => "{\"action\":\"HOLD\"}"}}]
      })
    end)

    assert {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}} =
             LLM.chat([%{role: "user", content: "hi"}], req_opts)

    assert content == "{\"action\":\"HOLD\"}"
  end

  test "chat returns error on non-200" do
    req_opts = [plug: {Req.Test, LLM}]

    Req.Test.stub(LLM, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    assert {:error, :http_error} = LLM.chat([%{role: "user", content: "hi"}], req_opts)
  end

  test "chat times out instead of hanging" do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    Task.start(fn ->
      {:ok, socket} = :gen_tcp.accept(listen)
      :gen_tcp.recv(socket, 0, 5000)
    end)

    base = "http://127.0.0.1:#{port}/v1"

    started = System.monotonic_time(:millisecond)

    assert {:error, :http_error} =
             LLM.chat([%{role: "user", content: "hi"}],
               base_url: base,
               receive_timeout: 300,
               retry_delays: []
             )

    elapsed = System.monotonic_time(:millisecond) - started
    assert elapsed < 2000
  end

  test "retries transient failure then succeeds" do
    req_opts = [plug: {Req.Test, LLM}]

    Req.Test.expect(LLM, 1, fn conn ->
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    Req.Test.expect(LLM, 1, fn conn ->
      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"content" => "{\"action\":\"HOLD\"}"}}]
      })
    end)

    assert {:ok, body} =
             LLM.chat([%{role: "user", content: "hi"}], req_opts ++ [retry_delays: [1]])

    assert body |> get_in(["choices"]) |> List.first() |> get_in(["message", "content"]) =~ "HOLD"
    Req.Test.verify_on_exit!(LLM)
  end

  test "returns error after all retries" do
    req_opts = [plug: {Req.Test, LLM}]

    Req.Test.expect(LLM, 3, fn conn ->
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    assert {:error, :http_error} =
             LLM.chat([%{role: "user", content: "hi"}], req_opts ++ [retry_delays: [1, 1]])

    Req.Test.verify_on_exit!(LLM)
  end
end
