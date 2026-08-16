defmodule BotTrader.TelegramTest do
  use ExUnit.Case, async: true

  alias BotTrader.Telegram

  setup do
    System.put_env("TELEGRAM_BOT_TOKEN", "test-token")
    System.put_env("TELEGRAM_CHAT_ID", "123456")

    on_exit(fn ->
      System.delete_env("TELEGRAM_BOT_TOKEN")
      System.delete_env("TELEGRAM_CHAT_ID")
    end)

    :ok
  end

  test "announces buy with fill and fee" do
    trade = %{symbol: "BTC", side: "BUY", quantity: 0.09995, price: 300_000.0, fee: 0.1}
    summary = %{cash: 899.9, positions: 1}

    message = Telegram.format_trade_announcement(trade, summary)

    assert message =~ "BTC"
    assert message =~ "BUY"
    assert message =~ "300000"
    assert message =~ "0.1"
    assert message =~ "899.9"
  end

  test "announces stop-loss close with pnl" do
    trade = %{
      symbol: "ETH",
      side: "CLOSE",
      quantity: 0.5,
      price: 95.0,
      fee: 0.0475,
      reason: :stop_loss,
      realized_pnl: -10.0
    }

    message = Telegram.format_trade_announcement(trade, %{cash: 850.0, positions: 0})
    assert message =~ "ETH"
    assert message =~ "CLOSE"
    assert message =~ "stop-loss"
    assert message =~ "-10"
  end

  test "formats digest" do
    digest = %{
      pnl_today: 12.3,
      positions: ["BTC", "AAPL"],
      risk_status: "OK",
      days_remaining: 27
    }

    message = Telegram.format_digest(digest)
    assert message =~ "12.3"
    assert message =~ "BTC"
    assert message =~ "AAPL"
    assert message =~ "OK"
    assert message =~ "27"
  end

  test "retries once then succeeds" do
    req_opts = [plug: {Req.Test, Telegram}]

    Req.Test.expect(Telegram, 1, fn conn ->
      send(self(), :attempt)
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    Req.Test.expect(Telegram, 1, fn conn ->
      send(self(), :attempt)
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert :ok = Telegram.send_message("hello", req_opts)
    assert_received :attempt
    assert_received :attempt
    refute_received :attempt
    Req.Test.verify_on_exit!(Telegram)
  end

  test "logs double failure without crash" do
    req_opts = [plug: {Req.Test, Telegram}]

    Req.Test.expect(Telegram, 2, fn conn ->
      send(self(), :attempt)
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    assert {:error, :telegram_failed} = Telegram.send_message("hello", req_opts)
    assert_received :attempt
    assert_received :attempt
    Req.Test.verify_on_exit!(Telegram)
  end
end
