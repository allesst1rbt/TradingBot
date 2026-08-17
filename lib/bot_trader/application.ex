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
      BotTrader.Migration.run(state_dir)
    end

    children = [
      {BotTrader.Scheduler, name: BotTrader.Scheduler},
      {BotTrader.Telegram.Poller, name: BotTrader.Telegram.Poller}
    ]

    opts = [strategy: :one_for_one, name: BotTrader.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
