# Universe Mover Trading Proposal

## Why

The bot only ever analyzes/trades its 5-symbol watchlist (signals overwhelmingly HOLD; only PETR4 bought). The user wants the bot to explore the whole market: screen all 660 universe symbols, deep-dive the top movers with the LLM, and take calculated risks in new positions. The prior universe scan (1 candidate per run) was throttled to death by Yahoo 429s and added zero symbols.

## What Changes

- New mover screen: score all 660 universe symbols from Yahoo batch quotes (abs day-change% + volume bonus), skip held positions, deep-dive the top 5 movers with the LLM each run (configurable count).
- Yahoo rate discipline for the screener: chunked quotes, min-interval between chunk requests, 429 backoff, partial results (no crash on throttle).
- Mover trades: max 10% of capital per mover position; max positions raised 6 → 10.
- Movers are transient (re-screened each run), skipped when all tracked markets are closed.
- Signals tagged `source` ("mover" | "watchlist") for audit.
- `DAILY_CALL_BUDGET` default raised to 5000.

## Capabilities

### New Capabilities
- `mover-trading`: whole-universe screening + top-mover LLM deep-dives + mover-specific risk sizing.

### Modified Capabilities
- `market-data`: rate-disciplined batch quotes.
- `data-store`: signals source tag.
- `research-analysis` (runner): mover analysis path.
- `paper-portfolio` (risk): mover sizing + position cap 10.
