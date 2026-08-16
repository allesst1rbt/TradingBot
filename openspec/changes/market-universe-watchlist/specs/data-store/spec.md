# data-store

## ADDED Requirements

### Requirement: Watchlist table
The system SHALL persist the watchlist in a SQLite `watchlist` table (symbol, asset_class, coin_id nullable, added_at, source) and seed it from `config/watchlist.json` only when empty.

#### Scenario: Seed on empty
- **WHEN** the watchlist table is empty and `seed_watchlist` is called with legacy entries
- **THEN** the legacy entries are inserted with source `seed`

#### Scenario: Idempotent seed
- **WHEN** `seed_watchlist` is called again after seeding
- **THEN** no duplicate rows are inserted

#### Scenario: Add and read back
- **WHEN** `add_to_watchlist("NEW", "stock-us")` is called
- **THEN** `get_watchlist` includes NEW with source `candidate`, and duplicate adds are rejected

### Requirement: Runner uses persisted watchlist
The system SHALL read the watchlist from SQLite for analysis (falling back to the legacy file only to seed an empty table).

#### Scenario: Watchlist from store
- **WHEN** a run starts after the table is seeded and has grown
- **THEN** the run analyzes all symbols currently in the watchlist table
