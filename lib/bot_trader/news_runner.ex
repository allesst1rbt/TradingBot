defmodule BotTrader.NewsRunner do
  @moduledoc """
  Dedicated news runner GenServer. Ticks every 5 minutes (independent of the
  main runner and TradingView scraper). Loads open positions, fetches TradingView
  news for each, deduplicates, stores structured rows, classifies sentiment
  in one LLM batch per cycle, and alerts/re-analyzes on risk.
  """

  use GenServer

  alias BotTrader.{NewsStore}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      positions_fn: opts[:positions_fn] || fn -> default_positions() end,
      news_fetcher: opts[:news_fetcher] || (&fetch_news/1),
      sentiment_fn: opts[:sentiment_fn] || (&classify_sentiment/1),
      telegram_fn: opts[:telegram_fn] || (&BotTrader.Telegram.send_message/1),
      reanalysis_fn: opts[:reanalysis_fn] || (&reanalyze/2),
      tick_ms: opts[:tick_ms] || 300_000,
      poll_once: opts[:poll_once] || false
    }

    if opts[:poll_once] do
      :ok
    else
      Process.send_after(self(), :tick, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    unless state.poll_once do
      Process.send_after(self(), :tick, state.tick_ms)
    end

    run_tick(state)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp run_tick(state) do
    positions = state.positions_fn.()
    if positions == [], do: :ok, else: process_positions(positions, state)
  end

  defp process_positions(positions, state) do
    {:ok, snapshots} = state.news_fetcher.(positions)

    new_headlines =
      Enum.flat_map(snapshots, fn snapshot ->
        news = Map.get(snapshot, :news) || []

        Enum.flat_map(news, fn item ->
          headline = item[:headline] || item["headline"]
          source = item[:source] || item["source"]
          timestamp = Map.get(item, :timestamp) || Map.get(item, "timestamp")

          case NewsStore.insert(%{
                 symbol: snapshot.symbol,
                 headline: headline,
                 source: source,
                 timestamp: timestamp,
                 sentiment: "pending"
               }) do
            {:ok, row} ->
              Process.sleep(1)
              [%{row | sentiment: "pending"}]

            {:error, :duplicate} ->
              []
          end
        end)
      end)

    prune_news(positions)

    if new_headlines != [] do
      classify_and_alert(new_headlines, state)
    end
  end

  defp prune_news(positions) do
    Enum.each(positions, fn position ->
      NewsStore.prune(position.symbol, 50)
    end)
  end

  defp classify_and_alert(headlines, state) do
    headlines_text = Enum.map(headlines, & &1.headline)
    sentiment = state.sentiment_fn.(headlines_text)

    Enum.each(headlines, fn headline ->
      update_sentiment(headline, sentiment)
    end)

    if sentiment == "negative" do
      summary =
        Enum.map_join(headlines, "\n", fn h -> "  #{h.symbol}: #{h.headline} (#{sentiment})" end)

      state.telegram_fn.("⚠️ Risk news:\n#{summary}")
    end

    headlines
    |> Enum.map(& &1.symbol)
    |> Enum.uniq()
    |> Enum.each(fn symbol ->
      news_text =
        headlines
        |> Enum.filter(&(&1.symbol == symbol))
        |> Enum.map_join(" | ", & &1.headline)

      case state.reanalysis_fn.(symbol, news_text) do
        %{"action" => action} = result when action in ["SELL", "CLOSE"] ->
          send_risk_alert(symbol, action, result["rationale"], state)
          :ok

        _ ->
          :ok
      end
    end)
  end

  defp update_sentiment(headline, sentiment) do
    import Ecto.Query

    from(n in BotTrader.NewsRunnerRow, where: n.id == ^headline.id)
    |> BotTrader.Repo.update_all(set: [sentiment: sentiment])
  end

  defp send_risk_alert(symbol, action, rationale, state) do
    state.telegram_fn.(
      "⚠️ Position #{symbol}: signal changed to #{action}\n#{rationale || "from news re-analysis"}"
    )
  end

  defp default_positions do
    with {:ok, watchlist} <- load_watchlist(),
         positions <- BotTrader.Store.open_positions() do
      wm = Map.new(watchlist, fn e -> {e.symbol, e} end)

      Enum.flat_map(positions, fn p ->
        case Map.get(wm, p.symbol) do
          nil ->
            []

          entry ->
            [
              %{
                symbol: p.symbol,
                asset_class: entry.asset_class,
                quantity: p.quantity,
                entry: p.entry
              }
            ]
        end
      end)
    else
      _ -> []
    end
  end

  defp load_watchlist do
    case File.read(BotTrader.Config.watchlist_path()) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, json} ->
            {:ok,
             Enum.map(json["symbols"] || [], fn e ->
               %{symbol: e["symbol"], asset_class: String.to_atom(e["asset_class"])}
             end)}

          _ ->
            {:error, :parse_error}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp fetch_news(entries) do
    BotTrader.TradingView.Browser.scrape_batch(entries, max_concurrency: 2)
    |> then(fn results -> {:ok, results} end)
  end

  defp classify_sentiment(headlines) do
    prompt =
      "Classify each headline as positive, negative, or neutral.\n" <>
        Enum.map_join(headlines, "\n", fn h -> "- #{h}" end) <>
        "\nReturn JSON: [{\"headline\": \"...\", \"sentiment\": \"...\"}]"

    case BotTrader.LLM.chat([%{role: "user", content: prompt}],
           model: BotTrader.Config.llm_model_flash()
         ) do
      {:ok, body} ->
        text = get_in(body, ["choices"]) |> List.first() |> get_in(["message", "content"])

        case Jason.decode(text) do
          {:ok, items} when is_list(items) ->
            items
            |> Enum.map(fn item -> item["sentiment"] end)
            |> Enum.find("neutral", &(&1 in ["positive", "negative"]))

          _ ->
            "neutral"
        end

      _ ->
        "neutral"
    end
  end

  defp reanalyze(symbol, news_text) do
    with {:ok, snapshot} <- BotTrader.TradingViewStore.latest_snapshot(symbol) do
      prompt =
        "Position #{symbol} has new news: #{news_text}\n" <>
          BotTrader.TradingView.Reasoning.build_prompt(snapshot, nil)

      case BotTrader.LLM.chat(
             [%{role: "user", content: prompt}],
             model: BotTrader.Config.llm_model_flash()
           ) do
        {:ok, body} ->
          body
          |> get_in(["choices"])
          |> List.first()
          |> get_in(["message", "content"])
          |> Jason.decode()
          |> elem(1)

        _ ->
          %{}
      end
    else
      _ -> %{}
    end
  end
end
