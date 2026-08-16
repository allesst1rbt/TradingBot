# Intraday Upgrade Design

## Context

Working bot in production on Railway: daily cron (21:30 UTC), JSON state on volume, `hermes -z` shell-outs, send-only Telegram. This change converts it to an always-on intraday system. All decisions below were crystallized with the user (14 discovery questions).

## Goals / Non-Goals

**Goals:**
- 5-minute 24/7 analysis runs on 7 symbols with 15m candles and news awareness.
- Precise compact SQLite storage with auto-migration of existing JSON state.
- Telegram slash commands (/status /hour /day /month /force) via long-polling.
- Persistent Hermes link via MCP on localhost only — zero public exposure.

**Non-Goals:**
- No web dashboard, no public HTTP, no webhooks.
- No real broker integration (unchanged).
- No backtesting changes.
- No change to risk gates except the min-hold addition.

## Decisions

### D1: Always-on OTP service with in-app ticker
The bot becomes a long-running app (`restartPolicyType = "ALWAYS"`). A `BotTrader.Scheduler` GenServer ticks every 5 minutes, guarded against overlap (skip tick if previous run still executing). Railway cron is removed. The daily deep run fires at 21:30 UTC from the same scheduler.

**Rejected:** Railway cron every 5 min + separate poller service (two services sharing SQLite = locking headaches); keeping run-and-exit model (Telegram polling needs a live process).

### D2: Model split by run type
`deepseek-v4-flash` for 5-min runs (~60k calls/month, fits 158k limit), `deepseek-v4-pro` for the daily 21:30 deep run. Config: `LLM_MODEL_FLASH`, `LLM_MODEL_PRO` env vars with defaults.

**Rejected:** v4-pro everywhere (hits Go cap in ~8 days); flash-only (loses deep analysis).

### D3: 15-minute candle window
Yahoo provider gains `interval` param (`15m`, range `1d`); CoinGecko's granular hourly data is bucketed to 15m. Candles stay normalized, nil-dropped, and the pipeline refuses to run on an empty window.

**Rejected:** 5m windows (noisier, more fetches); 30m+ (slower reaction).

### D4: News via Hermes web tool, one per run + trigger
Each 5-min run asks Hermes (through MCP) for ONE compact market-wide news note covering the watchlist; when a symbol's 15m move exceeds the volatility threshold (default ±2%), the run requests a deeper per-symbol news search for that symbol. News text lands in the DB `news` table and in the rolling summary.

**Rejected:** per-symbol search every run (rate-limit/too slow); no news (user explicitly wants closed-market news capture).

### D5: SQLite via Ecto/Exqlite
`BotTrader.Repo` (exqlite adapter) with tables: `runs` (id, started_at, finished_at, kind), `signals` (run_id, symbol, action, confidence, model, price), `trades` (from portfolio), `snapshots` (equity/cash per run), `news` (run_id, symbol nullable, trigger nullable, text). Store module supersedes `BotTrader.State` for runtime persistence. `BotTrader.Migration` on first boot imports legacy JSON (portfolio/trades/snapshots) into SQLite, then renames the JSON files to `*.json.archived`.

**Rejected:** Postgres (new paid service); JSON+compaction (user asked for a DB).

### D6: Compact LLM context
`BotTrader.Research.build_prompt/2` gains a compact mode: rolling 24h summary (last signal, position, news notes, equity) built from DB aggregates instead of raw history. Prompt size stays roughly constant regardless of run count.

### D7: Telegram polling + command dispatch
`BotTrader.Telegram.Poller` runs a `getUpdates` long-poll loop (offset persisted in DB). `/status` → current equity, positions, last run age; `/hour` → equity delta + trades over last 60 min; `/day` → daily diary (day aggregates); `/month` → monthly diary (30-day daily rows + gate countdown); `/force` → triggers one standard run immediately (Scheduler handles it; concurrent forces collapse to one pending run). No public URL anywhere.

**Rejected:** webhook (exposes public HTTPS endpoint — conflicts with "nothing exposed").

### D8: Hermes MCP child process, localhost only
`BotTrader.HermesMCP.Supervisor` starts Hermes in MCP server mode (`hermes mcp --stdio` wrapped over a local TCP bridge or `hermes mcp` http mode bound to 127.0.0.1) as a child of the app. `BotTrader.HermesMCP.Client` implements the MCP JSON-RPC initialize/tools/list/tools/call cycle with the analysis tool. All traffic stays on loopback; the container exposes no ports. Health: ping on each run; on failure, restart child once per run, then fall back to marking the run degraded (no crash).

**Rejected:** separate Railway service (two services to maintain); `hermes -z` (288 shell-outs/day = cold starts; removed).

### D9: Min-hold 15 minutes
`BotTrader.Risk.precheck/3` gains a check: reversal orders (SELL/CLOSE) for a position opened less than 15 minutes ago are rejected with `{:error, :min_hold}`. Stop-loss closes bypass the check. Trades carry `opened_at`.

### D10: Run overlap and backpressure
Ticker skips when a run is executing. `/force` sets a pending flag if one is running (runs after current completes). Every run writes a `runs` row regardless of outcome (kind: `standard` | `deep` | `forced`).

## Risks / Trade-offs

- [Go plan rate limits] → Flash budget 158k/month vs ~60k usage; 5-hour cap 31k requests; guardrail: `LLM_CALL_BUDGET_PER_RUN` (default 10 calls) and Telegram alert if the daily call count exceeds 2,400.
- [MCP protocol maturity] → Client implements only initialize/tools/list/tools/call; single tool ("analyze"); anything else = degraded run + alert.
- [Hermes child crash] → Supervisor restart strategy `:one_for_one`, max 1 restart/run, then degraded.
- [SQLite lock contention] → Single writer (the OTP app); WAL mode; all queries via Repo.
- [Fee drag from 5-min churn] → Min-hold 15 min + confidence gate 0.6 (existing).
- [Telegram polling cost] → 25s long-poll, negligible traffic.

## Migration Plan

1. Deploy new image (always-on). On first boot: legacy JSON detected → imported into SQLite → JSON archived (`portfolio.json.archived`).
2. Rollback: the archived JSON files remain; revert image + re-enable old `mix bot.daily` path (config flag `LEGACY_JSON_BOOT=1` documented in README).
3. No manual steps required.

## Open Questions

None — all crystallized (14 discovery answers). Env vars documented in README.
