defmodule BotTrader.ConfigTest do
  use ExUnit.Case, async: true

  alias BotTrader.Config

  test "market open within 4-18 gmt-4 window (8-22 utc)" do
    # Friday 10:00 UTC = 06:00 GMT-4 -> open
    assert Config.market_open?(~U[2026-08-14 10:00:00Z]) == true
    # Friday 20:00 UTC = 16:00 GMT-4 -> open
    assert Config.market_open?(~U[2026-08-14 20:00:00Z]) == true
    # Friday 22:30 UTC = 18:30 GMT-4 -> closed (past 18:00 local)
    assert Config.market_open?(~U[2026-08-14 22:30:00Z]) == false
    # Friday 07:00 UTC = 03:00 GMT-4 -> closed (before 04:00 local)
    assert Config.market_open?(~U[2026-08-14 07:00:00Z]) == false
    # Saturday stays closed
    assert Config.market_open?(~U[2026-08-15 15:00:00Z]) == false
  end
end
