# Universe Mover Trading Apply Checklist

**Change:** `universe-mover-trading`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/universe-mover-trading/`
**Implementation plan:** `openspec/changes/universe-mover-trading/tasks.md`
**Status:** complete

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Mover screen (top_movers + screen_movers + config)

- [x] Complete
- **Acceptance behavior:** `Universe.top_movers(quotes, exclude, n)` returns the top n by `abs(day_change_pct) + volume bonus`, excluding listed symbols; `:none` when none eligible. Config: MOVER_COUNT=5, MAX_MOVER_POSITION_PCT=0.10, MAX_POSITIONS=10, DAILY_CALL_BUDGET=5000.
- **RED test:** `test/bot_trader/universe_test.exs` — `"top movers ranked with exclusions"`, `"no eligible movers returns none"`
- **RED command:** `mix test test/bot_trader/universe_test.exs`
- **Expected RED:** `Universe.top_movers/3` undefined.
- **GREEN scope:** `lib/bot_trader/universe.ex` (`top_movers/3`, `screen_movers/1` with injectable quotes fun), Config additions.
- **GREEN command:** `mix test test/bot_trader/universe_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** scoring shared with pick_candidate; top_movers pure.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.4; plan N/A
- **Atomic commit:** `feat: add top-mover screening to universe yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 2. Rate-disciplined quotes

- [x] Complete
- **Acceptance behavior:** `YahooFinance.quotes/2` chunks at 25 (default) with ≥150ms between chunk requests; a 429 chunk retries once with backoff then is skipped (partial results, no crash).
- **RED test:** `test/bot_trader/market_data_test.exs` — `"rate disciplined chunk timing"`, `"429 partial results no crash"`
- **RED command:** `mix test test/bot_trader/market_data_test.exs`
- **Expected RED:** single chunk of 60 (no chunk timing); 429 raises/fails whole fetch.
- **GREEN scope:** `lib/bot_trader/market_data/yahoo_finance.ex` — chunk/interval/429 handling in `quotes/2` (opts `chunk_size`, `min_interval_ms`).
- **GREEN command:** `mix test test/bot_trader/market_data_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** chunk loop isolated; backoff constant configurable.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.2; plan N/A
- **Atomic commit:** `feat: rate-discipline batch quote fetching yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 3. Mover analysis in runner

- [x] Complete
- **Acceptance behavior:** Runner screens movers when `Config.market_open?` (B3/US weekday windows); deep-dives each mover; mover signals `source: "mover"`, watchlist `source: "watchlist"`; closed markets → no mover analysis, run completes.
- **RED test:** `test/bot_trader/runner_test.exs` — `"mover analysis runs when market open"`, `"mover signal tagged source"`, `"market closed skips movers"`; `test/bot_trader/config_test.exs` (or inline) — `"market open on weekday hours"`, `"closed on weekend"`
- **RED command:** `mix test test/bot_trader/runner_test.exs`
- **Expected RED:** runner never calls mover screen; signals lack source.
- **GREEN scope:** `lib/bot_trader/runner.ex` (mover path after news, `source` in insert_signal), `lib/bot_trader/config.ex` (`market_open?/1`, `mover_count/0`, `mover_source`), signals schema `source` field (part of item 5 migration).
- **GREEN command:** `mix test test/bot_trader/runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** mover path mirrors watchlist analyze; no duplicated prompt logic.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.3; plan N/A
- **Atomic commit:** `feat: analyze top movers with source tagging yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 4. Mover risk sizing

- [x] Complete
- **Acceptance behavior:** `Risk.precheck` limits mover orders (`source: :mover`) to 10% of capital; watchlist orders keep 25%; `MAX_POSITIONS` default 10.
- **RED test:** `test/bot_trader/risk_test.exs` — `"mover buy over 10 percent rejected"`, `"watchlist 25 percent unaffected"`
- **RED command:** `mix test test/bot_trader/risk_test.exs`
- **Expected RED:** mover orders use 25% cap (no 10% rejection).
- **GREEN scope:** `lib/bot_trader/risk.ex` (source-aware cap), Config `max_mover_position_pct/0`, `max_positions/0` default 10.
- **GREEN command:** `mix test test/bot_trader/risk_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** cap selection is one function of order source.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.2; plan N/A
- **Atomic commit:** `feat: enforce tighter sizing for mover positions yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 5. Signals source + deploy

- [x] Complete
- **Acceptance behavior:** migration V4 adds `signals.source` (string, default "watchlist"); README documents movers + new envs; prod compile; deploy.
- **RED test:** N/A (structural) — covered by item 3 tests for behavior.
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** `lib/bot_trader/release_v4.ex` (add `source` to signals), Signal schema field, README env/commands, application/test_helper V4 migration wiring.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** migration consistent with schema.
- **Structural validation:** prod compile exits 0; migration applies on boot.
- **Source checkboxes:** OpenSpec 5.1; plan N/A
- **Atomic commit:** `feat: tag signals with source and deploy mover trading yarr`
- **Evidence:** RED→GREEN→regression green→committed.

## Completion Gate

- [x] Every item has passing validation evidence
- [x] OpenSpec task checkboxes synchronized
- [x] Regression suite passes
- [x] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [x] No unrelated files
