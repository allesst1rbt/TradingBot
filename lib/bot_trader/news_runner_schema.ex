defmodule BotTrader.NewsRunnerRow do
  use Ecto.Schema

  schema "news_runner" do
    field(:symbol, :string)
    field(:headline, :string)
    field(:source, :string)
    field(:timestamp, :utc_datetime)
    field(:sentiment, :string)
    field(:hash, :string)
    field(:inserted_at, :utc_datetime)
  end
end
