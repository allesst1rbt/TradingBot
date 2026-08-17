# BotTrader

Autonomous intraday trading bot (Elixir/OTP, always-on). Runs every 5 minutes 24/7 on BR stocks, US stocks, and crypto: 15m candles, `deepseek-v4-flash` signals via an internal Hermes MCP link (localhost only), market-wide news each run plus deeper news on volatility triggers, paper trades with fees/slippage and hard risk limits (incl. 15-min min-hold), SQLite history, Telegram announcements and slash commands. Daily 21:30 UTC deep run uses `deepseek-v4-pro` and sends the digest. After 30 days an evaluation gate emits a go/no-go verdict (return ≥ 2%, max drawdown ≤ 5%, ≥ 10 trades); on PASS the bot stays paper until a broker adapter is attached.

## Commands

```bash
mix bot.backtest   # ~90-day indicator-only backtest on the first watchlist symbol
mix test           # test suite
mix run --no-halt  # production entrypoint (scheduler + telegram poller)
```

## Telegram slash commands

- `/status` — equity, positions, last run age
- `/hour` — equity change over the last hour
- `/day` — today's trades, P&L and open positions
- `/week` — last 7 days summary
- `/month` — last 30 days summary
- `/force` — run the pipeline now (queued if a run is executing)
- `/positions [N]` — open positions + paginated trade history

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DEEPSEEK_API_KEY` | — (required) | API key for the OpenAI-compatible endpoint |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com/v1` | Base URL (may point to the opencode-go endpoint) |
| `DEEPSEEK_MODEL` | `deepseek-v4-pro` | Model name (direct backend) |
| `LLM_BACKEND` | `hermes` | `hermes` (MCP) or `direct` (HTTP) |
| `HERMES_MCP_BIN` | `hermes` | Hermes binary for the MCP child |
| `HERMES_MCP_ARGS` | `mcp` | Comma-separated args for the MCP child |
| `LLM_MODEL_FLASH` | `deepseek-v4-flash` | Model for standard/forced runs |
| `LLM_MODEL_PRO` | `deepseek-v4-pro` | Model for the daily deep run |
| `RUN_INTERVAL_MS` | `300000` | Scheduler tick interval |
| `ANALYSIS_INTERVAL` | `15m` | Candle interval |
| `VOLATILITY_THRESHOLD` | `0.02` | 15m move triggering per-symbol news |
| `DAILY_CALL_BUDGET` | `2400` | LLM calls/day before a Telegram alert |
| `MIN_HOLD_MINUTES` | `15` | Minimum holding time per position |
| `DEEP_RUN_HOUR_UTC` | `21` | Deep run hour (UTC) |
| `DEEP_RUN_MINUTE_UTC` | `30` | Deep run minute (UTC) |
| `TELEGRAM_BOT_TOKEN` | — (required) | Telegram bot token |
| `TELEGRAM_CHAT_ID` | — (required) | Chat id receiving announcements |
| `BOT_STATE_DIR` | `./data` | State directory (Railway: `/data`) |
| `WATCHLIST_PATH` | `config/watchlist.json` | Seed watchlist file (first boot only; watchlist persists in SQLite) |
| `UNIVERSE_PATH` | `config/market_universe.json` | Full US+BR market universe for scanning |
| `UNIVERSE_SCAN_ENABLED` | `true` | Adds one candidate to the watchlist each run |
| `UNIVERSE_QUOTE_CHUNK` | `50` | Symbols per batch quote request |
| `UNIVERSE_VOLUME_FLOOR` | `1000000` | Volume threshold for the candidate score bonus |
| `HERMES_MEMORY_PATH` | `/data/hermes_memory.md` | Trade memory file absorbed by Hermes |
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

1. Create a Railway project and deploy this repo (Dockerfile builds Elixir + Hermes; `railway.toml` runs `mix run --no-halt` with restartPolicy ALWAYS).
2. Attach a volume at `/data` (service → Settings → Volumes, or `railway volume add -m /data`).
3. Set the env vars above as service variables (`OPENCODE_GO_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` at minimum; `BOT_STATE_DIR=/data`). The entrypoint seeds `~/.hermes/.env` from `OPENCODE_GO_API_KEY`.
4. Verify with `MIX_ENV=prod mix compile` locally.
5. Rollback: archived JSON (`*.json.archived`) remains in `/data`; redeploy the previous image.
