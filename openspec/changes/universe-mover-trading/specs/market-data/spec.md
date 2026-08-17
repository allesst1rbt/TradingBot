# market-data

## MODIFIED Requirements

### Requirement: Batch quotes
The system SHALL fetch current quotes for many symbols in chunked requests and normalize to `{symbol, price, day_change_pct, volume}`, dropping symbols with no data. Fetches SHALL respect rate discipline: configurable chunk size (default 25), minimum interval between chunk requests (default 150ms), and a single 429 backoff retry per chunk with partial results on persistent throttle.

#### Scenario: Rate-disciplined chunks
- **WHEN** 60 symbols are requested with chunk size 25
- **THEN** at least three requests occur with ≥150ms between them

#### Scenario: 429 partial results
- **WHEN** a chunk request returns 429 twice
- **THEN** the fetch returns `{:ok, quotes}` containing the other chunks' results and no crash occurs
