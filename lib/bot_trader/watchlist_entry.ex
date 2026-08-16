defmodule BotTrader.WatchlistEntry do
  use Ecto.Schema

  schema "watchlist" do
    field :symbol, :string
    field :asset_class, :string
    field :coin_id, :string
    field :added_at, :utc_datetime
    field :source, :string
  end
end
