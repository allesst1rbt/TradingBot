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

  test "rsi ignores nil closes" do
    closes = [
      100.0,
      nil,
      101.0,
      102.0,
      103.0,
      104.0,
      105.0,
      106.0,
      107.0,
      108.0,
      109.0,
      110.0,
      111.0,
      112.0,
      113.0,
      114.0
    ]

    assert Indicators.rsi(closes) >= 70.0
  end

  test "ema ignores nil closes" do
    flat = Enum.map(1..30, fn i -> if rem(i, 5) == 0, do: nil, else: 10.0 end)
    assert_in_delta Indicators.ema(flat, 20), 10.0, 1.0e-9
  end
end
