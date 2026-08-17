# Intraday Upgrade Proposal

## Why

The bot currently runs once daily on daily candles with JSON file state and a `hermes -z` shell-out per symbol. The user wants a 5-minute 24/7 cadence (news captured even while markets are closed, advantage when they reopen), precise compact storage in a real database, Telegram slash commands for monitoring (/status, /hour, /day, /month) and manual triggering (/force), and a persistent Hermes link over MCP that exposes nothing publicly.

## What Changes

- **Scheduling**: Railway cron is retired; the bot becomes an always-on OTP service (restartPolicy ALWAYS) with an in-app 5-minute ticker GenServer.
- **Cadence**: Runs every 5 minutes, 24/7, on all 7 watchlist symbols, using 15-minute intraday candles.
- **Models**: 5-min runs use `deepseek-v4-flash` (fits Go subscription limits ~60k calls/month); the daily 21:30 UTC deep run uses `deepseek-v4-pro`.
- **News**: one compact market-wide news lookup per run via Hermes web tool, plus deeper per-symbol searches when a volatility trigger fires.
- **Storage**: SQLite via Ecto + Exqlite on the `/data` volume; compact typed rows for runs, signals, trades, snapshots, news. On first boot, existing JSON state (portfolio/trades/snapshots) is auto-migrated and archived.
- **LLM context**: prompts carry a rolling 24h compact summary instead of raw history.
- **Commands**: Telegram long-polling loop handles `/status`, `/hour`, `/day`, `/month`, `/force` (immediate standard run). No public endpoint (polling, not webhook).
- **Hermes MCP**: Hermes runs as a supervised child process in the same container serving MCP over `127.0.0.1` only; the bot calls it per-symbol each run. The `hermes -z` shell-out path is removed. Nothing is exposed externally.
- **Risk**: new 15-minute minimum holding time per position (stop-loss remains exempt); existing gates unchanged.
- **BREAKING**: `LLM_BACKEND=hermes` shell-out adapter (`BotTrader.Hermes.chat/1` via System.cmd) is removed in favor of the MCP client.

## Capabilities

### New Capabilities
- `data-store`: SQLite persistence via Ecto — compact typed schema (runs, signals, trades, snapshots, news), queries for hour/day/month aggregates, boot migration from legacy JSON.
- `hermes-mcp`: supervised Hermes MCP child process bound to localhost, MCP client with per-symbol analysis tool calls, startup/health/restart handling.
- `scheduler`: in-app 5-minute ticker with catch-up protection and run overlap guard, plus the daily 21:30 UTC deep run.
- `telegram-commands`: long-polling receive loop dispatching /status, /hour, /day, /month, /force.

### Modified Capabilities
- `market-data`: intraday 15m interval support (Yahoo `interval=15m`, CoinGecko granular hourly→15m mapping), candles always normalized and nil-dropped.
- `research-analysis`: model split (flash for 5-min, pro for daily deep), 15m-window prompts with rolling 24h summary, per-run market-wide news plus trigger-based deep news.
- `paper-portfolio`: 15-minute minimum hold per position (stops exempt); all other risk limits unchanged.
- `telegram-notifications`: keep per-transaction announcements + digest; digest semantics updated for 5-min cadence (compact, hourly aggregate instead of spam per run).

## Impact

- `lib/bot_trader/*` — runner pipeline reworked around Store + MCP client + scheduler; `state.ex` superseded by Ecto repo (kept only for legacy migration); `hermes.ex` shell-out replaced by `BotTrader.HermesMCP`.
- `mix.exs` — add `ecto_sql`, `exqlite`.
- `railway.toml` — cron removed; startCommand becomes the always-on app; restartPolicy ALWAYS.
- Railway volume: SQLite file + archived JSON on `/data`.
- LLM spend: ~60k flash calls + ~210 pro calls/month — within Go plan limits.
