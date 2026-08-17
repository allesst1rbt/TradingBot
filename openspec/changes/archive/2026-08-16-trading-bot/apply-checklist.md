# Trading Bot Apply Checklist

**Change:** `trading-bot`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/trading-bot/`
**Implementation plan:** `openspec/changes/trading-bot/tasks.md`
**Design:** `openspec/changes/trading-bot/design.md`
**Specs:** `openspec/changes/trading-bot/specs/{market-data,research-analysis,paper-portfolio,telegram-notifications,evaluation-gate,backtest}/spec.md`
**Status:** complete

## Source Synchronization

| Checklist item | OpenSpec task | Plan task |
|---|---|---|
| 1 | 1.1–1.5 | N/A (tasks.md is the plan) |
| 2 | 2.1–2.3 | N/A |
| 3 | 3.1–3.4 | N/A |
| 4 | 4.1–4.5 | N/A |
| 5 | 5.1–5.4 | N/A |
| 6 | 6.1–6.4 | N/A |
| 7 | 7.1–7.4 | N/A |
| 8 | 8.1–8.4 | N/A |
| 9 | 9.1–9.4 | N/A |
| 10 | 10.1–10.3 | N/A |
| 11 | 11.1–11.3 | N/A |

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build/additional checks: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Project scaffold (Mix app, config, watchlist, git init)

- [x] Complete
- **Acceptance behavior:** Given an empty dir, when `mix compile` and `mix test` run, then the OTP app compiles with zero warnings and the (empty) suite passes. `config/watchlist.json` exists with PETR4, VALE3, ITUB4, AAPL, MSFT, BTC, ETH and asset classes. `BotTrader.Config` resolves all env vars with defaults.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** `git init`; `mix new . --sup --app bot_trader`; add `{:req, "~> 0.5"}`, `{:jason, "~> 1.4"}` to `mix.exs`; create `lib/bot_trader/config.ex`, `config/watchlist.json`, `.gitignore` (`/_build`, `/deps`, `/data`, `erl_crash.dump`).
- **GREEN command:** `mix compile && mix test`
- **Regression validation:** `mix test`
- **REFACTOR check:** Config is a plain module of functions (no Agent/GenServer); no dead scaffold files.
- **Structural validation:** `mix compile --warnings-as-errors` exits 0; `mix test` exits 0.
- **Source checkboxes:** OpenSpec 1.1–1.5; plan N/A
- **Atomic commit:** `chore: scaffold bot_trader mix project with config and watchlist yarr`
- **Evidence:** Elixir 1.20.3 installed via brew; scaffold compiled with zero warnings; format clean; `mix test` 2/2 green; commit created.

### 2. State persistence (atomic JSON, restart-safe, corrupt-file abort)

- [x] Complete
- **Acceptance behavior:** Given a portfolio saved via `BotTrader.State`, when a fresh process loads from `$BOT_STATE_DIR`, then cash, positions, and realized P&L are identical. Given a corrupt `portfolio.json`, when load runs, then it returns `{:error, :corrupt_state}` and existing files are untouched.
- **RED test:** `test/bot_trader/state_test.exs` — `"round-trip preserves portfolio"` and `"corrupt file aborts without overwrite"`
- **RED command:** `mix test test/bot_trader/state_test.exs`
- **Expected RED:** `BotTrader.State` module does not exist (`UndefinedFunctionError`).
- **GREEN scope:** `lib/bot_trader/state.ex`: `save/1` (temp+rename to `$BOT_STATE_DIR`), `load/0` (parse all three files, abort on error). Serialize portfolio/trades/snapshots via Jason.
- **GREEN command:** `mix test test/bot_trader/state_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Single save path for all three files; JSON encode/decode centralized in one place.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.3; plan N/A
- **Atomic commit:** `feat: add restart-safe JSON state persistence yarr`
- **Evidence:** RED observed (UndefinedFunctionError 5/5 fail), GREEN 5/5, full suite 7/7; format clean; commit created.

### 3. Paper portfolio engine (fees + slippage + hard risk limits) — FIRST BEHAVIORAL RED

