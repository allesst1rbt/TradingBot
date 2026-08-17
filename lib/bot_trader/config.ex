defmodule BotTrader.Config do
  @moduledoc """
  Environment-driven configuration. Every value has a default so local
  runs work without any env vars set (except secrets, which fail loudly).
  """

  def state_dir, do: env("BOT_STATE_DIR", "./data")

  def llm_backend, do: env("LLM_BACKEND", "hermes")
  def hermes_bin, do: env("HERMES_BIN", "hermes")
  def hermes_model, do: env("HERMES_MODEL", "deepseek-v4-pro")
  def hermes_timeout_ms, do: env_int("HERMES_TIMEOUT_MS", 120_000)
  def hermes_mcp_bin, do: env("HERMES_MCP_BIN", "hermes")
  def hermes_mcp_args, do: env("HERMES_MCP_ARGS", "mcp") |> String.split(",")
  def llm_model_flash, do: env("LLM_MODEL_FLASH", "deepseek-v4-flash")
  def llm_model_pro, do: env("LLM_MODEL_PRO", "deepseek-v4-pro")
  def volatility_threshold, do: env_float("VOLATILITY_THRESHOLD", 0.02)
  def llm_call_budget_per_run, do: env_int("LLM_CALL_BUDGET_PER_RUN", 10)
  def daily_call_budget, do: env_int("DAILY_CALL_BUDGET", 5000)
  def min_hold_minutes, do: env_int("MIN_HOLD_MINUTES", 15)
  def run_interval_ms, do: env_int("RUN_INTERVAL_MS", 300_000)
  def analysis_interval, do: env("ANALYSIS_INTERVAL", "15m")
  def deep_run_hour_utc, do: env_int("DEEP_RUN_HOUR_UTC", 21)
  def deep_run_minute_utc, do: env_int("DEEP_RUN_MINUTE_UTC", 30)
  def universe_path, do: env("UNIVERSE_PATH", "config/market_universe.json")
  def universe_quote_chunk, do: env_int("UNIVERSE_QUOTE_CHUNK", 50)
  def universe_volume_floor, do: env_int("UNIVERSE_VOLUME_FLOOR", 1_000_000)
  def universe_scan_enabled, do: env("UNIVERSE_SCAN_ENABLED", "true") == "true"
  def mover_count, do: env_int("MOVER_COUNT", 10)
  def max_mover_position_pct, do: env_float("MAX_MOVER_POSITION_PCT", 0.10)
  def market_hours_enabled, do: env("MARKET_HOURS_ENABLED", "true") == "true"
  def candle_cache_seconds, do: env_int("CANDLE_CACHE_SECONDS", 900)
  def universe_screen_every_minutes, do: env_int("UNIVERSE_SCREEN_EVERY_MINUTES", 60)
  def universe_scan_every_n_runs, do: env_int("UNIVERSE_SCAN_EVERY_N_RUNS", 30)
  def hermes_memory_path, do: env("HERMES_MEMORY_PATH", "/data/hermes_memory.md")
  def tradingview_enabled, do: env("TRADINGVIEW_ENABLED", "true") == "true"
  def tradingview_batch_size, do: env_int("TRADINGVIEW_BATCH_SIZE", 25)
  def tradingview_max_concurrency, do: env_int("TRADINGVIEW_MAX_CONCURRENCY", 2)

  def market_hours_start_utc, do: env_int("MARKET_HOURS_START_UTC", 8)
  def market_hours_end_utc, do: env_int("MARKET_HOURS_END_UTC", 22)

  def market_open?(now \\ DateTime.utc_now()) do
    case Date.day_of_week(DateTime.to_date(now)) do
      d when d in [6, 7] ->
        false

      _ ->
        now.hour >= market_hours_start_utc() and now.hour < market_hours_end_utc()
    end
  end

  def yahoo_base_url, do: env("YAHOO_BASE_URL", "https://query1.finance.yahoo.com")
  def coingecko_base_url, do: env("COINGECKO_BASE_URL", "https://api.coingecko.com")

  def deepseek_base_url, do: env("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1")
  def deepseek_model, do: env("DEEPSEEK_MODEL", "deepseek-v4-pro")

  def deepseek_api_key do
    case System.get_env("DEEPSEEK_API_KEY") do
      nil -> raise "DEEPSEEK_API_KEY is required"
      key -> key
    end
  end

  def confidence_threshold, do: env_float("LLM_CONFIDENCE_THRESHOLD", 0.6)

  def telegram_bot_token do
    case System.get_env("TELEGRAM_BOT_TOKEN") do
      nil -> raise "TELEGRAM_BOT_TOKEN is required"
      token -> token
    end
  end

  def telegram_chat_id do
    case System.get_env("TELEGRAM_CHAT_ID") do
      nil -> raise "TELEGRAM_CHAT_ID is required"
      id -> id
    end
  end

  def crypto_fee, do: env_float("CRYPTO_FEE", 0.001)
  def us_fee_usd, do: env_float("US_FEE_USD", 1.0)
  def b3_fee_brl, do: env_float("B3_FEE_BRL", 5.0)
  def slippage, do: env_float("SLIPPAGE", 0.0005)
  def usd_brl_rate, do: env_float("USD_BRL_RATE", 5.5)

  def max_position_pct, do: env_float("MAX_POSITION_PCT", 0.25)
  def max_positions, do: env_int("MAX_POSITIONS", 10)
  def stop_loss_pct, do: env_float("STOP_LOSS_PCT", 0.05)
  def daily_loss_pct, do: env_float("DAILY_LOSS_PCT", 0.03)

  def gate_min_return, do: env_float("GATE_MIN_RETURN", 2.0)
  def gate_max_drawdown, do: env_float("GATE_MAX_DRAWDOWN", 5.0)
  def gate_min_trades, do: env_int("GATE_MIN_TRADES", 10)
  def gate_days, do: env_int("GATE_DAYS", 30)

  def candidate_cap, do: env_int("CANDIDATE_CAP", 3)
  def start_capital_brl, do: env_float("START_CAPITAL_BRL", 1000.0)
  def watchlist_path, do: env("WATCHLIST_PATH", "config/watchlist.json")

  defp env(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> value
    end
  end

  defp env_float(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.to_float(value)
    end
  end

  defp env_int(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.to_integer(value)
    end
  end
end
