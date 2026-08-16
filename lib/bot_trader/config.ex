defmodule BotTrader.Config do
  @moduledoc """
  Environment-driven configuration. Every value has a default so local
  runs work without any env vars set (except secrets, which fail loudly).
  """

  def state_dir, do: env("BOT_STATE_DIR", "./data")

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
  def max_positions, do: env_int("MAX_POSITIONS", 6)
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
