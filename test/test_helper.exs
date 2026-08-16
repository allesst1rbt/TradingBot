ExUnit.start()

db_dir = Path.join(System.tmp_dir!(), "bot_trader_test_db")
File.rm_rf(db_dir)
File.mkdir_p!(db_dir)

Application.put_env(:bot_trader, BotTrader.Repo,
  database: Path.join(db_dir, "test.db"),
  pool_size: 1,
  journal_mode: :wal,
  busy_timeout: 5000
)

{:ok, _sup} = Supervisor.start_link([BotTrader.Repo], strategy: :one_for_one)
Ecto.Migrator.up(BotTrader.Repo, 0, BotTrader.Release, log: false)