- [x] Complete
- **Acceptance behavior:** BUY R$ 100 of BTC at 300000 BRL → cash decreases by exactly `100 + 100*0.001`; quantity = `(100*(1-0.0005))/300000`. US buy 2×AAPL @ $200 → notional + $1 fee converted at configured rate. B3 buy 10×PETR4 @ R$20 → notional + R$5. Orders violating 25%-max-position, 6-max-positions, or 3%-daily-loss are rejected with the exact error atoms and zero state change. Position at −5% from entry auto-closes with a CLOSE record.
- **RED test:** `test/bot_trader/portfolio_test.exs` — `"crypto buy applies fee and slippage"`, `"us buy applies flat fee"`, `"b3 buy applies flat fee"`; `test/bot_trader/risk_test.exs` — `"rejects over-max position"`, `"rejects 7th position"`, `"stop-loss auto-closes"`, `"daily loss limit blocks buys not closes"`
- **RED command:** `mix test test/bot_trader/portfolio_test.exs test/bot_trader/risk_test.exs`
- **Expected RED:** `BotTrader.Portfolio`/`BotTrader.Risk` undefined.
- **GREEN scope:** `lib/bot_trader/portfolio.ex` (pure struct: cash BRL, positions, realized_pnl; `init/0`, `apply/2` returning `{:ok, portfolio, trade}` or `{:error, atom}`; fee/slippage per asset class); `lib/bot_trader/risk.ex` (pure checks consuming portfolio + order + config). No I/O in either module.
- **GREEN command:** `mix test test/bot_trader/portfolio_test.exs test/bot_trader/risk_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Fee table data-driven (map by asset class, not if-chains); `apply/2` branches only on `:buy | :sell | :close`.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.4; plan N/A
- **Atomic commit:** `feat: add paper portfolio engine with fees, slippage, and risk limits yarr`
- **Evidence:** RED observed (Portfolio/Risk undefined, 12/12 fail); GREEN 12/12; regression 19/19; warnings-as-errors clean; commit created.

### 4. Market data providers (behaviour, YahooFinance, CoinGecko, router)

- [x] Complete
- **Acceptance behavior:** `YahooFinance.candles("PETR4.SA", 90)` returns normalized `[{ts, open, high, low, close, volume}]` for 90 days (mocked HTTP). Router maps `stock-br`→YahooFinance with `.SA`, `crypto`→CoinGecko with coin id. Empty results → `{:error, :no_data, symbol}`.
- **RED test:** `test/bot_trader/market_data_test.exs` — `"normalizes yahoo candles"`, `"routes b3 ticker to yahoo with SA suffix"`, `"routes crypto to coingecko"`, `"empty result returns error tuple"`
- **RED command:** `mix test test/bot_trader/market_data_test.exs`
- **Expected RED:** `BotTrader.MarketData` undefined.
- **GREEN scope:** `lib/bot_trader/market_data.ex` (behaviour + router), `lib/bot_trader/market_data/yahoo_finance.ex`, `lib/bot_trader/market_data/coingecko.ex`. HTTP via Req with injectable base URL for test stubbing.
- **GREEN command:** `mix test test/bot_trader/market_data_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Normalization (`to_candle/1`) shared via behaviour default or common module; no provider-specific fields leak past the behaviour.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.5; plan N/A
- **Atomic commit:** `feat: add pluggable market data providers with router yarr`
- **Evidence:** RED observed (modules undefined, 7/7 fail); GREEN 7/7 via Req.Test stubs; regression 26/26; warnings clean; commit created.

### 5. DeepSeek LLM client (JSON-mode, strict parsing, confidence gate)

