defmodule BotTrader.RiskTest do
  use ExUnit.Case, async: true

  alias BotTrader.Portfolio
  alias BotTrader.Risk

  defp buy_order(notional) do
    %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: notional, price: 1000.0}
  end

  test "rejects over-max position size" do
    portfolio = Portfolio.init()
    order = buy_order(300.0)

    assert {:error, :max_position_size} = Risk.precheck(portfolio, order)
  end

  test "allows buy within max position size" do
    portfolio = Portfolio.init()
    order = buy_order(200.0)

    assert :ok = Risk.precheck(portfolio, order)
  end

  test "rejects 11th position" do
    portfolio = Portfolio.init()

    filled =
      Enum.reduce(1..10, portfolio, fn i, acc ->
        order = %{
          type: :buy,
          symbol: "SYM#{i}",
          asset_class: :crypto,
          notional: 50.0,
          price: 100.0
        }

        {:ok, acc, _} = Portfolio.apply(acc, order)
        acc
      end)

    order = %{type: :buy, symbol: "SYM11", asset_class: :crypto, notional: 50.0, price: 100.0}
    assert {:error, :max_positions} = Risk.precheck(filled, order)
  end

  test "adding to existing position is not a new position" do
    portfolio = Portfolio.init()

    portfolio =
      Enum.reduce(1..6, portfolio, fn i, acc ->
        order = %{
          type: :buy,
          symbol: "SYM#{i}",
          asset_class: :crypto,
          notional: 50.0,
          price: 100.0
        }

        {:ok, acc, _} = Portfolio.apply(acc, order)
        acc
      end)

    order = %{type: :buy, symbol: "SYM1", asset_class: :crypto, notional: 10.0, price: 100.0}
    assert :ok = Risk.precheck(portfolio, order)
  end

  test "stop-loss candidates are positions at or below threshold" do
    portfolio = Portfolio.init()

    orders = [
      %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: 100.0, price: 1000.0},
      %{type: :buy, symbol: "ETH", asset_class: :crypto, notional: 100.0, price: 100.0}
    ]

    portfolio =
      Enum.reduce(orders, portfolio, fn order, acc ->
        {:ok, acc, _} = Portfolio.apply(acc, order)
        acc
      end)

    prices = %{"BTC" => 940.0, "ETH" => 100.5}

    assert [{"BTC", 940.0}] = Risk.stop_loss_candidates(portfolio, prices)
  end

  test "stop-loss close removes position and records pnl" do
    portfolio = Portfolio.init()
    buy = %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: 100.0, price: 1000.0}
    assert {:ok, portfolio, _} = Portfolio.apply(portfolio, buy)

    assert [{"BTC", 940.0}] = Risk.stop_loss_candidates(portfolio, %{"BTC" => 940.0})
    close = %{type: :close, symbol: "BTC", asset_class: :crypto, price: 940.0, reason: :stop_loss}
    assert {:ok, updated, trade} = Portfolio.apply(portfolio, close)

    assert updated.positions == []
    assert trade.side == "CLOSE"
    assert trade.reason == :stop_loss
    assert updated.realized_pnl < 0
  end

  test "daily loss limit blocks buys but not closes" do
    portfolio = %{Portfolio.init() | day_realized_loss: 35.0, start_of_day_cash: 1000.0}

    assert {:error, :daily_loss_limit} = Risk.precheck(portfolio, buy_order(50.0))

    close = %{type: :close, symbol: "BTC", asset_class: :crypto, price: 1000.0, reason: :manual}
    assert :ok = Risk.precheck(portfolio, close)
  end

  test "mover buy over 10 percent rejected" do
    portfolio = Portfolio.init()

    order = %{
      type: :buy,
      symbol: "BTC",
      asset_class: :crypto,
      notional: 150.0,
      price: 100.0,
      source: :mover
    }

    assert {:error, :max_position_size} = Risk.precheck(portfolio, order)
  end

  test "mover buy under 10 percent allowed" do
    portfolio = Portfolio.init()

    order = %{
      type: :buy,
      symbol: "BTC",
      asset_class: :crypto,
      notional: 90.0,
      price: 100.0,
      source: :mover
    }

    assert :ok = Risk.precheck(portfolio, order)
  end

  test "watchlist 25 percent unaffected" do
    portfolio = Portfolio.init()
    order = %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: 200.0, price: 100.0}
    assert :ok = Risk.precheck(portfolio, order)

    over = %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: 300.0, price: 100.0}
    assert {:error, :max_position_size} = Risk.precheck(portfolio, over)
  end

  test "daily loss under limit allows buys" do
    portfolio = %{Portfolio.init() | day_realized_loss: 29.9, start_of_day_cash: 1000.0}
    assert :ok = Risk.precheck(portfolio, buy_order(50.0))
  end

  test "rejects close of fresh position" do
    portfolio = Portfolio.init()
    now = ~U[2026-08-16 12:00:00Z]

    buy = %{
      type: :buy,
      symbol: "BTC",
      asset_class: :crypto,
      notional: 100.0,
      price: 1000.0,
      ts: DateTime.add(now, -3 * 60, :second)
    }

    assert {:ok, portfolio, _} = Portfolio.apply(portfolio, buy)

    close = %{type: :close, symbol: "BTC", asset_class: :crypto, price: 1000.0, reason: :signal}
    assert {:error, :min_hold} = Risk.precheck(portfolio, close, now)
  end

  test "stop-loss bypasses min-hold" do
    portfolio = Portfolio.init()
    now = ~U[2026-08-16 12:00:00Z]

    buy = %{
      type: :buy,
      symbol: "BTC",
      asset_class: :crypto,
      notional: 100.0,
      price: 1000.0,
      ts: DateTime.add(now, -3 * 60, :second)
    }

    assert {:ok, portfolio, _} = Portfolio.apply(portfolio, buy)

    stop = %{type: :close, symbol: "BTC", asset_class: :crypto, price: 940.0, reason: :stop_loss}
    assert :ok = Risk.precheck(portfolio, stop, now)
  end

  test "old position closes normally" do
    portfolio = Portfolio.init()
    now = ~U[2026-08-16 12:00:00Z]

    buy = %{
      type: :buy,
      symbol: "BTC",
      asset_class: :crypto,
      notional: 100.0,
      price: 1000.0,
      ts: DateTime.add(now, -20 * 60, :second)
    }

    assert {:ok, portfolio, _} = Portfolio.apply(portfolio, buy)

    close = %{type: :close, symbol: "BTC", asset_class: :crypto, price: 1000.0, reason: :signal}
    assert :ok = Risk.precheck(portfolio, close, now)
  end
end
