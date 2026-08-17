defmodule BotTrader.TradingViewProviderTest do
  use ExUnit.Case, async: true

  alias BotTrader.TradingView.Provider

  test "uses yahoo fallback" do
    tv = fn _entry -> {:error, :blocked} end
    yahoo = fn _entry -> {:ok, %{symbol: "VIVT3", price: 42.0, provider: "yahoo"}} end

    assert {:ok, snapshot} = Provider.fetch(%{symbol: "VIVT3"}, tradingview: tv, yahoo: yahoo)
    assert snapshot.provider == "yahoo"
    assert snapshot.fallback == true
  end

  test "tradingview is primary" do
    tv = fn _entry -> {:ok, %{symbol: "VIVT3", price: 42.5, provider: "tradingview"}} end
    yahoo = fn _entry -> flunk("fallback should not run") end

    assert {:ok, snapshot} = Provider.fetch(%{symbol: "VIVT3"}, tradingview: tv, yahoo: yahoo)
    assert snapshot.provider == "tradingview"
  end
end
