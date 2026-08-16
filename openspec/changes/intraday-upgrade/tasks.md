# Intraday Upgrade Tasks

## 1. Database Foundation

- [x] 1.1 Add deps `ecto_sql` + `exqlite`; create `BotTrader.Repo` and `BotTrader.Release` migrations (runs, signals, trades, snapshots, news, poller_state)
- [x] 1.2 Schemas: `Run`, `Signal`, `Trade`, `Snapshot`, `News`, `PollerState` with compact typed fields
- [x] 1.3 `BotTrader.Store` query API: run lifecycle, aggregates (hourly delta, day diary, month diary), call counter
- [x] 1.4 `BotTrader.Migration` — import legacy JSON into SQLite, archive files (`.archived`), idempotent
- [x] 1.5 Test all Store + Migration behavior (RED→GREEN)

## 2. Intraday Market Data

- [x] 2.1 YahooFinance: interval param (5m/15m/30m/1d) with matching range
- [x] 2.2 CoinGecko: bucket hourly into 15m candles
- [x] 2.3 Pipeline treats empty window as `{:error, :no_data}` (no LLM call)
- [x] 2.4 Test interval param, bucketing, nil-drop, empty-window abort (RED→GREEN)

## 3. MCP Client + Hermes Child

- [x] 3.1 `BotTrader.HermesMCP.Supervisor` — Hermes MCP child on 127.0.0.1, restart strategy
- [x] 3.2 `BotTrader.HermesMCP.Client` — JSON-RPC initialize/tools list/tools call, analysis tool invocation
- [x] 3.3 Remove `BotTrader.Hermes` shell-out module and its tests; wire pipeline to MCP client
- [x] 3.4 Degraded-run handling + Telegram alert on MCP failure
- [x] 3.5 Test client protocol with a fake MCP server, supervision, degradation (RED→GREEN)

## 4. Scheduler + Runner Rework

- [x] 4.1 `BotTrader.Scheduler` GenServer: 5-min tick, overlap skip, forced-run queue (collapse), daily 21:30 UTC deep run
- [x] 4.2 Runner split by kind: standard/forced (flash, 15m window, news 1/run) vs deep (pro, deeper news)
- [x] 4.3 Compact rolling 24h summary in prompts
- [x] 4.4 Call budget guardrail (default 2400/day) + one Telegram alert
- [x] 4.5 Test tick/overlap/forced/deep/budget behaviors with fake deps (RED→GREEN)

## 5. Telegram Commands

- [x] 5.1 `BotTrader.Telegram.Poller` — getUpdates loop, offset persisted in DB, command dispatch
- [x] 5.2 `/status`, `/hour`, `/day`, `/month` handlers using Store aggregates
- [x] 5.3 `/force` handler (immediate or queued) with ack reply
- [x] 5.4 Register commands with BotFather API (setMyCommands) on boot
- [x] 5.5 Test dispatch, aggregate replies, force ack, offset persistence (RED→GREEN)

## 6. Risk Min-Hold

- [x] 6.1 `BotTrader.Risk`: min-hold 15 min check on reversal orders, stop-loss exempt
- [x] 6.2 Trades carry `opened_at`
- [x] 6.3 Test fresh-position rejection, stop-loss exemption, old-position pass (RED→GREEN)

## 7. Notifications Update

- [x] 7.1 Digest only after deep run; standard runs send nothing except trade announcements
- [x] 7.2 Run-failure alert with skipped symbols
- [x] 7.3 Test digest gating and failure alert (RED→GREEN)

## 8. Railway Switch

- [x] 8.1 `railway.toml`: remove cron schedule; startCommand runs always-on app; restartPolicy ALWAYS
- [x] 8.2 Dockerfile: keep Hermes; app entrypoint starts supervision tree (mcp child + poller + scheduler)
- [x] 8.3 README: new env vars (LLM_MODEL_FLASH, LLM_MODEL_PRO, VOLATILITY_THRESHOLD, LLM_CALL_BUDGET_PER_RUN, MIN_HOLD_MINUTES), commands list, rollback note
- [x] 8.4 Validate prod build `MIX_ENV=prod mix compile`
