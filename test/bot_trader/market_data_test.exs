defmodule BotTrader.MarketDataTest do
  use ExUnit.Case, async: true

  alias BotTrader.MarketData
  alias BotTrader.MarketData.CoinGecko
  alias BotTrader.MarketData.YahooFinance

  @yahoo_body %{
    "chart" => %{
      "result" => [
        %{
          "timestamp" => [1_756_848_000, 1_756_934_400],
          "indicators" => %{
            "quote" => [
              %{
                "open" => [10.0, 11.0],
                "high" => [10.5, 11.5],
                "low" => [9.5, 10.5],
                "close" => [10.2, 11.2],
                "volume" => [1000, 1100]
              }
            ]
          }
        }
      ],
      "error" => nil
    }
  }

  test "normalizes yahoo candles" do
    Req.Test.stub(YahooFinance, fn conn ->
      Req.Test.json(conn, @yahoo_body)
    end)

    assert {:ok, candles} = YahooFinance.candles("PETR4.SA", 90, plug: {Req.Test, YahooFinance})
    assert length(candles) == 2

    assert [first, second] = candles
    assert first.open == 10.0
    assert first.high == 10.5
    assert first.low == 9.5
    assert first.close == 10.2
    assert first.volume == 1000
    assert second.close == 11.2
  end

  test "routes b3 ticker to yahoo with SA suffix" do
    entry = %{symbol: "PETR4", asset_class: :stock_br}
    assert {YahooFinance, "PETR4.SA"} = MarketData.router(entry)
  end

  test "routes us ticker to yahoo without suffix" do
    entry = %{symbol: "AAPL", asset_class: :stock_us}
    assert {YahooFinance, "AAPL"} = MarketData.router(entry)
  end

  test "routes crypto to coingecko with coin id" do
    entry = %{symbol: "BTC", asset_class: :crypto, coin_id: "bitcoin"}
    assert {CoinGecko, "bitcoin"} = MarketData.router(entry)
  end

  test "normalizes coingecko ohlc candles" do
    body = [
      [1_756_848_000, 10.0, 10.5, 9.5, 10.2],
      [1_756_934_400, 11.0, 11.5, 10.5, 11.2]
    ]

    Req.Test.stub(CoinGecko, fn conn ->
      Req.Test.json(conn, body)
    end)

    assert {:ok, candles} = CoinGecko.candles("bitcoin", 90, plug: {Req.Test, CoinGecko})
    assert length(candles) == 2
    assert [first, second] = candles
    assert first.open == 10.0
    assert first.close == 10.2
    assert first.volume == 0.0
    assert second.close == 11.2
  end

  test "empty result returns error tuple" do
    Req.Test.stub(YahooFinance, fn conn ->
      Req.Test.json(conn, %{"chart" => %{"result" => nil, "error" => nil}})
    end)

    assert {:error, :no_data, "BOGUS.SA"} =
             YahooFinance.candles("BOGUS.SA", 90, plug: {Req.Test, YahooFinance})
  end

  test "drops candles with nil close" do
    body = %{
      "chart" => %{
        "result" => [
          %{
            "timestamp" => [1_756_848_000, 1_756_934_400, 1_757_020_800],
            "indicators" => %{
              "quote" => [
                %{
                  "open" => [10.0, nil, 12.0],
                  "high" => [10.5, nil, 12.5],
                  "low" => [9.5, nil, 11.5],
                  "close" => [10.2, nil, 12.2],
                  "volume" => [1000, nil, 1100]
                }
              ]
            }
          }
        ]
      },
      "error" => nil
    }

    Req.Test.stub(YahooFinance, fn conn ->
      Req.Test.json(conn, body)
    end)

    assert {:ok, candles} =
             YahooFinance.candles("PETR4.SA", 90, plug: {Req.Test, YahooFinance})

    assert length(candles) == 2
    assert Enum.all?(candles, &(&1.close != nil))
  end

  test "http failure returns error tuple" do
    Req.Test.stub(YahooFinance, fn conn ->
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    assert {:error, :http_error, "PETR4.SA"} =
             YahooFinance.candles("PETR4.SA", 90, plug: {Req.Test, YahooFinance})
  end
end
