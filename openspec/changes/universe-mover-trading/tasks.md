# Universe Mover Trading Tasks

## 1. Mover Screen

- [x] 1.1 `Universe.top_movers/3` — pure top-N ranking by score, exclude list, `:none` when empty
- [x] 1.2 `Universe.screen_movers/1` — rate-disciplined quotes + top_movers + asset classes
- [x] 1.3 Config: `MOVER_COUNT` (5), `MAX_MOVER_POSITION_PCT` (0.10), `MAX_POSITIONS` (10), `DAILY_CALL_BUDGET` (5000), `MARKET_HOURS_ENABLED`
- [x] 1.4 Test ranking, exclusion, none, screen with fake quotes (RED→GREEN)

## 2. Rate-Disciplined Quotes

- [x] 2.1 `YahooFinance.quotes/2` — chunk default 25, min-interval 150ms, 429 backoff retry once, partial results
- [x] 2.2 Test chunk count/timing, 429 partial, no-crash (RED→GREEN)

## 3. Mover Analysis in Runner

- [x] 3.1 Runner: after watchlist+news, if market open → screen movers → LLM deep-dive each → signals with `source: "mover"`; watchlist signals `source: "watchlist"`
- [x] 3.2 `Config.market_open?/1` — B3/US weekday hour windows
- [x] 3.3 Test mover analysis path, source tags, market-hours gate (RED→GREEN)

## 4. Mover Risk Sizing

- [x] 4.1 `Risk.precheck` mover sizing (10% cap for `source: :mover` orders); `MAX_POSITIONS` 10
- [x] 4.2 Test mover over-10% rejected, watchlist 25% unaffected (RED→GREEN)

## 5. Deploy

- [x] 5.1 Signals schema `source` column (migration V4); README; prod compile; deploy
