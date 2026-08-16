defmodule BotTrader.RunnerTest do
  use ExUnit.Case, async: true

  alias BotTrader.Runner

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
      llm: fn _messages -> {:ok, openai_body(llm_content)} end,
      telegram: fn text ->
        send(self(), {:tg, text})
        :ok
      end
    }
  end

  setup do
    dir = Path.join(System.tmp_dir!(), "bot_trader_runner_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
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

  test "announces each executed trade and digest", %{dir: dir} do
    assert {:ok, _} = Runner.run(deps(dir, signal_json()))

    messages =
      receive_messages()

    assert Enum.any?(messages, &(&1 =~ "BUY BTC"))
    assert Enum.any?(messages, &(&1 =~ "Daily digest"))
  end

  test "hold signal executes no trade", %{dir: dir} do
    assert {:ok, summary} = Runner.run(deps(dir, signal_json(action: "HOLD", confidence: 0.1)))
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

    assert {:ok, _} = Runner.run(deps(dir, signal_json()))

    messages = receive_messages()
    assert Enum.any?(messages, &(&1 =~ "GATE"))
  end

  defp receive_messages(acc \\ []) do
    receive do
      {:tg, text} -> receive_messages([text | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
