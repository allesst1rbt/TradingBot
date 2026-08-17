defmodule BotTrader.TradingViewSnapshot do
  use Ecto.Schema

  schema "tradingview_snapshots" do
    field(:symbol, :string)
    field(:asset_class, :string)
    field(:timestamp, :utc_datetime)
    field(:timeframe, :string)
    field(:price, :float)
    field(:change_pct, :float)
    field(:open, :float)
    field(:high, :float)
    field(:low, :float)
    field(:close, :float)
    field(:volume, :float)
    field(:technical_rating, :string)
    field(:rsi, :float)
    field(:macd, :float)
    field(:ema20, :float)
    field(:sma50, :float)
    field(:provider, :string)
    field(:stale, :boolean, default: false)
  end
end

defmodule BotTrader.TradingViewCursor do
  use Ecto.Schema

  @primary_key {:key, :string, autogenerate: false}
  schema "tradingview_cursors" do
    field(:position, :integer, default: 0)
    field(:updated_at, :utc_datetime)
  end
end
