defmodule TestRepoBoot do
  @db_dir Path.join(System.tmp_dir!(), "bot_trader_test_db")

  def start! do
    case Process.whereis(BotTrader.Repo) do
      nil ->
        File.rm_rf(@db_dir)
        File.mkdir_p!(@db_dir)

        Application.put_env(:bot_trader, BotTrader.Repo,
          database: Path.join(@db_dir, "test.db"),
          pool_size: 1,
          journal_mode: :wal,
          busy_timeout: 5000
        )

        {:ok, _} = BotTrader.Repo.start_link()

      _ ->
        :already_started
    end

    Ecto.Migrator.up(BotTrader.Repo, 0, BotTrader.Release, log: false)
    :ok
  end
end
