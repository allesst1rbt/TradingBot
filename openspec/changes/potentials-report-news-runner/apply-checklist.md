# Potentials Report + News Runner Apply Checklist

**Change:** `potentials-report-news-runner`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/potentials-report-news-runner/`
**Implementation plan:** `openspec/changes/potentials-report-news-runner/tasks.md`
**Status:** planned

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Storage + potentials report

- [x] Complete
- **Acceptance behavior:** V6 `news_runner` table; `NewsStore` dedups by headline hash, reads latest, prunes to 50/symbol; `Potentials.Report.build/1` formats one compact line per valid screened symbol.
- **RED test:** `test/bot_trader/news_store_test.exs` — `"dedup by hash"`, `"prune keeps latest fifty"`; `test/bot_trader/potentials_report_test.exs` — `"formats one line per valid symbol"`, `"excludes stale symbols"`
- **RED command:** `mix test test/bot_trader/news_store_test.exs test/bot_trader/potentials_report_test.exs`
- **Expected RED:** NewsStore/Potentials.Report undefined; V6 missing.
- **GREEN scope:** `release_v6.ex`, `news_store.ex`, `potentials/report.ex`, migration wiring (application/test_helper).
- **GREEN command:** `mix test test/bot_trader/news_store_test.exs test/bot_trader/potentials_report_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** news insertion/query isolated in NewsStore; report formatting pure.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.4; plan N/A
- **Atomic commit:** `feat: add news storage and potentials report yarr`
- **Evidence:** `<filled by /apply>`

### 2. TradingView news extraction

- [x] Complete
- **Acceptance behavior:** Playwright page extraction includes headline/source/timestamp lists; missing news is empty-on-failure without aborting the batch.
- **RED test:** `test/bot_trader/tradingview_news_test.exs` — `"extracts headlines from fixture"`, `"empty on missing news"`
- **RED command:** `mix test test/bot_trader/tradingview_news_test.exs`
- **Expected RED:** news extraction functions undefined.
- **GREEN scope:** extend `priv/tradingview_scraper.mjs` and browser normalizer for news fields.
- **GREEN command:** `mix test test/bot_trader/tradingview_news_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** news parsing separate from price/technical parsing.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.2; plan N/A
- **Atomic commit:** `feat: extract tradingview page news yarr`
- **Evidence:** `<filled by /apply>`

### 3. NewsRunner GenServer

- [x] Complete
- **Acceptance behavior:** 5-min tick loads open positions, fetches news, dedups, classifies sentiment in one LLM batch (neutral fallback), alerts only on negative headline or signal change, stores re-analysis signal with source `news`.
- **RED test:** `test/bot_trader/news_runner_test.exs` — `"tick processes open positions"`, `"duplicate headline skipped"`, `"sentiment neutral fallback"`, `"negative headline alerts only"`, `"re-analysis signal source news"`
- **RED command:** `mix test test/bot_trader/news_runner_test.exs`
- **Expected RED:** NewsRunner undefined.
- **GREEN scope:** `news_runner.ex` GenServer, `news_store.ex` helpers, LLM batch sentiment, risk alert via Telegram, re-analysis through existing LLM path.
- **GREEN command:** `mix test test/bot_trader/news_runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** tick orchestration thin; dedup/sentiment/alert as pure helpers.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.5; plan N/A
- **Atomic commit:** `feat: add news runner with sentiment and risk alerts yarr`
- **Evidence:** `<filled by /apply>`

### 4. Potentials report cycle wiring

- [ ] Complete
- **Acceptance behavior:** Scraper cursor wrap sends exactly one Telegram potentials report; mid-cycle ticks send none.
- **RED test:** `test/bot_trader/potentials_report_test.exs` — `"wrap triggers one report"`, `"mid-cycle no report"`
- **RED command:** `mix test test/bot_trader/potentials_report_test.exs`
- **Expected RED:** wrap detection absent.
- **GREEN scope:** scraper scheduler wrap callback → Telegram report; Config `POTENTIALS_REPORT_ENABLED`.
- **GREEN command:** `mix test test/bot_trader/potentials_report_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** wrap detection injected/testable.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.2; plan N/A
- **Atomic commit:** `feat: send potentials report once per cycle yarr`
- **Evidence:** `<filled by /apply>`

### 5. Railway rollout

- [ ] Complete
- **Acceptance behavior:** NewsRunner supervised in production; README documents env vars; deploy succeeds and a production cycle persists news rows and emits the potentials report.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** application supervision, README, rollout env.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** env names match Config; no secrets committed.
- **Structural validation:** Railway deploy succeeds.
- **Source checkboxes:** OpenSpec 5.1–5.2; plan N/A
- **Atomic commit:** `chore: deploy news runner and potentials report yarr`
- **Evidence:** `<filled by /apply>`

## Completion Gate

- [ ] Every item has passing validation evidence
- [ ] OpenSpec task checkboxes synchronized
- [ ] Regression suite passes
- [ ] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [ ] No unrelated files
