defmodule BotTrader.IndicatorsTest do
  use ExUnit.Case, async: true

  alias BotTrader.Indicators

  test "rsi overbought on steady rise" do
    closes = Enum.to_list(1..20) |> Enum.map(&(&1 * 1.0))
    assert Indicators.rsi(closes) >= 70.0
  end

  test "rsi oversold on steady fall" do
    closes = Enum.to_list(1..20) |> Enum.reverse() |> Enum.map(&(&1 * 1.0))
    assert Indicators.rsi(closes) <= 30.0
  end

  test "ema on flat series equals flat price" do
    flat = List.duplicate(10.0, 30)
    assert_in_delta Indicators.ema(flat, 20), 10.0, 1.0e-9
  end

  test "ema lags a trend" do
    up = Enum.to_list(1..30) |> Enum.map(&(&1 * 1.0))
    assert Indicators.ema(up, 20) < 30.0
  end

  test "daily return computed from last two closes" do
    assert_in_delta Indicators.daily_return([100.0, 110.0]), 0.10, 1.0e-9
    assert_in_delta Indicators.daily_return([100.0, 95.0]), -0.05, 1.0e-9
  end
end
