ExUnit.start()

{:ok, _} = Supervisor.start_link([BotTrader.Repo], strategy: :one_for_one)
Ecto.Migrator.up(BotTrader.Repo, 0, BotTrader.Release, log: false)
Ecto.Migrator.up(BotTrader.Repo, 1, BotTrader.Release.V2, log: false)
Ecto.Migrator.up(BotTrader.Repo, 2, BotTrader.Release.V3, log: false)
Ecto.Migrator.up(BotTrader.Repo, 3, BotTrader.Release.V4, log: false)
Ecto.Migrator.up(BotTrader.Repo, 4, BotTrader.Release.V5, log: false)
Ecto.Migrator.up(BotTrader.Repo, 5, BotTrader.Release.V6, log: false)
