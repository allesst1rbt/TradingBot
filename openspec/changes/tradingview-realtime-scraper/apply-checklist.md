# TradingView Realtime Scraper Apply Checklist

**Change:** `tradingview-realtime-scraper`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/tradingview-realtime-scraper/`
**Implementation plan:** `openspec/changes/tradingview-realtime-scraper/tasks.md`
**Status:** planned

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Snapshot schema and Store

- [x] Complete
- **Acceptance behavior:** A normalized TradingView snapshot persists with provenance/stale fields; scraper cursor advances and wraps; retention query returns compact recent history.
- **RED test:** `test/bot_trader/tradingview_store_test.exs` — `"persists normalized snapshot"`, `"advances batch cursor"`, `"retains latest compact history"`
- **RED command:** `mix test test/bot_trader/tradingview_store_test.exs`
- **Expected RED:** V5 tables/schemas undefined.
- **GREEN scope:** `release_v5.ex`, snapshot/cursor schemas, Store functions.
- **GREEN command:** `mix test test/bot_trader/tradingview_store_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** typed schema and compact query API, no raw payload storage.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.3; plan N/A
- **Atomic commit:** `feat: add tradingview snapshot store yarr`
- **Evidence:** `<filled by /apply>`

### 2. Playwright scraper

- [x] Complete
- **Acceptance behavior:** A captured public TradingView fixture normalizes into the stable snapshot schema; blocked/missing pages produce stale/error results without aborting the batch; browser concurrency never exceeds 4.
- **RED test:** `test/bot_trader/tradingview_normalizer_test.exs` — `"normalizes market and technical fixture"`, `"missing fields mark stale"`; `test/bot_trader/tradingview_browser_test.exs` — `"failed page does not abort batch"`
- **RED command:** `mix test test/bot_trader/tradingview_normalizer_test.exs test/bot_trader/tradingview_browser_test.exs`
- **Expected RED:** TradingView modules undefined.
- **GREEN scope:** `lib/bot_trader/trading_view/browser.ex`, `normalizer.ex`, selector module, Dockerfile Playwright dependencies.
- **GREEN command:** `mix test test/bot_trader/tradingview_normalizer_test.exs test/bot_trader/tradingview_browser_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** selectors separate from normalization; browser lifecycle has one owner.
- **Structural validation:** Docker image builds with Playwright and exposes no browser port.
- **Source checkboxes:** OpenSpec 2.1–2.4; plan N/A
- **Atomic commit:** `feat: add bounded tradingview playwright scraper yarr`
- **Evidence:** `<filled by /apply>`

### 3. Round-robin universe

- [x] Complete
- **Acceptance behavior:** Each five-minute tick scrapes one persisted batch, advances the cursor, wraps after the final batch, retains stale snapshots, and does not duplicate a batch before a cycle completes.
- **RED test:** `test/bot_trader/tradingview_scheduler_test.exs` — `"advances round robin cursor"`, `"wraps after final batch"`, `"retains stale snapshot"`
- **RED command:** `mix test test/bot_trader/tradingview_scheduler_test.exs`
- **Expected RED:** scraper scheduler undefined.
- **GREEN scope:** scraper scheduler integration, Config batch size/interval, stale fallback.
- **GREEN command:** `mix test test/bot_trader/tradingview_scheduler_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** cursor state is persisted through Store; scheduler timing injectable.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.3; plan N/A
- **Atomic commit:** `feat: add round-robin tradingview universe scraping yarr`
- **Evidence:** `<filled by /apply>`

### 4. Provider + LLM integration

- [ ] Complete
- **Acceptance behavior:** TradingView data is primary, Yahoo fallback is marked; 600 snapshots produce at most 10 LLM analyses; prompts contain structured fields and current position context.
- **RED test:** `test/bot_trader/tradingview_provider_test.exs` — `"uses yahoo fallback"`; `test/bot_trader/tradingview_reasoning_test.exs` — `"shortlist capped at ten"`, `"prompt contains structured fields"`
- **RED command:** `mix test test/bot_trader/tradingview_provider_test.exs test/bot_trader/tradingview_reasoning_test.exs`
- **Expected RED:** coordinator/shortlist functions undefined.
- **GREEN scope:** provider coordinator, deterministic scorer, prompt builder, signal pipeline source/provenance.
- **GREEN command:** `mix test test/bot_trader/tradingview_provider_test.exs test/bot_trader/tradingview_reasoning_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** provider selection and scoring are pure/testable; LLM only receives normalized data.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.4; plan N/A
- **Atomic commit:** `feat: reason over top tradingview market candidates yarr`
- **Evidence:** `<filled by /apply>`

### 5. Railway rollout

- [x] Complete
- **Acceptance behavior:** Railway image contains Playwright, no public browser endpoint, env vars documented, shadow-mode deployment completes, and TradingView primary can be enabled by configuration.
- **RED test:** N/A (deployment/structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** Dockerfile, railway config, README, rollout flags.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** provider rollback to Yahoo is one env change; no secrets committed.
- **Structural validation:** Railway deploy succeeds; no browser port published.
- **Source checkboxes:** OpenSpec 5.1–5.3; plan N/A
- **Atomic commit:** `chore: deploy tradingview scraper in shadow mode yarr`
- **Evidence:** `<filled by /apply>`

## Completion Gate

- [ ] Every item has passing validation evidence
- [ ] OpenSpec task checkboxes synchronized
- [ ] Regression suite passes
- [ ] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [ ] No unrelated files
