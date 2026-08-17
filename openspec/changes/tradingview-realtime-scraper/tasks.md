# TradingView Realtime Scraper Tasks

## 1. Snapshot Schema and Store

- [x] 1.1 Add V5 SQLite migration for TradingView snapshots, scraper cursor, stale/error provenance, and retention metadata
- [x] 1.2 Add Ecto schemas and Store queries for latest snapshot, batch cursor, and compact history
- [x] 1.3 Test snapshot persistence, stale metadata, cursor advancement, retention query (RED→GREEN)

## 2. Playwright Scraper

- [x] 2.1 Add Playwright runtime to the Docker image without exposing a browser port
- [x] 2.2 Implement `BotTrader.TradingView.Browser` with one browser and configurable 2–4 page concurrency
- [x] 2.3 Implement centralized selectors and `BotTrader.TradingView.Normalizer`
- [x] 2.4 Test fixture extraction, missing-field handling, and blocked-page continuation (RED→GREEN)

## 3. Round-Robin Universe

- [x] 3.1 Implement batch partitioning and persisted cursor
- [x] 3.2 Implement five-minute scraper tick integration and stale fallback
- [x] 3.3 Test cursor wrap, batch size, stale retention, and no duplicate batch within a cycle (RED→GREEN)

## 4. Provider and LLM Integration

- [ ] 4.1 TradingView-primary/Yahoo-fallback coordinator
- [ ] 4.2 Deterministic snapshot scorer and top-10 shortlist
- [ ] 4.3 Structured snapshot prompt builder for LLM reasoning
- [ ] 4.4 Test fallback provenance, top-10 bound, and prompt fields (RED→GREEN)

## 5. Railway Rollout

- [ ] 5.1 Add scraper environment variables and README documentation
- [ ] 5.2 Deploy Playwright image with no public browser endpoint
- [ ] 5.3 Validate production shadow mode and enable TradingView primary
