# Intraday Upgrade Tasks

## 1. Database Foundation

- [ ] 1.1 Add deps `ecto_sql` + `exqlite`; create `BotTrader.Repo` and `BotTrader.Release` migrations (runs, signals, trades, snapshots, news, poller_state)
- [ ] 1.2 Schemas: `Run`, `Signal`, `Trade`, `Snapshot`, `News`, `PollerState` with compact typed fields
- [ ] 1.3 `BotTrader.Store` query API: run lifecycle, aggregates (hourly delta, day diary, month diary), call counter
- [ ] 1.4 `BotTrader.Migration` — import legacy JSON into SQLite, archive files (`.archived`), idempotent
- [ ] 1.5 Test all Store + Migration behavior (RED→GREEN)

## 2. Intraday Market Data

- [ ] 2.1 YahooFinance: interval param (5m/15m/30m/1d) with matching range
- [ ] 2.2 CoinGecko: bucket hourly into 15m candles
- [ ] 2.3 Pipeline treats empty window as `{:error, :no_data}` (no LLM call)
- [ ] 2.4 Test interval param, bucketing, nil-drop, empty-window abort (RED→GREEN)

## 3. MCP Client + Hermes Child

- [ ] 3.1 `BotTrader.HermesMCP.Supervisor` — Hermes MCP child on 127.0.0.1, restart strategy
- [ ] 3.2 `BotTrader.HermesMCP.Client` — JSON-RPC initialize/tools list/tools call, analysis tool invocation
- [ ] 3.3 Remove `BotTrader.Hermes` shell-out module and its tests; wire pipeline to MCP client
- [ ] 3.4 Degraded-run handling + Telegram alert on MCP failure
- [ ] 3.5 Test client protocol with a fake MCP server, supervision, degradation (RED→GREEN)

## 4. Scheduler + Runner Rework

- [ ] 4.1 `BotTrader.Scheduler` GenServer: 5-min tick, overlap skip, forced-run queue (collapse), daily 21:30 UTC deep run
- [ ] 4.2 Runner split by kind: standard/forced (flash, 15m window, news 1/run) vs deep (pro, deeper news)
- [ ] 4.3 Compact rolling 24h summary in prompts
- [ ] 4.4 Call budget guardrail (default 2400/day) + one Telegram alert
- [ ] 4.5 Test tick/overlap/forced/deep/budget behaviors with fake deps (RED→GREEN)

## 5. Telegram Commands

- [ ] 5.1 `BotTrader.Telegram.Poller` — getUpdates loop, offset persisted in DB, command dispatch
- [ ] 5.2 `/status`, `/hour`, `/day`, `/month` handlers using Store aggregates
- [ ] 5.3 `/force` handler (immediate or queued) with ack reply
- [ ] 5.4 Register commands with BotFather API (setMyCommands) on boot
- [ ] 5.5 Test dispatch, aggregate replies, force ack, offset persistence (RED→GREEN)

## 6. Risk Min-Hold

- [ ] 6.1 `BotTrader.Risk`: min-hold 15 min check on reversal orders, stop-loss exempt
- [ ] 6.2 Trades carry `opened_at`
- [ ] 6.3 Test fresh-position rejection, stop-loss exemption, old-position pass (RED→GREEN)

## 7. Notifications Update

- [ ] 7.1 Digest only after deep run; standard runs send nothing except trade announcements
- [ ] 7.2 Run-failure alert with skipped symbols
- [ ] 7.3 Test digest gating and failure alert (RED→GREEN)

## 8. Railway Switch

- [ ] 8.1 `railway.toml`: remove cron schedule; startCommand runs always-on app; restartPolicy ALWAYS
- [ ] 8.2 Dockerfile: keep Hermes; app entrypoint starts supervision tree (mcp child + poller + scheduler)
- [ ] 8.3 README: new env vars (LLM_MODEL_FLASH, LLM_MODEL_PRO, VOLATILITY_THRESHOLD, LLM_CALL_BUDGET_PER_RUN, MIN_HOLD_MINUTES), commands list, rollback note
- [ ] 8.4 Validate prod build `MIX_ENV=prod mix compile`
