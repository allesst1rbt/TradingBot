# market-data

## ADDED Requirements

### Requirement: Batch quotes
The system SHALL fetch current quotes for many symbols in one chunked request (Yahoo v7 `quote` endpoint, chunk of configurable size, default 50) and normalize to `{symbol, price, day_change_pct, volume}`, dropping symbols with no data.

#### Scenario: Chunked quote fetch
- **WHEN** 120 symbols are requested with chunk size 50
- **THEN** three requests are issued and the merged result has 120 entries

#### Scenario: Missing symbols dropped
- **WHEN** a quote response omits a requested symbol
- **THEN** the result does not include that symbol
