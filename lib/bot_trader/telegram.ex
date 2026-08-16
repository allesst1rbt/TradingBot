defmodule BotTrader.Telegram do
  @moduledoc """
  Telegram Bot API client: per-transaction announcements, daily digest,
  and failure alerts. Sends retry once; double failure returns an error
  tuple instead of crashing.
  """

  alias BotTrader.Config

  def send_message(text, opts \\ []) do
    url = "https://api.telegram.org/bot" <> Config.telegram_bot_token() <> "/sendMessage"
    body = %{chat_id: Config.telegram_chat_id(), text: text}

    do_send(url, body, Keyword.merge(opts, retry: false))
  end

  defp do_send(url, body, opts, attempts \\ 2)

  defp do_send(_url, _body, _opts, 0), do: {:error, :telegram_failed}

  defp do_send(url, body, opts, attempts) do
    case Req.post(url, Keyword.merge([json: body, retry: false], opts)) do
      {:ok, %Req.Response{status: 200, body: %{"ok" => true}}} ->
        :ok

      _ ->
        do_send(url, body, opts, attempts - 1)
    end
  end

  def announce_trade(trade, summary, opts \\ []) do
    case send_message(format_trade_announcement(trade, summary), opts) do
      :ok -> :ok
      {:error, :telegram_failed} -> {:error, :telegram_failed}
    end
  end

  def send_digest(digest, opts \\ []) do
    send_message(format_digest(digest), opts)
  end

  def send_failure_alert(reason, opts \\ []) do
    send_message(format_failure_alert(reason), opts)
  end

  def format_failure_alert(reason) do
    "⚠️ bot_trader run FAILED: #{inspect(reason)}"
  end

  def format_trade_announcement(trade, summary) do
    reason =
      case trade[:reason] do
        nil -> ""
        reason -> "\nReason: #{humanize(reason)}"
      end

    pnl =
      case trade[:realized_pnl] do
        nil -> ""
        pnl -> "\nRealized P&L: #{pnl}"
      end

    """
    📈 #{trade.side} #{trade.symbol}
    Quantity: #{format(trade.quantity)}
    Fill price: #{format(trade.price)}
    Fee: #{format(trade.fee)}#{reason}#{pnl}
    Cash: #{format(summary.cash)} | Positions: #{summary.positions}
    """
    |> String.trim()
  end

  def format_digest(digest) do
    positions = Enum.join(digest.positions, ", ")

    """
    📊 Daily digest
    P&L today: #{digest.pnl_today}
    Open positions: #{positions}
    Risk status: #{digest.risk_status}
    Days until gate: #{digest.days_remaining}
    """
    |> String.trim()
  end

  defp humanize(:stop_loss), do: "stop-loss"
  defp humanize(:take_profit), do: "take-profit"
  defp humanize(:manual), do: "manual"
  defp humanize(reason), do: to_string(reason)

  defp format(value) when is_float(value),
    do:
      :erlang.float_to_binary(value, decimals: 4)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")

  defp format(value), do: to_string(value)
end
