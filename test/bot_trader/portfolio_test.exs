defmodule BotTrader.PortfolioTest do
  use ExUnit.Case, async: true

  alias BotTrader.Portfolio

  test "crypto buy applies fee and slippage" do
    portfolio = Portfolio.init()
    order = %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: 100.0, price: 300_000.0}

    assert {:ok, updated, trade} = Portfolio.apply(portfolio, order)

    assert trade.opened_at != nil

    expected_fee = 100.0 * 0.001
    assert_in_delta updated.cash, 1000.0 - 100.0 - expected_fee, 1.0e-9
    expected_qty = 100.0 * (1 - 0.0005) / 300_000.0
    assert_in_delta trade.quantity, expected_qty, 1.0e-12
    assert trade.fee == expected_fee

    assert [position] = updated.positions
    assert position.symbol == "BTC"
    assert_in_delta position.quantity, expected_qty, 1.0e-12
  end

  test "us stock buy applies flat fee" do
    portfolio = Portfolio.init()
    order = %{type: :buy, symbol: "AAPL", asset_class: :stock_us, quantity: 2.0, price: 200.0}

    assert {:ok, updated, trade} = Portfolio.apply(portfolio, order)

    fee_brl = 1.0 * 5.5
    expected_cost = 2.0 * 200.0 * 5.5
    assert_in_delta updated.cash, 1000.0 - expected_cost - fee_brl, 1.0e-9
    assert trade.fee == fee_brl
    assert_in_delta trade.quantity, 2.0 * (1 - 0.0005), 1.0e-9
  end

  test "b3 stock buy applies flat fee" do
    portfolio = Portfolio.init()
    order = %{type: :buy, symbol: "PETR4", asset_class: :stock_br, quantity: 10.0, price: 20.0}

    assert {:ok, updated, trade} = Portfolio.apply(portfolio, order)

    expected_cost = 10.0 * 20.0
    assert_in_delta updated.cash, 1000.0 - expected_cost - 5.0, 1.0e-9
    assert trade.fee == 5.0
  end

  test "sell closes position with slippage and realized pnl" do
    portfolio = Portfolio.init()
    buy = %{type: :buy, symbol: "BTC", asset_class: :crypto, notional: 100.0, price: 1000.0}
    assert {:ok, portfolio, _} = Portfolio.apply(portfolio, buy)

    sell = %{type: :sell, symbol: "BTC", asset_class: :crypto, quantity: 0.05, price: 1100.0}
    assert {:ok, updated, trade} = Portfolio.apply(portfolio, sell)

    proceeds = 0.05 * 1100.0 * (1 - 0.0005)
    fee = proceeds * 0.001
    assert_in_delta updated.cash, 1000.0 - 100.0 - 0.1 + proceeds - fee, 1.0e-9
    assert trade.side == "SELL"
    assert_in_delta updated.realized_pnl, (1100.0 * (1 - 0.0005) - 1000.0) * 0.05, 1.0e-9
  end
end
