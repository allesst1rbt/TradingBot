# Universe Mover Trading Design

## Context

Crystallized with the user (13 discovery answers): screen-all + LLM-top-5 movers, Yahoo with rate discipline, change%+volume score, 5 movers/run, 10% mover sizing, max positions 10, confidence 0.6 unchanged, watchlist+movers both, transient movers, skip held, skip when markets closed, budget 5000, signals tagged.

## Decisions

### D1: Universe.top_movers/3
`top_movers(quotes, exclude, n)` — pure function: score each quote with `abs(day_change_pct) + (volume >= floor ? 1.0 : 0.0)`, exclude symbols in `exclude` (held + watchlist), return the top n `{symbol, asset_class}` entries. `:none` when fewer than 1 eligible.

### D2: Rate-disciplined quote fetch
`YahooFinance.quotes/2` gains rate discipline opts: `chunk_size` (default 25), `min_interval_ms` (default 150) between chunk requests, and on 429 responses: backoff + retry once per chunk, then skip the chunk (partial results). Never raises; returns `{:ok, quotes}` with whatever succeeded.

### D3: Mover analysis in runner
After watchlist analysis + news, when markets open (B3 13:00–20:00 UTC weekdays OR US 14:30–20:00 UTC weekdays, configurable via `MARKET_HOURS_ENABLED`), the runner:
1. fetches universe quotes (rate-disciplined)
2. `top_movers(quotes, held ++ watchlist, MOVER_COUNT)`
3. LLM deep-dive each mover (same prompt/confidence; flash model)
4. signals stored with `source: "mover"`; watchlist signals `source: "watchlist"`

### D4: Mover risk sizing
`Risk.precheck` gains mover handling: orders marked `source: :mover` are limited to `MAX_MOVER_POSITION_PCT` (default 0.10) instead of 0.25; `MAX_POSITIONS` default raised to 10.

### D5: Market hours gate
`Config.market_open?(now)` — true when B3 or US market is open (weekday, hour windows). When false, mover screen skipped (watchlist analysis continues).

### D6: Budget
`DAILY_CALL_BUDGET` default 2400 → 5000.

## Risks / Trade-offs

- [Yahoo still throttles] → rate discipline + partial results keep the run alive; movers may be empty on heavy throttle (watchlist unaffected).
- [~3100 calls/day] → under the raised 5000 budget; Go plan caps are the outer bound.
- [Mover trades riskier] → 10% sizing cap + 0.6 confidence gate + stop-loss/min-hold unchanged.
