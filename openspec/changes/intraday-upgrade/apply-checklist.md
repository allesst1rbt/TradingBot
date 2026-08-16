# Intraday Upgrade Apply Checklist

**Change:** `intraday-upgrade`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/intraday-upgrade/`
**Implementation plan:** `openspec/changes/intraday-upgrade/tasks.md`
**Design:** `openspec/changes/intraday-upgrade/design.md`
**Specs:** `openspec/changes/intraday-upgrade/specs/{data-store,hermes-mcp,scheduler,telegram-commands,market-data,research-analysis,paper-portfolio,telegram-notifications}/spec.md`
**Status:** planned

## Source Synchronization

| Checklist item | OpenSpec task | Plan task |
|---|---|---|
| 1 | 1.1–1.5 | N/A (tasks.md is the plan) |
| 2 | 2.1–2.4 | N/A |
| 3 | 3.1–3.5 | N/A |
| 4 | 4.1–4.5 | N/A |
| 5 | 5.1–5.5 | N/A |
| 6 | 6.1–6.3 | N/A |
| 7 | 7.1–7.3 | N/A |
| 8 | 8.1–8.4 | N/A |

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build/additional checks: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Database foundation (Ecto/Exqlite, Store, migration)

- [ ] Complete
- **Acceptance behavior:** Repo starts against `$BOT_STATE_DIR/bot_trader.sqlite3` (WAL). `Store.start_run/2` + `finish_run/2` write `runs` rows with kind; signals/trades/snapshots/news insert with compact typed fields. Boot with legacy `portfolio.json`/`trades.json`/`snapshots.json` imports rows then renames files to `*.archived`; second boot is a no-op. `/hour`-style aggregate returns equity delta + trade count over 60 min; month diary returns 30 daily rows.
- **RED test:** `test/bot_trader/store_test.exs` — `"run lifecycle persists"`, `"hourly delta aggregate"`, `"monthly diary rows"`; `test/bot_trader/migration_test.exs` — `"imports legacy json and archives"`, `"second boot is no-op"`
- **RED command:** `mix test test/bot_trader/store_test.exs test/bot_trader/migration_test.exs`
- **Expected RED:** `BotTrader.Repo` undefined (module load error).
- **GREEN scope:** `mix.exs` deps `{:ecto_sql, "~> 3.13"}`, `{:exqlite, "~> 0.30"}`; `lib/bot_trader/repo.ex`; `lib/bot_trader/release.ex` (migrations `create_runs`, `create_signals`, `create_trades`, `create_snapshots`, `create_news`, `create_poller_state`); schemas `lib/bot_trader/run.ex` etc.; `lib/bot_trader/store.ex`; `lib/bot_trader/migration.ex`. Test Repo uses a tmp dir per test.
- **GREEN command:** `mix test test/bot_trader/store_test.exs test/bot_trader/migration_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Store is the only module touching Repo queries; schemas are plain structs without business logic.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.5; plan N/A
- **Atomic commit:** `feat: add sqlite store with legacy json migration yarr`
- **Evidence:** `<filled by /apply>`

### 2. Intraday market data (interval, bucketing, empty-window abort)

