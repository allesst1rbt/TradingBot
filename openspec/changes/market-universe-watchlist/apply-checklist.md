# Market Universe Watchlist Apply Checklist

**Change:** `market-universe-watchlist`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/market-universe-watchlist/`
**Implementation plan:** `openspec/changes/market-universe-watchlist/tasks.md`
**Status:** planned

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Watchlist storage (migration V2 + schema + Store)

- [ ] Complete
- **Acceptance behavior:** `watchlist` table exists; `seed_watchlist([{symbol, asset_class}])` inserts source=seed only when empty (idempotent); `add_to_watchlist("NEW","stock-us")` inserts source=candidate, rejects duplicates; `get_watchlist` returns all rows in insertion order.
- **RED test:** `test/bot_trader/store_test.exs` — `"watchlist seed only when empty"`, `"watchlist add and read back"`, `"watchlist duplicate rejected"`
- **RED command:** `mix test test/bot_trader/store_test.exs`
- **Expected RED:** `watchlist` table missing (`no such table`).
- **GREEN scope:** `lib/bot_trader/release.ex` new `BotTrader.Release.V2` migration (`change/0` creates `watchlist`); `BotTrader.WatchlistEntry` schema; Store functions; wire V2 migrate in `application.ex` + `TestRepoBoot`.
- **GREEN command:** `mix test test/bot_trader/store_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** seed uses `insert_all` with `:conflict_target` dedup; one source atom normalized to string.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.4; plan N/A
- **Atomic commit:** `feat: add persisted watchlist table with seed and grow yarr`
- **Evidence:** `<filled by /apply>`

### 2. Batch quotes

- [ ] Complete
- **Acceptance behavior:** `YahooFinance.quotes/2` issues one request per chunk (default 50) to the v7 quote endpoint, returns normalized `{symbol, price, day_change_pct, volume}` entries, drops symbols absent from the response.
- **RED test:** `test/bot_trader/market_data_test.exs` — `"chunked quote fetch"`, `"missing symbols dropped"`
- **RED command:** `mix test test/bot_trader/market_data_test.exs`
- **Expected RED:** `YahooFinance.quotes/2` undefined.
- **GREEN scope:** `lib/bot_trader/market_data/yahoo_finance.ex` `quotes/2` (chunk via `Enum.chunk_every`, normalize `quoteResponse.result`, nil-safe day_change/volume), Config `universe_quote_chunk/0`.
- **GREEN command:** `mix test test/bot_trader/market_data_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** normalization is a pure `to_quote/1`; chunking separate from HTTP.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.2; plan N/A
- **Atomic commit:** `feat: add chunked batch quotes to market data yarr`
- **Evidence:** `<filled by /apply>`

### 3. Universe module

- [ ] Complete
- **Acceptance behavior:** `Universe.load_universe()` parses the static file (≥500 entries, `stock-br`/`stock-us`); `pick_candidate(quotes, watchlist)` scores by `abs(day_change_pct)` + volume bonus, skips watchlist symbols, returns `{:ok, entry}` or `:none`; `scan_and_add` adds one candidate to Store, non-fatal on failure.
- **RED test:** `test/bot_trader/universe_test.exs` — `"loads universe with both asset classes"`, `"picks highest mover not in watchlist"`, `"returns none when all in watchlist"`, `"scan and add grows store"`, `"scan failure non-fatal"`
- **RED command:** `mix test test/bot_trader/universe_test.exs`
- **Expected RED:** `BotTrader.Universe` undefined.
- **GREEN scope:** `lib/bot_trader/universe.ex` (load/1, pick_candidate/2, scan_and_add/0 with injectable quotes fun + path), Config envs.
- **GREEN command:** `mix test test/bot_trader/universe_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** `pick_candidate` is a pure function of (quotes, watchlist) — no I/O.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.4; plan N/A
- **Atomic commit:** `feat: add universe module with rules-based candidate pick yarr`
- **Evidence:** `<filled by /apply>`

### 4. Runner integration

- [ ] Complete
- **Acceptance behavior:** Runner reads the watchlist from Store (seeding from legacy config file when empty; `deps[:watchlist]` still overrides); every run invokes the universe scan once and the watchlist grows by one; scan failure doesn't fail the run.
- **RED test:** `test/bot_trader/runner_test.exs` — `"watchlist from store grows by one per run"`, `"scan failure non-fatal"`
- **RED command:** `mix test test/bot_trader/runner_test.exs`
- **Expected RED:** runner still reads static watchlist file; growth assertion fails.
- **GREEN scope:** `lib/bot_trader/runner.ex` `load_watchlist` (Store-based w/ seed fallback), `universe_fun` dep + call after news, Config `universe_scan_enabled/0`.
- **GREEN command:** `mix test test/bot_trader/runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** universe scan isolated in one step; watchlist normalization reused for seed and store reads.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.3; plan N/A
- **Atomic commit:** `feat: grow watchlist from market universe each run yarr`
- **Evidence:** `<filled by /apply>`

### 5. Deploy config

- [ ] Complete
- **Acceptance behavior:** `config/market_universe.json` present (≥500 entries); Config envs documented; `MIX_ENV=prod mix compile` exits 0; deploy completes and a run adds a candidate.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** `config/market_universe.json`, Config functions, README env additions.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** universe file schema matches `load_universe/1`.
- **Structural validation:** toml parses; prod compile exits 0.
- **Source checkboxes:** OpenSpec 5.1–5.3; plan N/A
- **Atomic commit:** `chore: add market universe list and deploy config yarr`
- **Evidence:** `<filled by /apply>`

## Completion Gate

- [ ] Every item has passing validation evidence
- [ ] OpenSpec task checkboxes synchronized
- [ ] Regression suite passes
- [ ] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [ ] No unrelated files
