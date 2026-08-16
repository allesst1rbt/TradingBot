# Market Universe Watchlist Proposal

## Why

The bot currently analyzes a fixed 7-symbol watchlist. The user wants the scraper to cover the full US and BR stock market, an increaseable watchlist (persisted, grows over time), and one new symbol added to the watchlist on every scrape run — automatically, with no LLM cost.

## What Changes

- Static master universe file `config/market_universe.json` (660 symbols: 157 B3 + 503 S&P 500).
- New `watchlist` SQLite table; first boot seeds it from `config/watchlist.json`; all later runs read the watchlist from SQLite (grows across restarts).
- New `BotTrader.MarketData.YahooFinance.quotes/2` batch quote fetch (v7 endpoint, chunked) for cheap whole-market scanning.
- New `BotTrader.Universe` module: loads universe, scores candidates by rules (absolute day-change % + volume bonus), picks the top symbol not already in the watchlist.
- Runner adds one picked symbol to the watchlist on every run (unbounded growth per user decision).

## Capabilities

### New Capabilities
- `market-universe`: static universe listing + rules-based candidate ranking + batch quotes for the full market.

### Modified Capabilities
- `market-data`: add batch quotes endpoint.
- `data-store`: add watchlist table with seed/add/get.
- `research-analysis`-adjacent pipeline (runner): watchlist now comes from SQLite and grows by one per run.