- [ ] Complete
- **Acceptance behavior:** `YahooFinance.candles("PETR4.SA", 1, "15m")` requests `interval=15m&range=1d` and returns normalized candles (nil-dropped). CoinGecko hourly data bucketed into 15m. Empty window → `{:error, :no_data, symbol}` and pipeline skips LLM for that symbol.
- **RED test:** `test/bot_trader/market_data_test.exs` — `"intraday interval param on request"`, `"coingecko buckets hourly into 15m"`, `"empty intraday window returns no_data"` (stubs via `Req.Test`)
- **RED command:** `mix test test/bot_trader/market_data_test.exs`
- **Expected RED:** `candles/3` undefined or interval ignored — stub asserts `interval=15m` fails.
- **GREEN scope:** `lib/bot_trader/market_data/yahoo_finance.ex` (`candles/3` with interval, `range_for_interval/1`: 5m/15m/30m → `1d`, `1d` → `3mo`); `lib/bot_trader/market_data/coingecko.ex` (15m bucketing); `lib/bot_trader/market_data.ex` (behaviour updated); runner respects `{:error, :no_data, _}` before LLM call.
- **GREEN command:** `mix test test/bot_trader/market_data_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Bucketing is a pure function `bucket/2` unit-testable without HTTP.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.4; plan N/A
- **Atomic commit:** `feat: add intraday interval support to market data providers yarr`
- **Evidence:** `<filled by /apply>`

### 3. Hermes MCP child + client (localhost only, no shell-out)

- [ ] Complete
- **Acceptance behavior:** Supervisor starts Hermes MCP child bound to 127.0.0.1; client performs JSON-RPC initialize → tools/list → tools/call per symbol; tool result parsed as signal JSON. Child crash → restarted once per run. MCP unreachable → run completes degraded, symbols skipped, `runs` row written, Telegram alert sent. `BotTrader.Hermes` module removed; no `System.cmd` hermes calls remain.
- **RED test:** `test/bot_trader/hermes_mcp_test.exs` — `"client completes mcp handshake and calls analysis tool"`, `"parses signal from tool result"`, `"mcp failure degrades run with alert"`, `"no shell-out adapter remains"` (fake MCP TCP server on an ephemeral port)
- **RED command:** `mix test test/bot_trader/hermes_mcp_test.exs`
- **Expected RED:** `BotTrader.HermesMCP.Client` undefined.
- **GREEN scope:** `lib/bot_trader/hermes_mcp/client.ex` (JSON-RPC over TCP localhost, configurable port `HERMES_MCP_PORT` default 8787), `lib/bot_trader/hermes_mcp/supervisor.ex` (child spec running `hermes mcp` http mode on 127.0.0.1), delete `lib/bot_trader/hermes.ex` + its test; runner `llm_fun` default replaced by MCP-backed `BotTrader.HermesMCP.analyze/3` (messages → signal json).
- **GREEN command:** `mix test test/bot_trader/hermes_mcp_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Protocol framing (JSON-RPC envelopes) isolated from signal parsing; supervisor child spec data-driven.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.5; plan N/A
- **Atomic commit:** `feat: replace hermes shell-out with internal mcp client yarr`
- **Evidence:** `<filled by /apply>`

### 4. Scheduler + runner rework (tick, kinds, model split, rolling context, budget)

- [ ] Complete
- **Acceptance behavior:** Scheduler ticks every 5 min; overlap skipped; forced runs queue-collapse; 21:30 UTC daily deep run. Standard/forced runs use flash model + 15m window + 1 market-wide news call; deep runs use pro + deeper news. Prompt contains rolling 24h summary; size within 20% regardless of run count. Daily LLM calls > 2400 → one Telegram alert that day.
- **RED test:** `test/bot_trader/scheduler_test.exs` — `"tick triggers standard run"`, `"overlap skipped"`, `"forced run queued during busy"`, `"deep run at 2130 utc"`; `test/bot_trader/runner_test.exs` — `"standard run uses flash model"`, `"deep run uses pro model"`, `"rolling summary keeps prompt size stable"`, `"budget alert sent once"`
- **RED command:** `mix test test/bot_trader/scheduler_test.exs test/bot_trader/runner_test.exs`
- **Expected RED:** `BotTrader.Scheduler` undefined; model split assertions fail.
- **GREEN scope:** `lib/bot_trader/scheduler.ex` (GenServer with `:timer`/`Process.send_after`, tick state, forced flag); runner refactor: `run/2` accepting `kind`; `Config.llm_model_flash/0`, `Config.llm_model_pro/0`, `Config.volatility_threshold/0`, `Config.llm_call_budget_per_run/0`; Store-backed call counter; research prompt compact mode.
- **GREEN command:** `mix test test/bot_trader/scheduler_test.exs test/bot_trader/runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Scheduler owns timing only; runner owns pipeline only; tick interval injectable for tests (no sleeps in tests — use `send/2` ticks).
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.5; plan N/A
- **Atomic commit:** `feat: add 5-minute scheduler with model split and rolling context yarr`
- **Evidence:** `<filled by /apply>`

### 5. Telegram commands (poller, 5 handlers, BotFather menu)

- [ ] Complete
- **Acceptance behavior:** Poller long-polls, persists offset in DB. `/status` → equity/positions/last-run age; `/hour` → 60-min delta + trades; `/day` → today diary; `/month` → 30 daily rows + gate countdown; `/force` → ack + immediate/queued run. Non-command messages ignored. `setMyCommands` called on boot with the 5 commands.
- **RED test:** `test/bot_trader/telegram_poller_test.exs` — `"dispatches /status reply"`, `"/hour returns delta from store"`, `"/month lists 30 rows"`, `"/force acks and triggers"`, `"ignores non-command"`, `"offset persisted across restart"` (fake update payloads, mocked send)
- **RED command:** `mix test test/bot_trader/telegram_poller_test.exs`
- **Expected RED:** `BotTrader.Telegram.Poller` undefined.
- **GREEN scope:** `lib/bot_trader/telegram/poller.ex` (getUpdates loop, offset via Store), `lib/bot_trader/telegram/commands.ex` (dispatch + handlers building replies from Store aggregates), `setMyCommands` on boot, application supervisor adds poller child.
- **GREEN command:** `mix test test/bot_trader/telegram_poller_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Command handlers are pure functions of (state) → reply text; poller only transports.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 5.1–5.5; plan N/A
- **Atomic commit:** `feat: add telegram slash commands via long polling yarr`
- **Evidence:** `<filled by /apply>`

