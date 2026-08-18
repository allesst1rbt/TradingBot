defmodule BotTrader.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    state_dir = BotTrader.Config.state_dir()
    File.mkdir_p!(state_dir)

    unless Application.get_env(:bot_trader, BotTrader.Repo) do
      Application.put_env(:bot_trader, BotTrader.Repo,
        database: Path.join(state_dir, "bot_trader.sqlite3"),
        pool_size: 2,
        journal_mode: :wal,
        busy_timeout: 5000
      )
    end

    if Mix.env() != :test do
      {:ok, _repo} = BotTrader.Repo.start_link()
      Ecto.Migrator.up(BotTrader.Repo, 0, BotTrader.Release, log: false)
      Ecto.Migrator.up(BotTrader.Repo, 1, BotTrader.Release.V2, log: false)
      Ecto.Migrator.up(BotTrader.Repo, 2, BotTrader.Release.V3, log: false)
      Ecto.Migrator.up(BotTrader.Repo, 3, BotTrader.Release.V4, log: false)
      Ecto.Migrator.up(BotTrader.Repo, 4, BotTrader.Release.V5, log: false)
      Ecto.Migrator.up(BotTrader.Repo, 5, BotTrader.Release.V6, log: false)
      BotTrader.Migration.run(state_dir)
    end

    children = [
      {BotTrader.Scheduler, name: BotTrader.Scheduler},
      {BotTrader.Telegram.Poller, name: BotTrader.Telegram.Poller}
    ]

    children =
      if Mix.env() != :test and BotTrader.Config.tradingview_enabled() do
        entries =
          case BotTrader.Universe.load_universe() do
            {:ok, entries} -> entries
            _ -> []
          end

        {:ok, cursor} = BotTrader.TradingViewStore.get_cursor("stocks")

        scraper = %{
          entries: entries,
          batch_size: BotTrader.Config.tradingview_batch_size(),
          cursor: cursor,
          scrape_fun: fn batch ->
            BotTrader.TradingView.Browser.scrape_batch(batch,
              max_concurrency: BotTrader.Config.tradingview_max_concurrency()
            )
          end,
          persist_fun: fn results ->
            Enum.each(results, fn result ->
              news = Map.get(result, :news) || []

              snapshot_attrs =
                Map.drop(result, [:news, :error])
                |> Map.put_new_lazy(:timestamp, fn ->
                  DateTime.truncate(DateTime.utc_now(), :second)
                end)

              if snapshot_attrs[:timestamp] do
                BotTrader.TradingViewStore.insert_snapshot(snapshot_attrs)
              end

              Enum.each(news, fn item ->
                BotTrader.NewsStore.insert(%{
                  symbol: result[:symbol],
                  headline: item[:headline] || item["headline"] || "",
                  source: item[:source] || item["source"] || "",
                  timestamp: snapshot_attrs[:timestamp],
                  sentiment: "neutral"
                })
              end)
            end)
          end,
          cursor_fun: fn next_cursor ->
            BotTrader.TradingViewStore.put_cursor("stocks", next_cursor)
          end,
          on_wrap: fn ->
            if BotTrader.Config.potentials_report_enabled() do
              snapshots = BotTrader.TradingViewStore.latest_snapshots()
              text = BotTrader.Potentials.Report.build(snapshots)
              BotTrader.Telegram.send_message(text)
            end
          end,
          auto_start: true,
          name: BotTrader.TradingView.Scheduler
        }

        children ++ [{BotTrader.TradingView.Scheduler, scraper}]
      else
        children
      end

    opts = [strategy: :one_for_one, name: BotTrader.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
