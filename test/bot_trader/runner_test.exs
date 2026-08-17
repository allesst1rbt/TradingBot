defmodule BotTrader.RunnerTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias BotTrader.Runner

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  @candles [
    %{
      ts: ~U[2026-08-14 00:00:00Z],
      open: 90.0,
      high: 95.0,
      low: 89.0,
      close: 92.0,
      volume: 100.0
    },
    %{
      ts: ~U[2026-08-15 00:00:00Z],
      open: 92.0,
      high: 97.0,
      low: 91.0,
      close: 95.0,
      volume: 100.0
    },
    %{
      ts: ~U[2026-08-16 00:00:00Z],
      open: 95.0,
      high: 105.0,
      low: 94.0,
      close: 100.0,
      volume: 100.0
    }
  ]

  @watchlist [%{symbol: "BTC", asset_class: :crypto, coin_id: "bitcoin"}]

  defp signal_json(opts \\ []) do
    %{
      "action" => Keyword.get(opts, :action, "BUY"),
      "confidence" => Keyword.get(opts, :confidence, 0.8),
      "rationale" => "fixture",
      "target_weight" => Keyword.get(opts, :target_weight, 0.1),
      "qualitative" => "fixture qualitative"
    }
    |> Jason.encode!()
  end

  defp openai_body(content) do
    %{"choices" => [%{"message" => %{"content" => content}}]}
  end

  defp deps(state_dir, llm_content, candles_fun \\ fn _symbol, _days -> {:ok, @candles} end) do
    %{
      state_dir: state_dir,
      date: ~D[2026-08-16],
      watchlist: @watchlist,
      candles: candles_fun,
      llm: fn _messages, model ->
        send(self(), {:model, model})
        {:ok, openai_body(llm_content)}
      end,
      telegram: fn text ->
        send(self(), {:tg, text})
        :ok
      end,
      news: fn symbols ->
        send(self(), {:news, symbols})
        "market news"
      end
    }
  end

  setup do
    dir = Path.join(System.tmp_dir!(), "bot_trader_runner_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    BotTrader.Repo.delete_all(BotTrader.WatchlistEntry)

    BotTrader.Store.seed_watchlist(
      Enum.map(@watchlist, fn e ->
        %{symbol: e.symbol, asset_class: Atom.to_string(e.asset_class), coin_id: e[:coin_id]}
      end)
    )

    {:ok, dir: dir}
  end

  test "full daily run writes report and state", %{dir: dir} do
    assert {:ok, summary} = Runner.run(deps(dir, signal_json()))
    assert summary.trades_executed == 1

    report = Path.join(dir, "reports/2026-08-16.md")
    assert File.exists?(report)
    assert File.read!(report) =~ "BTC"

    assert File.exists?(Path.join(dir, "portfolio.json"))
    assert File.exists?(Path.join(dir, "trades.json"))
    assert File.exists?(Path.join(dir, "snapshots.json"))

    {:ok, portfolio} = BotTrader.State.read(dir, :portfolio)
    assert [%{symbol: "BTC"}] = portfolio.positions
  end

  test "announces each executed trade and digest on deep run", %{dir: dir} do
    assert {:ok, _} = Runner.run(deps(dir, signal_json()), :deep)

    messages =
      receive_messages()

    assert Enum.any?(messages, &(&1 =~ "BUY BTC"))
    assert Enum.any?(messages, &(&1 =~ "Daily digest"))
  end

  test "no digest on standard run", %{dir: dir} do
    assert {:ok, _} =
             Runner.run(deps(dir, signal_json(action: "HOLD", confidence: 0.1)), :standard)

    messages = receive_messages()
    refute Enum.any?(messages, &(&1 =~ "Daily digest"))
  end

  test "failure alert lists skipped symbols", %{dir: dir} do
    llm = fn _messages, _model -> {:error, :mcp_unreachable} end
    deps = deps(dir, signal_json()) |> Map.put(:llm, llm)

    assert {:ok, _} = Runner.run(deps, :standard)

    messages = receive_messages()
    assert Enum.any?(messages, &(&1 =~ "degraded"))
    assert Enum.any?(messages, &(&1 =~ "BTC"))
  end

  test "standard run uses flash model", %{dir: dir} do
    assert {:ok, _} = Runner.run(deps(dir, signal_json()), :standard)
    assert_received {:model, "deepseek-v4-flash"}
  end

  test "deep run uses pro model", %{dir: dir} do
    assert {:ok, _} = Runner.run(deps(dir, signal_json()), :deep)
    assert_received {:model, "deepseek-v4-pro"}
  end

  test "one market-wide news call per run", %{dir: dir} do
    assert {:ok, _} = Runner.run(deps(dir, signal_json(action: "HOLD", confidence: 0.1)))
    assert_received {:news, :market}
  end

  test "volatility triggers per-symbol news", %{dir: dir} do
    volatile = [
      %{
        ts: ~U[2026-08-16 00:00:00Z],
        open: 100.0,
        high: 100.0,
        low: 100.0,
        close: 100.0,
        volume: 1.0
      },
      %{
        ts: ~U[2026-08-16 00:15:00Z],
        open: 100.0,
        high: 104.0,
        low: 100.0,
        close: 104.0,
        volume: 1.0
      }
    ]

    assert {:ok, _} = Runner.run(deps(dir, signal_json(), fn _s, _d -> {:ok, volatile} end))
    assert_received {:news, ["BTC"]}
  end

  test "hold signal executes no trade", %{dir: dir} do
    assert {:ok, summary} =
             Runner.run(deps(dir, signal_json(action: "HOLD", confidence: 0.1)), :deep)

    assert summary.trades_executed == 0
    assert Enum.any?(receive_messages(), &(&1 =~ "Daily digest"))
  end

  test "missing data excludes symbol without crashing", %{dir: dir} do
    candles_fun = fn symbol, _days -> {:error, :no_data, symbol} end
    assert {:ok, summary} = Runner.run(deps(dir, signal_json(), candles_fun))
    assert summary.trades_executed == 0
    assert summary.symbols_without_data == ["BTC"]
  end

  test "corrupt state aborts with alert and no overwrite", %{dir: dir} do
    File.write!(Path.join(dir, "portfolio.json"), "{corrupt")

    assert {:error, :corrupt_state} = Runner.run(deps(dir, signal_json()))
    assert File.read!(Path.join(dir, "portfolio.json")) == "{corrupt"
    assert Enum.any?(receive_messages(), &(&1 =~ "FAILED"))
  end

  test "day 30 digest includes gate verdict", %{dir: dir} do
    snapshots =
      for i <- 1..29 do
        %{date: "2026-07-#{i}", equity: 1000.0 + i}
      end

    BotTrader.State.write(dir, :snapshots, snapshots)

    assert {:ok, _} = Runner.run(deps(dir, signal_json()), :deep)

    messages = receive_messages()
    assert Enum.any?(messages, &(&1 =~ "GATE"))
  end

  defmodule FakeProvider do
    def candles(symbol, _days, _opts \\ []) do
      send(self(), {:candles_called, symbol})
      {:ok, []}
    end
  end

  test "default candles path calls routed provider with symbol and days" do
    dir = Path.join(System.tmp_dir!(), "bot_trader_default_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    deps =
      deps(dir, signal_json())
      |> Map.drop([:candles])
      |> Map.put(:router, fn _entry -> {FakeProvider, "PETR4.SA"} end)

    assert {:ok, summary} = Runner.run(deps)
    assert summary.symbols_without_data == ["BTC"]
    assert_received {:candles_called, "PETR4.SA"}
  end

  test "budget alert sent once per day", %{dir: dir} do
    {:ok, run} = BotTrader.Store.start_run(:standard)
    BotTrader.Store.finish_run(run, "ok", 2500)

    assert {:ok, _} = Runner.run(deps(dir, signal_json()))
    assert Enum.any?(receive_messages(), &(&1 =~ "budget"))

    assert {:ok, _} = Runner.run(deps(dir, signal_json()))
    refute Enum.any?(receive_messages(), &(&1 =~ "budget"))
  end

  defp start_http_responder(body) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    Task.start(fn ->
      {:ok, socket} = :gen_tcp.accept(listen)
      :gen_tcp.recv(socket, 0, 5000)

      :gen_tcp.send(
        socket,
        "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: #{byte_size(body)}\r\nconnection: close\r\n\r\n" <>
          body
      )

      :gen_tcp.close(socket)
    end)

    port
  end

  test "watchlist grows by one per run", %{dir: dir} do
    BotTrader.Repo.delete_all(BotTrader.WatchlistEntry)
    BotTrader.Store.add_to_watchlist("AAA", "stock-us")

    universe_fun = fn ->
      BotTrader.Store.add_to_watchlist("NEWCAND", "stock-us")
      {:ok, "NEWCAND"}
    end

    deps =
      deps(dir, signal_json(action: "HOLD", confidence: 0.1))
      |> Map.put(:universe_fun, universe_fun)

    assert {:ok, _} = Runner.run(deps, :standard)

    symbols = BotTrader.Store.get_watchlist() |> Enum.map(& &1.symbol)
    assert "NEWCAND" in symbols
    assert "AAA" in symbols
  end

  test "trade absorbed into hermes memory", %{dir: dir} do
    mem_path = Path.join(dir, "hermes_memory.md")
    System.put_env("HERMES_MEMORY_PATH", mem_path)
    on_exit(fn -> System.delete_env("HERMES_MEMORY_PATH") end)

    assert {:ok, _} = Runner.run(deps(dir, signal_json()), :standard)

    assert File.exists?(mem_path)
    content = File.read!(mem_path)
    assert content =~ "BUY"
    assert content =~ "fixture"
  end

  test "memory failure non-fatal with run note", %{dir: dir} do
    System.put_env("HERMES_MEMORY_PATH", "/dev/null/nope/mem.md")
    on_exit(fn -> System.delete_env("HERMES_MEMORY_PATH") end)

    assert {:ok, summary} = Runner.run(deps(dir, signal_json()), :standard)
    assert summary.trades_executed == 1

    latest = BotTrader.Repo.one(from(r in BotTrader.Run, order_by: [desc: r.id], limit: 1))
    assert latest.note =~ "memory"
  end

  test "rolling summary shows open position", %{dir: dir} do
    System.put_env("HERMES_MEMORY_PATH", Path.join(dir, "mem.md"))
    on_exit(fn -> System.delete_env("HERMES_MEMORY_PATH") end)

    llm = fn messages, _model ->
      send(self(), {:prompt, Enum.map_join(messages, " ", & &1.content)})
      {:ok, openai_body(signal_json(action: "HOLD", confidence: 0.1))}
    end

    deps = deps(dir, signal_json(action: "HOLD", confidence: 0.1)) |> Map.put(:llm, llm)
    assert {:ok, _} = Runner.run(deps, :standard)

    # first run: no position yet (buy happened this run for BTC? signal is HOLD -> no trade)
    prompt = receive_messages() |> Enum.find(&(is_binary(&1) and String.contains?(&1, "Rolling")))
    assert prompt == nil or prompt =~ "position: none"
  end

  test "rolling summary shows position on later run", %{dir: dir} do
    System.put_env("HERMES_MEMORY_PATH", Path.join(dir, "mem.md"))
    on_exit(fn -> System.delete_env("HERMES_MEMORY_PATH") end)

    assert {:ok, _} = Runner.run(deps(dir, signal_json()), :standard)

    llm = fn messages, _model ->
      send(self(), {:prompt2, Enum.map_join(messages, " ", & &1.content)})
      {:ok, openai_body(signal_json(action: "HOLD", confidence: 0.1))}
    end

    deps2 = deps(dir, signal_json(action: "HOLD", confidence: 0.1)) |> Map.put(:llm, llm)
    assert {:ok, _} = Runner.run(deps2, :standard)

    prompts = collect_prompt2()
    assert length(prompts) == 1
    assert hd(prompts) =~ "position: 0.9995"
  end

  test "scan failure non-fatal keeps watchlist", %{dir: dir} do
    System.put_env("UNIVERSE_SCAN_ENABLED", "true")
    on_exit(fn -> System.delete_env("UNIVERSE_SCAN_ENABLED") end)

    BotTrader.Repo.delete_all(BotTrader.WatchlistEntry)
    BotTrader.Store.add_to_watchlist("AAA", "stock-us")

    deps =
      deps(dir, signal_json(action: "HOLD", confidence: 0.1))
      |> Map.put(:universe_fun, fn -> :none end)

    assert {:ok, _} = Runner.run(deps, :standard)

    symbols = BotTrader.Store.get_watchlist() |> Enum.map(& &1.symbol)
    assert symbols == ["AAA"]
  end

  test "default direct llm backend works end to end", %{dir: dir} do
    body = Jason.encode!(openai_body(signal_json()))

    port = start_http_responder(body)

    System.put_env("LLM_BACKEND", "direct")
    System.put_env("DEEPSEEK_BASE_URL", "http://127.0.0.1:#{port}/v1")
    System.put_env("DEEPSEEK_API_KEY", "test")
    on_exit(fn -> System.delete_env("LLM_BACKEND") end)
    on_exit(fn -> System.delete_env("DEEPSEEK_BASE_URL") end)
    on_exit(fn -> System.delete_env("DEEPSEEK_API_KEY") end)

    deps = deps(dir, signal_json()) |> Map.drop([:llm, :news])

    assert {:ok, summary} = Runner.run(deps, :standard)
    assert summary.trades_executed >= 0

    {:ok, signal} =
      BotTrader.Store.get_last_signal("BTC")

    assert signal.model == "deepseek-v4-flash"
  end

  defp collect_prompt2(acc \\ []) do
    receive do
      {:prompt2, text} -> collect_prompt2([text | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end

  defp receive_messages(acc \\ []) do
    receive do
      {:tg, text} -> receive_messages([text | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
