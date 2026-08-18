defmodule BotTrader.NewsRunnerTest do
  use ExUnit.Case, async: false

  alias BotTrader.{NewsRunner, NewsRunnerRow, NewsStore, Repo}

  setup_all do
    TestRepoBoot.start!()
    :ok
  end

  setup do
    Repo.delete_all(BotTrader.NewsRunnerRow)
    :ok
  end

  @now ~U[2026-08-17 13:00:00Z]
  @positions [%{symbol: "VIVT3", asset_class: :stock_br, quantity: 0.1, entry: 29.85}]

  defp news_results do
    [
      %{
        symbol: "VIVT3",
        asset_class: :stock_br,
        timestamp: @now,
        price: "29.9",
        news: [%{headline: "VIVT3 earnings beat", source: "https://tv.com/news/a"}]
      }
    ]
  end

  defp start_runner(parent, extra_opts \\ []) do
    base = %{
      positions_fn: fn -> @positions end,
      news_fetcher: fn entries ->
        send(parent, {:fetched, Enum.map(entries, & &1.symbol)})
        {:ok, news_results()}
      end,
      sentiment_fn: fn headlines ->
        send(parent, {:sentiment, headlines})
        "neutral"
      end,
      telegram_fn: fn text -> send(parent, {:tg, text}) end,
      reanalysis_fn: fn symbol, _text ->
        send(parent, {:reanalyzed, symbol})

        %{
          "action" => "BUY",
          "confidence" => 0.7,
          "rationale" => "positive news",
          "target_weight" => 0.1
        }
      end,
      tick_ms: 60_000,
      poll_once: true
    }

    {:ok, pid} = NewsRunner.start_link(Map.merge(base, Map.new(extra_opts)))

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    pid
  end

  test "tick processes open positions" do
    parent = self()
    pid = start_runner(parent)

    send(pid, :tick)
    Process.sleep(300)

    rows = NewsStore.latest("VIVT3", 50)
    assert length(rows) == 1
    assert hd(rows).headline == "VIVT3 earnings beat"
    assert hd(rows).sentiment == "neutral"
    assert_received {:fetched, ["VIVT3"]}
    assert_received {:sentiment, _}
  end

  test "duplicate headline skipped" do
    parent = self()
    pid = start_runner(parent)

    send(pid, :tick)
    Process.sleep(300)
    send(pid, :tick)
    Process.sleep(300)

    rows = NewsStore.latest("VIVT3", 100)
    assert length(rows) == 1
  end

  test "negative headline alerts only" do
    parent = self()

    pid =
      start_runner(parent, %{
        sentiment_fn: fn _ -> "negative" end,
        news_fetcher: fn _entries ->
          {:ok,
           [
             %{
               symbol: "VIVT3",
               asset_class: :stock_br,
               timestamp: @now,
               price: "29.9",
               news: [%{headline: "SEC investigation", source: "https://tv.com/news/bad"}]
             }
           ]}
        end
      })

    send(pid, :tick)
    Process.sleep(300)

    assert_received {:tg, text}
    assert text =~ "negative"
  end

  test "neutral headline no alert" do
    parent = self()

    pid =
      start_runner(parent, %{
        sentiment_fn: fn _ -> "neutral" end,
        news_fetcher: fn _entries ->
          {:ok,
           [
             %{
               symbol: "VIVT3",
               asset_class: :stock_br,
               timestamp: @now,
               price: "29.9",
               news: [%{headline: "company holds event", source: "https://tv.com/news/ok"}]
             }
           ]}
        end
      })

    send(pid, :tick)
    Process.sleep(300)

    refute_received {:tg, _}
  end

  test "re-analysis signal source news" do
    parent = self()

    pid =
      start_runner(parent, %{
        sentiment_fn: fn _ -> "positive" end,
        news_fetcher: fn _entries ->
          {:ok,
           [
             %{
               symbol: "VIVT3",
               asset_class: :stock_br,
               timestamp: @now,
               price: "29.9",
               news: [%{headline: "strong 5G adoption", source: "https://tv.com/news/good"}]
             }
           ]}
        end
      })

    send(pid, :tick)
    Process.sleep(300)

    assert_received {:reanalyzed, "VIVT3"}
  end
end
