defmodule BotTrader.Research do
  @moduledoc """
  Research pipeline: hybrid universe (seed watchlist + LLM candidates),
  prompt building, and qualitative report rendering.
  """

  def universe(watchlist, candidates, cap) do
    watchlist ++ Enum.take(candidates, cap)
  end

  def build_prompt(entry, context) do
    position =
      case context.position do
        nil -> "none"
        position -> "#{position.quantity} @ #{position.entry_price}"
      end

    tradingview =
      case context[:tradingview_snapshot] do
        nil -> ""
        snapshot -> "\nTradingView snapshot: #{Jason.encode!(snapshot)}"
      end

    """
    You are a swing trading analyst. Analyze the asset below using technical indicators
    and your qualitative knowledge of recent news and fundamentals.

    Symbol: #{entry.symbol}
    Asset class: #{entry.asset_class}
    RSI(14): #{format(context.rsi)}
    EMA(20): #{format(context.ema20)}
    EMA(50): #{format(context.ema50)}
    Last close: #{format(context.last_close)}
    Daily return: #{format(context.daily_return)}
    Current position: #{position}
    Available cash (BRL): #{format(context.cash_brl)}
    #{context[:rolling_summary]}#{tradingview}

    Respond with a single JSON object:
    {"action": "BUY" | "SELL" | "HOLD" | "CLOSE",
     "confidence": 0.0..1.0,
     "rationale": "short justification",
     "target_weight": 0.0..0.25,
     "qualitative": "1-2 sentences of qualitative analysis about recent news/fundamentals"}
    """
    |> String.trim()
  end

  def render_qualitative(%{symbol: symbol, qualitative: qualitative}) do
    """
    ### Qualitative analysis — #{symbol}

    #{qualitative}

    _Label: this section is LLM prose and is non-deterministic._
    """
    |> String.trim()
  end

  def build_rolling_summary(attrs) do
    position =
      case attrs.position do
        nil -> "none"
        %{quantity: qty} -> "#{qty}"
      end

    """
    Rolling 24h: #{attrs.runs} runs | last signal: #{attrs.last_signal} | position: #{position} | equity: #{format(attrs.equity)} | news notes: #{attrs.news_count}
    """
    |> String.trim()
  end

  defp format(nil), do: "n/a"
  defp format(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 4)
  defp format(value), do: to_string(value)
end
