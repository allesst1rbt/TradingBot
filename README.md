# BotTrader

Autonomous swing trading bot (Elixir/OTP). Daily pipeline: fetches market data for BR stocks, US stocks, and crypto, asks DeepSeek v4 pro for a trading signal per symbol, executes paper trades with fees/slippage and hard risk limits, persists JSON state, and reports to Telegram (per-transaction announcements + daily digest). After 30 days an evaluation gate emits a go/no-go verdict (return ≥ 2%, max drawdown ≤ 5%, ≥ 10 trades). On PASS the bot stays paper until a broker adapter is attached.

## Commands

```bash
mix bot.daily      # one full pipeline run (used by Railway cron)
mix bot.backtest   # ~90-day indicator-only backtest on the first watchlist symbol
mix test           # test suite
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DEEPSEEK_API_KEY` | — (required) | API key for the OpenAI-compatible endpoint |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com/v1` | Base URL (may point to the opencode-go endpoint) |
| `DEEPSEEK_MODEL` | `deepseek-v4-pro` | Model name |
| `TELEGRAM_BOT_TOKEN` | — (required) | Telegram bot token |
| `TELEGRAM_CHAT_ID` | — (required) | Chat id receiving announcements |
| `BOT_STATE_DIR` | `./data` | State directory (Railway: `/data`) |
| `WATCHLIST_PATH` | `config/watchlist.json` | Seed watchlist file |
| `CRYPTO_FEE` | `0.001` | Crypto fee rate (0.1%) |
| `US_FEE_USD` | `1.0` | US stock flat fee (USD) |
| `B3_FEE_BRL` | `5.0` | B3 stock flat fee (BRL) |
| `SLIPPAGE` | `0.0005` | Slippage (0.05%) |
| `USD_BRL_RATE` | `5.5` | USD→BRL conversion rate |
| `MAX_POSITION_PCT` | `0.25` | Max allocation per position |
| `MAX_POSITIONS` | `6` | Max concurrent positions |
| `STOP_LOSS_PCT` | `0.05` | Stop-loss threshold |
| `DAILY_LOSS_PCT` | `0.03` | Daily loss limit (blocks new buys) |
| `LLM_CONFIDENCE_THRESHOLD` | `0.6` | Min confidence for BUY/SELL |
| `START_CAPITAL_BRL` | `1000.0` | Paper capital |
| `GATE_MIN_RETURN` | `2.0` | Gate: min return % |
| `GATE_MAX_DRAWDOWN` | `5.0` | Gate: max drawdown % |
| `GATE_MIN_TRADES` | `10` | Gate: min trade count |
| `GATE_DAYS` | `30` | Gate: evaluation window in days |
| `CANDIDATE_CAP` | `3` | Max new LLM candidates per day |
| `YAHOO_BASE_URL` | `https://query1.finance.yahoo.com` | Yahoo chart API base |
| `COINGECKO_BASE_URL` | `https://api.coingecko.com` | CoinGecko API base |

## Railway Deployment

1. Create a Railway project and deploy this repo (Nixpacks auto-detects Elixir; `railway.toml` sets `mix bot.daily` with cron `30 21 * * *` UTC = 18:30 BRT, after B3 and US closes).
2. Attach a volume at `/data` (service → Settings → Volumes, or `railway volume add -m /data`).
3. Set the env vars above as service variables (`DEEPSEEK_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` at minimum; `BOT_STATE_DIR=/data`).
4. Verify with `MIX_ENV=prod mix compile` locally.
5. The cron task must exit when done — `mix bot.daily` returns after the run.
