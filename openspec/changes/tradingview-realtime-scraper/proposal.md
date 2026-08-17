# TradingView Realtime Scraper

## Why

The bot currently relies on Yahoo data, which is rate-limited for whole-market screening. The user wants public TradingView data for the full US/BR universe, refreshed in five-minute round-robin batches, normalized compactly, and reasoned over by the LLM for the top candidates.

## What Changes

- Add a Playwright Chromium scraper for public TradingView market and symbol pages.
- Scrape the full configured US/BR universe in bounded round-robin batches every five minutes.
- Normalize market and technical fields into compact SQLite snapshots.
- Retain the last valid snapshot when a page fails or is blocked; mark the symbol stale.
- Rank the full available universe deterministically and send only the top 10 symbols to the LLM.
- Make TradingView the primary data source while retaining Yahoo as a fallback during migration.
- Keep the browser internal to the Railway service with no public browser endpoint.

## Capabilities

### New Capabilities
- `tradingview-scraper`: public-page extraction, normalized snapshots, batching, stale handling, and primary-provider selection.

### Modified Capabilities
- `market-data`: add TradingView snapshot/provider behavior and Yahoo fallback selection.
- `research-analysis`: consume structured TradingView snapshots for shortlist reasoning.

## Impact

- New Playwright/browser dependency and Docker image requirements.
- New SQLite snapshot schema and retention/compaction logic.
- New scraper scheduler state for round-robin batches.
- Railway memory and CPU usage increase; no public port is exposed.