### 6. Min-hold risk check

- [ ] Complete
- **Acceptance behavior:** SELL/CLOSE on position opened <15 min ago → `{:error, :min_hold}`, no state change. Stop-loss close on fresh position executes. Position older than 15 min closes normally. Trades carry `opened_at`.
- **RED test:** `test/bot_trader/risk_test.exs` — `"rejects close of fresh position"`, `"stop-loss bypasses min-hold"`, `"old position closes"`; portfolio test asserts `opened_at` present on BUY trade
- **RED command:** `mix test test/bot_trader/risk_test.exs test/bot_trader/portfolio_test.exs`
- **Expected RED:** min-hold tests fail (`:ok` returned where `{:error, :min_hold}` expected).
- **GREEN scope:** `lib/bot_trader/risk.ex` (`precheck/3` with `now` param + min-hold branch keyed on position.opened_at; stop-loss path skips check), `lib/bot_trader/portfolio.ex` (Position gets `opened_at`; BUY trade record gets `opened_at`), Config `min_hold_minutes/0` default 15.
- **GREEN command:** `mix test test/bot_trader/risk_test.exs test/bot_trader/portfolio_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** `now` injected explicitly — no `DateTime.utc_now` inside risk checks.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 6.1–6.3; plan N/A
- **Atomic commit:** `feat: add 15-minute minimum holding time yarr`
- **Evidence:** `<filled by /apply>`

### 7. Notifications update (digest gating, failure alert)

- [ ] Complete
- **Acceptance behavior:** Digest sent only after deep runs; standard runs send only trade announcements. Run failure (MCP down, corrupt DB) → Telegram alert listing failure + skipped symbols; failure recorded in run row.
- **RED test:** `test/bot_trader/telegram_test.exs` — `"no digest on standard run"`; `test/bot_trader/runner_test.exs` — `"failure alert lists skipped symbols"`
- **RED command:** `mix test test/bot_trader/telegram_test.exs test/bot_trader/runner_test.exs`
- **Expected RED:** digest gating assertion fails (currently digest sent every run); alert test fails.
- **GREEN scope:** runner sends digest only when `kind == :deep`; `BotTrader.Telegram.format_failure_alert/1` extended with symbol list; Store records failure status on run row.
- **GREEN command:** `mix test test/bot_trader/telegram_test.exs test/bot_trader/runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Digest gating is one `if kind == :deep` — no duplication of formatting.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 7.1–7.3; plan N/A
- **Atomic commit:** `feat: gate digests to deep runs and alert on failures yarr`
- **Evidence:** `<filled by /apply>`

### 8. Railway switch (always-on, no cron)

- [ ] Complete
- **Acceptance behavior:** `railway.toml` has no schedule; startCommand runs the OTP app (`mix run --no-halt`); restartPolicy ALWAYS. Dockerfile builds. README documents new env vars and commands. `MIX_ENV=prod mix compile` exits 0.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** `railway.toml` (remove `[deploy.schedule]`, `startCommand = "mix run --no-halt"`, `restartPolicyType = "ALWAYS"`); `lib/bot_trader/application.ex` supervision tree (Scheduler + Poller + HermesMCP child); README env table + command list + rollback note.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** Application children order: HermesMCP before Scheduler/Poller (dependencies documented).
- **Structural validation:** `railway.toml` parses; prod compile exits 0.
- **Source checkboxes:** OpenSpec 8.1–8.4; plan N/A
- **Atomic commit:** `chore: switch railway to always-on service without cron yarr`
- **Evidence:** `<filled by /apply>`

## Completion Gate

- [ ] Every item has passing validation evidence
- [ ] OpenSpec task checkboxes are synchronized
- [ ] Implementation-plan checkboxes are synchronized
- [ ] Relevant regression suite passes (`mix test`)
- [ ] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [ ] No unresolved blockers or unrelated files