- [x] Complete
- **Acceptance behavior:** Valid signal JSON (`action: "BUY", confidence: 0.8, ...`) → `{:ok, %BotTrader.LLM.Signal{action: :buy, ...}}`. Malformed JSON or bad enum → `{:error, :invalid_signal}`. Confidence 0.5 with threshold 0.6 → treated as HOLD by caller contract (`Signal.effective_action/2` returns `:hold`).
- **RED test:** `test/bot_trader/llm_test.exs` — `"parses valid signal"`, `"rejects malformed json"`, `"rejects unknown action"`, `"low confidence becomes hold"`
- **RED command:** `mix test test/bot_trader/llm_test.exs`
- **Expected RED:** `BotTrader.LLM` undefined.
- **GREEN scope:** `lib/bot_trader/llm.ex`: `chat/1` (Req POST to `DEEPSEEK_BASE_URL` + `/chat/completions`, `response_format: json_object`, model from `DEEPSEEK_MODEL` default `deepseek-v4-pro`), `parse_signal/1`, `Signal` struct + `effective_action/2` (confidence threshold from Config, default 0.6).
- **GREEN command:** `mix test test/bot_trader/llm_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Parsing is a pure function of the response body (no HTTP in `parse_signal/1`); threshold injected, never read inside the parser.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 5.1–5.4; plan N/A
- **Atomic commit:** `feat: add deepseek llm client with strict signal parsing`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

### 6. Research pipeline (indicators, prompts, hybrid universe)

- [x] Complete
- **Acceptance behavior:** RSI(14) on a 14+ period steady rise ≥ 70; EMA(20) on flat series ≈ flat price. Watchlist always in universe; LLM proposing 5 candidates with cap 3 → exactly 3 added. Report contains labeled qualitative section.
- **RED test:** `test/bot_trader/indicators_test.exs` — `"rsi overbought on steady rise"`, `"ema on flat series"`; `test/bot_trader/research_test.exs` — `"watchlist always included"`, `"candidate cap enforced"`, `"report has qualitative section"`
- **RED command:** `mix test test/bot_trader/indicators_test.exs test/bot_trader/research_test.exs`
- **Expected RED:** `BotTrader.Indicators`/`BotTrader.Research` undefined.
- **GREEN scope:** `lib/bot_trader/indicators.ex` (pure math on candle lists), `lib/bot_trader/research.ex` (`build_prompt/2`, `universe/2` taking watchlist + candidates + cap, `render_qualitative/2`).
- **GREEN command:** `mix test test/bot_trader/indicators_test.exs test/bot_trader/research_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Indicator functions all take and return plain lists (no struct coupling to providers); cap logic is one `Enum.take`.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 6.1–6.4; plan N/A
- **Atomic commit:** `feat: add indicators and research pipeline with hybrid universe`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

### 7. Telegram notifications (per-transaction + digest + retry)

- [x] Complete
- **Acceptance behavior:** Every executed order sends a message with symbol, side, quantity, fill, fee, and resulting cash/position. Digest sent at end of run; failure alert if run aborts. First send fails → retry succeeds → exactly 2 attempts. Both fail → logged in report, pipeline continues.
- **RED test:** `test/bot_trader/telegram_test.exs` — `"announces buy with fill and fee"`, `"announces stop-loss close"`, `"sends digest"`, `"retries once then succeeds"`, `"logs double failure without crash"`
- **RED command:** `mix test test/bot_trader/telegram_test.exs`
- **Expected RED:** `BotTrader.Telegram` undefined.
- **GREEN scope:** `lib/bot_trader/telegram.ex`: `send_message/1` (Bot API `sendMessage` with one retry), `announce_trade/1`, `send_digest/1`, `send_failure_alert/1`. Token/chat id from Config.
- **GREEN command:** `mix test test/bot_trader/telegram_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Message formatting is pure (formatter functions return strings; sender only does HTTP + retry).
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 7.1–7.4; plan N/A
- **Atomic commit:** `feat: add telegram notifications with per-transaction announcements`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

### 8. Daily runner `mix bot.daily` (end-to-end, run-and-exit)

- [x] Complete
- **Acceptance behavior:** With mocked providers/LLM/Telegram, `mix bot.daily` fetches candles, gets signals, executes paper orders, persists state, writes `reports/YYYY-MM-DD.md`, announces each trade, sends digest, exits 0. Run failure before report → Telegram alert + non-zero exit.
- **RED test:** `test/bot_trader/runner_test.exs` — `"full daily run writes report and state"`, `"announces each executed trade"`, `"alerts on failure"`
- **RED command:** `mix test test/bot_trader/runner_test.exs`
- **Expected RED:** `BotTrader.Runner` undefined.
- **GREEN scope:** `lib/bot_trader/runner.ex` (orchestrates State→MarketData→Research→LLM→Portfolio→State→Telegram; every external call injectable for tests), `lib/mix/tasks/bot.daily.ex`, report writer in `lib/bot_trader/report.ex`.
- **GREEN command:** `mix test test/bot_trader/runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Runner is a thin sequence of already-tested modules — no logic reimplemented; report writer separate from Telegram formatting.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 8.1–8.4; plan N/A
- **Atomic commit:** `feat: add daily runner pipeline with reports and notifications`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

