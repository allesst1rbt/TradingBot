defmodule BotTrader.Risk do
  @moduledoc """
  Hard risk limits checked by the pipeline before order execution.
  Pure functions: they never mutate state.
  """

  alias BotTrader.Config

  def precheck(portfolio, order, now \\ nil)

  def precheck(portfolio, %{type: type} = order, now) when type in [:sell, :close] do
    cond do
      order[:reason] == :stop_loss -> :ok
      min_hold_violated?(portfolio, order, now) -> {:error, :min_hold}
      true -> :ok
    end
  end

  def precheck(portfolio, %{type: :buy} = order, _now) do
    cond do
      daily_loss_limit_breached?(portfolio) ->
        {:error, :daily_loss_limit}

      max_positions_breached?(portfolio, order) ->
        {:error, :max_positions}

      max_position_size_breached?(portfolio, order) ->
        {:error, :max_position_size}

      true ->
        :ok
    end
  end

  def stop_loss_candidates(portfolio, prices) do
    threshold = 1 - Config.stop_loss_pct()

    for position <- portfolio.positions,
        price = prices[position.symbol],
        is_number(price),
        price <= position.entry_price * threshold do
      {position.symbol, price}
    end
  end

  defp daily_loss_limit_breached?(portfolio) do
    limit = Config.daily_loss_pct() * portfolio.start_of_day_cash
    portfolio.day_realized_loss >= limit
  end

  defp max_positions_breached?(portfolio, order) do
    not Enum.any?(portfolio.positions, &(&1.symbol == order.symbol)) and
      length(portfolio.positions) >= Config.max_positions()
  end

  defp max_position_size_breached?(portfolio, order) do
    existing_qty =
      case Enum.find(portfolio.positions, &(&1.symbol == order.symbol)) do
        nil -> 0.0
        position -> position.quantity
      end

    new_qty = order_quantity(order)
    rate = if order.asset_class == :stock_us, do: Config.usd_brl_rate(), else: 1.0
    projected = (existing_qty + new_qty) * order.price * rate
    limit = position_cap_pct(order) * portfolio.cash
    projected > limit
  end

  defp position_cap_pct(%{source: :mover}), do: Config.max_mover_position_pct()
  defp position_cap_pct(_), do: Config.max_position_pct()

  defp min_hold_violated?(_portfolio, _order, nil), do: false

  defp min_hold_violated?(portfolio, order, now) do
    case Enum.find(portfolio.positions, &(&1.symbol == order.symbol)) do
      %{opened_at: opened_at} when is_struct(opened_at, DateTime) ->
        DateTime.diff(now, opened_at, :second) < Config.min_hold_minutes() * 60

      _ ->
        false
    end
  end

  defp order_quantity(%{quantity: qty}), do: qty

  defp order_quantity(%{notional: notional, price: price, asset_class: asset_class}) do
    rate = if asset_class == :stock_us, do: Config.usd_brl_rate(), else: 1.0
    notional / (price * rate)
  end
end
