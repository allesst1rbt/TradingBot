defmodule BotTrader.Portfolio do
  @moduledoc """
  Pure paper portfolio engine. `apply/2` executes an order and returns
  the updated portfolio plus a trade record. All fees, slippage, and
  currency conversions are applied here. Risk checks live in `BotTrader.Risk`
  and are invoked by the pipeline before calling `apply/2`.
  """

  alias BotTrader.Config

  defstruct cash: 0.0,
            positions: [],
            realized_pnl: 0.0,
            day_realized_loss: 0.0,
            start_of_day_cash: 0.0,
            day: nil

  defmodule Position do
    @moduledoc false
    defstruct [:symbol, :asset_class, :quantity, :entry_price]
  end

  def init do
    cash = Config.start_capital_brl()
    %__MODULE__{cash: cash, start_of_day_cash: cash}
  end

  def new_day(portfolio, date) do
    if portfolio.day == date do
      portfolio
    else
      %{portfolio | day: date, day_realized_loss: 0.0, start_of_day_cash: portfolio.cash}
    end
  end

  def apply(portfolio, %{type: :buy} = order) do
    qty = order_quantity(order)
    filled = qty * (1 - Config.slippage())
    notional = order_notional(order)
    fee = buy_fee(order.asset_class, notional)

    position =
      update_position(portfolio.positions, order.symbol, order.asset_class, filled, order.price)

    trade = %{
      symbol: order.symbol,
      side: "BUY",
      quantity: filled,
      price: order.price,
      fee: fee,
      reason: order[:reason],
      ts: ts(order)
    }

    {:ok,
     %{
       portfolio
       | cash: portfolio.cash - notional - fee,
         positions: position
     }, trade}
  end

  def apply(portfolio, %{type: type} = order) when type in [:sell, :close] do
    case fetch_position(portfolio.positions, order.symbol) do
      nil ->
        {:error, :no_position}

      position ->
        target = if type == :close, do: position.quantity, else: order.quantity
        filled = min(target, position.quantity)
        proceeds = value_in_brl(order.asset_class, filled, order.price) * (1 - Config.slippage())
        fee = sell_fee(order.asset_class, proceeds)

        realized =
          (order.price * (1 - Config.slippage()) - position.entry_price) * filled *
            rate(order.asset_class)

        loss = -min(realized, 0.0)

        positions =
          if filled >= position.quantity do
            List.delete(portfolio.positions, position)
          else
            update_position_qty(portfolio.positions, order.symbol, position.quantity - filled)
          end

        trade = %{
          symbol: order.symbol,
          side: if(type == :close, do: "CLOSE", else: "SELL"),
          quantity: filled,
          price: order.price,
          fee: fee,
          reason: order[:reason],
          realized_pnl: realized,
          ts: ts(order)
        }

        {:ok,
         %{
           portfolio
           | cash: portfolio.cash + proceeds - fee,
             positions: positions,
             realized_pnl: portfolio.realized_pnl + realized,
             day_realized_loss: portfolio.day_realized_loss + loss
         }, trade}
    end
  end

  defp update_position(positions, symbol, asset_class, qty, price) do
    case Enum.find_index(positions, &(&1.symbol == symbol)) do
      nil ->
        positions ++
          [%Position{symbol: symbol, asset_class: asset_class, quantity: qty, entry_price: price}]

      index ->
        List.update_at(positions, index, &%{&1 | quantity: &1.quantity + qty})
    end
  end

  defp update_position_qty(positions, symbol, qty) do
    index = Enum.find_index(positions, &(&1.symbol == symbol))
    List.update_at(positions, index, &%{&1 | quantity: qty})
  end

  defp fetch_position(positions, symbol), do: Enum.find(positions, &(&1.symbol == symbol))

  defp order_quantity(%{quantity: qty}), do: qty

  defp order_quantity(%{notional: notional, price: price, asset_class: asset_class}) do
    notional / (price * rate(asset_class))
  end

  defp order_notional(%{notional: notional}), do: notional

  defp order_notional(%{quantity: qty, price: price, asset_class: asset_class}) do
    qty * price * rate(asset_class)
  end

  defp buy_fee(:crypto, notional), do: notional * Config.crypto_fee()
  defp buy_fee(:stock_us, _notional), do: Config.us_fee_usd() * Config.usd_brl_rate()
  defp buy_fee(:stock_br, _notional), do: Config.b3_fee_brl()

  defp sell_fee(:crypto, proceeds), do: proceeds * Config.crypto_fee()
  defp sell_fee(:stock_us, _proceeds), do: Config.us_fee_usd() * Config.usd_brl_rate()
  defp sell_fee(:stock_br, _proceeds), do: Config.b3_fee_brl()

  defp rate(:stock_us), do: Config.usd_brl_rate()
  defp rate(_), do: 1.0

  defp value_in_brl(:stock_us, qty, price), do: qty * price * Config.usd_brl_rate()
  defp value_in_brl(_, qty, price), do: qty * price

  defp ts(%{ts: ts}), do: ts
  defp ts(_), do: DateTime.utc_now()
end
