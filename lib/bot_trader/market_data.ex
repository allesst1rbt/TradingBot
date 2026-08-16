defmodule BotTrader.MarketData do
  @moduledoc """
  Pluggable market data providers. Each provider implements
  `candles/2` returning normalized daily candles.
  """

  @callback candles(symbol :: String.t(), days :: non_neg_integer()) ::
              {:ok, [map()]} | {:error, atom(), String.t()}

  defmodule Candle do
    @moduledoc false
    defstruct [:ts, :open, :high, :low, :close, :volume]
  end

  def router(%{asset_class: :stock_br, symbol: symbol}) do
    {BotTrader.MarketData.YahooFinance, symbol <> ".SA"}
  end

  def router(%{asset_class: :stock_us, symbol: symbol}) do
    {BotTrader.MarketData.YahooFinance, symbol}
  end

  def router(%{asset_class: :crypto, coin_id: coin_id}) do
    {BotTrader.MarketData.CoinGecko, coin_id}
  end
end
