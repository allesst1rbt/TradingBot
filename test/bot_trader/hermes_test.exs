defmodule BotTrader.HermesTest do
  use ExUnit.Case, async: true

  alias BotTrader.Hermes

  defp fake_bin(script) do
    dir = Path.join(System.tmp_dir!(), "hermes_fake_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    bin = Path.join(dir, "hermes")
    File.write!(bin, script)
    File.chmod!(bin, 0o755)
    on_exit(fn -> File.rm_rf(dir) end)
    bin
  end

  test "chat returns openai-shaped body with hermes output" do
    bin =
      fake_bin(
        "#!/bin/sh\necho '{\"action\":\"BUY\",\"confidence\":0.8,\"rationale\":\"r\",\"target_weight\":0.1,\"qualitative\":\"q\"}'\n"
      )

    messages = [%{role: "user", content: "analyze BTC"}]

    assert {:ok, body} = Hermes.chat(messages, hermes_bin: bin)
    assert %{"choices" => [%{"message" => %{"content" => content}}]} = body
    assert content =~ "BUY"
  end

  test "strips markdown fences from hermes output" do
    bin =
      fake_bin("#!/bin/sh\necho '```json\\n{\"action\":\"HOLD\"}\\n```'\n")

    assert {:ok, body} = Hermes.chat([%{role: "user", content: "hi"}], hermes_bin: bin)
    content = body |> get_in(["choices"]) |> List.first() |> get_in(["message", "content"])
    assert content =~ ~s("action":"HOLD")
    refute content =~ "```"
  end

  test "passes provider, model, and prompt to the binary" do
    bin =
      fake_bin("#!/bin/sh\necho \"$@\" > \"$FAKE_ARGS_FILE\"\necho '{}'\n")

    args_file = Path.join(System.tmp_dir!(), "hermes_args_#{System.unique_integer([:positive])}")

    {:ok, _body} =
      Hermes.chat([%{role: "user", content: "my prompt"}],
        hermes_bin: bin,
        env: [{"FAKE_ARGS_FILE", args_file}]
      )

    args = File.read!(args_file)
    assert args =~ "my prompt"
    assert args =~ "--provider opencode-go"
    assert args =~ "--model deepseek-v4-pro"
  end

  test "non-zero exit returns error tuple" do
    bin = fake_bin("#!/bin/sh\necho 'boom' >&2\nexit 1\n")

    assert {:error, :hermes_failed} =
             Hermes.chat([%{role: "user", content: "hi"}], hermes_bin: bin)
  end

  test "timeout returns error tuple" do
    bin = fake_bin("#!/bin/sh\nsleep 10\n")

    assert {:error, :timeout} =
             Hermes.chat([%{role: "user", content: "hi"}], hermes_bin: bin, timeout: 200)
  end
end
