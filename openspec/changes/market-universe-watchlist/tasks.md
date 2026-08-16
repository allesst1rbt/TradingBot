# Market Universe Watchlist Tasks

## 1. Watchlist Storage

- [ ] 1.1 Migration V2: `watchlist` table (symbol, asset_class, coin_id nullable, added_at, source)
- [ ] 1.2 `BotTrader.WatchlistEntry` schema
- [ ] 1.3 Store: `get_watchlist/0`, `add_to_watchlist/3`, `seed_watchlist/1` (seed-only-when-empty, idempotent, duplicate rejection)
- [ ] 1.4 Test seed/add/get/duplicate/idempotent (RED→GREEN)

## 2. Batch Quotes

- [ ] 2.1 `YahooFinance.quotes/2` — v7 quote endpoint, chunking (default 50), normalize, drop missing
- [ ] 2.2 Test chunked fetch + missing-drop with Req.Test stubs (RED→GREEN)

## 3. Universe Module

- [ ] 3.1 `BotTrader.Universe.load_universe/1` parses `config/market_universe.json`
- [ ] 3.2 `BotTrader.Universe.pick_candidate/2` rules-based rank (abs day change + volume bonus), skip watchlist symbols, `:none` when all in watchlist
- [ ] 3.3 `BotTrader.Universe.scan_and_add/0` — fetch quotes → pick → Store.add_to_watchlist; non-fatal on failure
- [ ] 3.4 Test load/pick/none/scan-and-add (RED→GREEN)

## 4. Runner Integration

- [ ] 4.1 Runner `load_watchlist` reads from Store (seed from legacy file when empty); keep `deps[:watchlist]` override
- [ ] 4.2 Runner calls `universe_fun` each run (adds one candidate); failures non-fatal
- [ ] 4.3 Test watchlist-from-store and one-candidate-per-run (RED→GREEN)

## 5. Deploy Config

- [ ] 5.1 Config envs: `UNIVERSE_PATH`, `UNIVERSE_QUOTE_CHUNK`, `UNIVERSE_VOLUME_FLOOR`, `UNIVERSE_SCAN_ENABLED`
- [ ] 5.2 `config/market_universe.json` committed; README note
- [ ] 5.3 Validate prod compile + deploy
