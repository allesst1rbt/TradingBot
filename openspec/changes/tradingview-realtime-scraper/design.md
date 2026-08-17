# TradingView Realtime Scraper Design

## Context

This is a greenfield data-provider extension to the deployed Elixir/OTP bot. The target is the public TradingView Brazil/US stock universe. TradingView pages are dynamic, so extraction uses Playwright Chromium. Access remains public-page only: no login automation, anti-bot bypass, websocket reverse engineering, or public scraper endpoint.

## Goals / Non-Goals

**Goals:**
- Refresh the full configured universe through five-minute round-robin batches.
- Persist compact normalized market/technical snapshots in SQLite.
- Rank symbols without LLM calls and send only the top 10 structured snapshots to the LLM.
- Preserve last-known data when a scrape fails and expose stale status.
- Use TradingView first and Yahoo fallback during rollout.

**Non-Goals:**
- No raw HTML or screenshots stored.
- No authenticated TradingView session.
- No bypass of rate limits, bot protections, or access restrictions.
- No public browser or scraper API.

## Decisions

### D1: One browser, low concurrency

The service owns one Chromium process and limits active pages to 2–4. A batch completes and closes pages before the next batch. This bounds Railway memory and reduces blocking risk.

### D2: Round-robin universe batches

The universe is partitioned into batches. Each five-minute tick scrapes one batch and persists a cursor. A full cycle may take multiple ticks. The batch size is configurable, default 25.

### D3: Normalized snapshot schema

Each valid symbol snapshot stores symbol, asset class, timestamp, timeframe, price, change percentage, OHLC, volume, technical rating, RSI, MACD, EMA/SMA values, provider, and stale flag. The schema is typed and compact; raw page content is discarded.

### D4: Selector strategy

Selectors are centralized and versioned in one module. Extraction first reads stable semantic labels/data attributes, then falls back to narrowly scoped text selectors. A fixture page is used for deterministic tests. Selector failure marks the symbol stale rather than failing the batch.

### D5: Provider fallback

The provider coordinator requests TradingView first. If the page times out, is blocked, or lacks required fields, it returns the last valid TradingView snapshot marked stale and optionally asks the existing Yahoo provider for a fallback snapshot. Fallback provenance is stored.

### D6: LLM shortlist

The scraper stores all available snapshots. A deterministic scorer ranks by absolute change, volume strength, and technical rating. Only the top 10 are sent to the existing LLM pipeline with structured snapshots and current position context.

### D7: Failure and retention

A failed page is skipped, the last valid snapshot remains queryable, and a stale/error event is stored. Snapshot compaction retains the latest snapshot per symbol/timeframe plus the configured recent history; raw HTML is never persisted.

## Risks / Trade-offs

- TradingView markup can change → selector fixtures and stale fallback prevent a run-wide failure.
- Public pages may rate-limit automation → low concurrency, round-robin cadence, and no retry storm.
- Full-cycle latency exceeds five minutes → the cursor and snapshot timestamp make freshness explicit.
- Playwright increases the image size → browser dependencies are installed once in the Railway image.

## Migration Plan

1. Deploy the scraper disabled or in shadow mode.
2. Validate snapshot freshness and stale rates against Yahoo for a sample batch.
3. Enable TradingView primary selection through environment configuration.
4. Roll back by selecting Yahoo as the provider; existing normalized snapshots remain valid.
