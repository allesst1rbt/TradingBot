defmodule BotTrader.Run do
  use Ecto.Schema

  schema "runs" do
    field(:kind, :string)
    field(:started_at, :utc_datetime)
    field(:finished_at, :utc_datetime)
    field(:status, :string)
    field(:calls, :integer, default: 0)
    field(:note, :string)
  end
end

defmodule BotTrader.Signal do
  use Ecto.Schema

  schema "signals" do
    field(:symbol, :string)
    field(:action, :string)
    field(:confidence, :float)
    field(:model, :string)
    field(:price, :float)
    field(:rationale, :string)
    belongs_to(:run, BotTrader.Run)
  end
end

defmodule BotTrader.Trade do
  use Ecto.Schema

  schema "trades" do
    field(:symbol, :string)
    field(:side, :string)
    field(:quantity, :float)
    field(:price, :float)
    field(:fee, :float)
    field(:realized_pnl, :float)
    field(:reason, :string)
    field(:opened_at, :utc_datetime)
    field(:closed_at, :utc_datetime)
    field(:ts, :utc_datetime)
    belongs_to(:run, BotTrader.Run)
  end
end

defmodule BotTrader.Snapshot do
  use Ecto.Schema

  schema "snapshots" do
    field(:ts, :utc_datetime)
    field(:equity, :float)
    field(:cash, :float)
    field(:realized_pnl, :float)
    belongs_to(:run, BotTrader.Run)
  end
end

defmodule BotTrader.News do
  use Ecto.Schema

  schema "news" do
    field(:symbol, :string)
    field(:trigger, :float)
    field(:text, :string)
    belongs_to(:run, BotTrader.Run)
  end
end

defmodule BotTrader.PollerState do
  use Ecto.Schema

  @primary_key {:key, :string, autogenerate: false}
  schema "poller_state" do
    field(:value, :string)
  end
end
