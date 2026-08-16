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

    assert {:ok, candles} =
             YahooFinance.candles("PETR4.SA", 90, "1d", plug: {Req.Test, YahooFinance})

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

    assert {:ok, candles} = CoinGecko.candles("bitcoin", 90, "1d", plug: {Req.Test, CoinGecko})
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
             YahooFinance.candles("BOGUS.SA", 90, "1d", plug: {Req.Test, YahooFinance})
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
             YahooFinance.candles("PETR4.SA", 90, "1d", plug: {Req.Test, YahooFinance})

    assert length(candles) == 2
    assert Enum.all?(candles, &(&1.close != nil))
  end

  test "intraday interval param on request" do
    Req.Test.stub(YahooFinance, fn conn ->
      assert conn.query_params["interval"] == "15m"
      assert conn.query_params["range"] == "1d"
      Req.Test.json(conn, @yahoo_body)
    end)

    assert {:ok, _} =
             YahooFinance.candles("PETR4.SA", 1, "15m", plug: {Req.Test, YahooFinance})
  end

  test "coingecko buckets hourly into 15m" do
    body = [
      [1_756_848_000_000, 10.0, 12.0, 9.0, 11.0],
      [1_756_851_600_000, 11.0, 13.0, 10.0, 12.0]
    ]

    Req.Test.stub(CoinGecko, fn conn ->
      Req.Test.json(conn, body)
    end)

    assert {:ok, candles} =
             CoinGecko.candles("bitcoin", 1, "15m", plug: {Req.Test, CoinGecko})

    assert length(candles) == 8
    assert Enum.all?(candles, &(&1.open == 10.0 or &1.open == 11.0))
    assert Enum.all?(candles, &(&1.close != nil))
  end

  test "empty intraday window returns no_data" do
    body = %{
      "chart" => %{
        "result" => [
          %{
            "timestamp" => [1_756_848_000],
            "indicators" => %{
              "quote" => [
                %{
                  "open" => [nil],
                  "high" => [nil],
                  "low" => [nil],
                  "close" => [nil],
                  "volume" => [nil]
                }
              ]
            }
          }
        ],
        "error" => nil
      }
    }

    Req.Test.stub(YahooFinance, fn conn ->
      Req.Test.json(conn, body)
    end)

    assert {:error, :no_data, "PETR4.SA"} =
             YahooFinance.candles("PETR4.SA", 1, "15m", plug: {Req.Test, YahooFinance})
  end

  test "http failure returns error tuple" do
    Req.Test.stub(YahooFinance, fn conn ->
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    assert {:error, :http_error, "PETR4.SA"} =
             YahooFinance.candles("PETR4.SA", 90, "1d", plug: {Req.Test, YahooFinance})
  end

  @quote_body %{
    "quoteResponse" => %{
      "result" => [
        %{
          "symbol" => "AAPL",
          "regularMarketPrice" => 200.0,
          "regularMarketChangePercent" => 2.5,
          "regularMarketVolume" => 50_000_000
        },
        %{
          "symbol" => "MSFT",
          "regularMarketPrice" => 400.0,
          "regularMarketChangePercent" => -1.2,
          "regularMarketVolume" => 20_000_000
        }
      ],
      "error" => nil
    }
  }

  test "chunked quote fetch" do
    Req.Test.stub(YahooFinance, fn conn ->
      assert conn.request_path == "/v7/finance/quote"
      symbols = String.split(conn.query_params["symbols"], ",")
      assert length(symbols) == 2
      Req.Test.json(conn, @quote_body)
    end)

    assert {:ok, quotes} =
             YahooFinance.quotes(["AAPL", "MSFT"], plug: {Req.Test, YahooFinance})

    assert length(quotes) == 2
    assert Enum.find(quotes, &(&1.symbol == "AAPL")).day_change_pct == 2.5
    assert Enum.find(quotes, &(&1.symbol == "MSFT")).volume == 20_000_000
  end

  test "missing symbols dropped" do
    Req.Test.stub(YahooFinance, fn conn ->
      Req.Test.json(conn, @quote_body)
    end)

    assert {:ok, quotes} =
             YahooFinance.quotes(["AAPL", "MSFT", "MISSING1", "MISSING2"],
               plug: {Req.Test, YahooFinance}
             )

    assert length(quotes) == 2
    refute Enum.any?(quotes, &(&1.symbol =~ "MISSING"))
  end
end
