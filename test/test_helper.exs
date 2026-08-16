ExUnit.start()

{:ok, _} = Supervisor.start_link([BotTrader.Repo], strategy: :one_for_one)
Ecto.Migrator.up(BotTrader.Repo, 0, BotTrader.Release, log: false)
Ecto.Migrator.up(BotTrader.Repo, 1, BotTrader.Release.V2, log: false)
