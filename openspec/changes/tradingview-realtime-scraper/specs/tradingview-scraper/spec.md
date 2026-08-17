## ADDED Requirements

### Requirement: Public-page extraction
The system SHALL extract public TradingView market and technical fields without authentication, anti-bot bypass, or a public scraper endpoint.

#### Scenario: Valid symbol page
- **WHEN** a public TradingView page for `BMFBOVESPA:VIVT3` renders required market and technical fields
- **THEN** the scraper returns one normalized snapshot with symbol, timestamp, price, change, OHLC, volume, technical rating, RSI, MACD, and moving averages

#### Scenario: Blocked page
- **WHEN** TradingView blocks or times out a symbol page
- **THEN** the scraper returns a stale/error result for that symbol and continues the batch

### Requirement: Round-robin batches
The system SHALL scrape the configured US/BR universe in batches of configurable size (default 25), advancing a persisted cursor after each batch.

#### Scenario: Batch cursor advances
- **WHEN** batch 1 of a 4-batch cycle completes
- **THEN** the next scraper tick starts at batch 2 and no symbol from batch 1 is scraped again until the cycle wraps

### Requirement: Compact SQLite snapshots
The system SHALL persist normalized snapshots with provider, timestamp, timeframe, and stale/error provenance, and SHALL NOT persist raw HTML or screenshots.

#### Scenario: Snapshot persistence
- **WHEN** a valid VIVT3 snapshot is scraped
- **THEN** a typed SQLite row is written and can be queried by symbol and timestamp

### Requirement: Top-N reasoning
The system SHALL rank available snapshots deterministically and send only the top 10 symbols to the LLM with structured snapshot data and current-position context.

#### Scenario: Shortlist bounded
- **WHEN** 600 valid snapshots exist
- **THEN** exactly 10 or fewer symbols are sent to the LLM and the remaining 590 are not individually reasoned over

### Requirement: Provider fallback
The system SHALL use TradingView as the primary provider and SHALL use the existing Yahoo provider as a fallback when TradingView data is unavailable.

#### Scenario: TradingView fallback
- **WHEN** TradingView fails for a symbol and Yahoo returns valid normalized data
- **THEN** the returned snapshot is marked with Yahoo provenance and the batch continues
