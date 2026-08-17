defmodule BotTrader.CandleCache do
  @moduledoc """
  Short-lived cache for 15m candle fetches. The 5-min runner re-fetches
  the same 15m candles every tick; caching them for CANDLE_CACHE_SECONDS
  cuts Yahoo request volume ~3x and avoids rate-limit churn.
  """

  alias BotTrader.Config

  @table :bot_trader_candle_cache

  def fetch(symbol, days, fun) do
    ensure_table()
    now = System.monotonic_time(:millisecond)
    ttl = Config.candle_cache_seconds() * 1000
    key = {symbol, days}

    case :ets.lookup(@table, key) do
      [{^key, candles, fetched_at}] when now - fetched_at < ttl ->
        {:ok, candles}

      _ ->
        case fun.() do
          {:ok, candles} ->
            :ets.insert(@table, {key, candles, now})
            {:ok, candles}

          other ->
            other
        end
    end
  end

  def clear do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
      _ -> :ok
    end
  end
end
