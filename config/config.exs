import Config

if config_env() == :test do
  System.put_env("TELEGRAM_BOT_TOKEN", "test")
  System.put_env("TELEGRAM_CHAT_ID", "1")
  System.put_env("BOT_STATE_DIR", Path.join(System.tmp_dir!(), "bot_trader_app_state"))
  System.put_env("OPENCODE_GO_API_KEY", "test")
  System.put_env("DEEPSEEK_API_KEY", "test")

  db_dir = Path.join(System.tmp_dir!(), "bot_trader_test_db")
  File.rm_rf(db_dir)
  File.mkdir_p!(db_dir)

  config :bot_trader, BotTrader.Repo,
    database: Path.join(db_dir, "test.db"),
    pool_size: 1,
    journal_mode: :wal,
    busy_timeout: 5000
end
