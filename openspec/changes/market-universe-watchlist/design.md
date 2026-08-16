# Market Universe Watchlist Design

## Context

Bounded extension of the live intraday bot. Decisions crystallized with the user: static universe list, rules-based candidate pick (zero LLM cost), unbounded watchlist growth.

## Decisions

### D1: Static universe file
`config/market_universe.json` — `{symbols: [{symbol, asset_class}]}`. 660 entries (BR: 157 liquid B3 tickers, US: 503 S&P 500). Read-only reference; editable by the user. Loading is a pure parse of the file.

### D2: Watchlist in SQLite
New `watchlist` table: `id, symbol, asset_class, coin_id (nullable), added_at, source ("seed"|"candidate")`. `BotTrader.Store.get_watchlist/0`, `add_to_watchlist/2`, `seed_watchlist/1` (seeds from config/watchlist.json only when the table is empty). Runner's `load_watchlist` falls back to Store (seeding from the legacy file on first boot). `deps[:watchlist]` still overrides in tests.

### D3: Batch quotes for the whole market
`BotTrader.MarketData.YahooFinance.quotes(symbols, opts)` → GET `{base}/v7/finance/quote?symbols=A,B,C`, chunks of `UNIVERSE_QUOTE_CHUNK` (default 50), returns `[{symbol, price, day_change_pct, volume}]`, drops missing. Injectable base URL for tests (Req.Test).

### D4: Rules-based candidate pick
`BotTrader.Universe.pick_candidate(quotes, watchlist_symbols)` — score = `abs(day_change_pct)` (+1.0 if volume > `UNIVERSE_VOLUME_FLOOR` default 1_000_000); pick the highest-scoring symbol NOT in the watchlist. Deterministic, no LLM. Returns `{:ok, entry}` or `:none` (all already in watchlist).

### D5: One addition per run
Runner, after news, calls `deps[:universe_fun] || &Universe.scan_and_add/0`. `scan_and_add` fetches quotes for the universe, picks a candidate, `Store.add_to_watchlist`. Failures are non-fatal (run continues; symbol skipped). No cap (unbounded).

## Risks / Trade-offs

- [Yahoo rate limits on batch quotes] → chunked 50/request; failures non-fatal; watchlist still grows from earlier successes.
- [BR list curated not exhaustive] → file is static/editable; universe can be extended by the user.
- [Unbounded growth → LLM cost grows] → user explicitly chose unbounded; signals cost scales with watchlist size.

## Migration

1. Deploy: boot migrates watchlist table (V2 migration), seeds from legacy watchlist.json if empty.
2. Rollback: previous image ignores the table.