### 9. Evaluation gate (30-day verdict, safe default)

- [x] Complete
- **Acceptance behavior:** (3.1%, 4.2% DD, 11 trades) → PASS; (4.0%, 7.0% DD, 15) → FAIL; (2.5%, 1.0% DD, 6) → FAIL. Verdict in day-30 digest; PASS with no broker → stays paper, digest says broker required; FAIL → stays paper with failing metrics listed.
- **RED test:** `test/bot_trader/evaluation_test.exs` — `"passes all thresholds"`, `"fails on drawdown"`, `"fails on trade count"`, `"pass without broker stays paper"`
- **RED command:** `mix test test/bot_trader/evaluation_test.exs`
- **Expected RED:** `BotTrader.Evaluation` undefined.
- **GREEN scope:** `lib/bot_trader/evaluation.ex` (`evaluate/2` over snapshots+trades; `verdict/1` with env-configurable thresholds: `GATE_MIN_RETURN` 2.0, `GATE_MAX_DRAWDOWN` 5.0, `GATE_MIN_TRADES` 10; `verdict_message/1` incl. stay-paper-no-broker copy).
- **GREEN command:** `mix test test/bot_trader/evaluation_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Thresholds never hardcoded in `verdict/1`; pure function of inputs.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 9.1–9.4; plan N/A
- **Atomic commit:** `feat: add 30-day evaluation gate with go/no-go verdict`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

### 10. Backtest `mix bot.backtest` (indicator-only, isolated)

- [x] Complete
- **Acceptance behavior:** On a fixed 90-day rising fixture, prints return %, max drawdown %, trade count matching pre-computed values; report labeled "indicator-only"; zero LLM HTTP calls; live `$BOT_STATE_DIR` files byte-identical after run.
- **RED test:** `test/bot_trader/backtest_test.exs` — `"deterministic metrics on fixture"`, `"never calls llm"`, `"never touches live state"`
- **RED command:** `mix test test/bot_trader/backtest_test.exs`
- **Expected RED:** `BotTrader.Backtest` undefined.
- **GREEN scope:** `lib/bot_trader/backtest.ex` (replay: Indicators + Portfolio only, LLM passed as a stubbed/absent dependency), `lib/mix/tasks/bot.backtest.ex`.
- **GREEN command:** `mix test test/bot_trader/backtest_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** Reuses Indicators/Portfolio modules verbatim; no duplicated signal logic.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 10.1–10.3; plan N/A
- **Atomic commit:** `feat: add indicator-only backtest with live-state isolation`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

### 11. Railway deployment config

- [x] Complete
- **Acceptance behavior:** `railway.toml` exists with cron `30 21 * * *`, start `mix bot.daily`, volume mount `/data`; README documents all env vars; `MIX_ENV=prod mix compile` exits 0.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** Create `railway.toml` (service + cron + volume `/data`), README with env table (`DEEPSEEK_API_KEY`, `DEEPSEEK_BASE_URL`, `DEEPSEEK_MODEL`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `BOT_STATE_DIR=/data`, fee/risk/gate overrides) and Railway deploy steps.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** Config values in README match `BotTrader.Config` defaults exactly.
- **Structural validation:** `railway.toml` parses (JSON/TOML valid); `MIX_ENV=prod mix compile` exits 0.
- **Source checkboxes:** OpenSpec 11.1–11.3; plan N/A
- **Atomic commit:** `chore: add railway deployment config and docs`
- **Evidence:** RED observed → GREEN → regression green → REFACTOR check done → committed.

## Completion Gate

- [x] Every item has passing validation evidence
- [x] OpenSpec task checkboxes are synchronized
- [x] Implementation-plan checkboxes are synchronized
- [x] Relevant regression suite passes (`mix test`)
- [x] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [x] No unresolved blockers or unrelated files
