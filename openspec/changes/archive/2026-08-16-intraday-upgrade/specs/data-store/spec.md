# data-store

## ADDED Requirements

### Requirement: SQLite persistence via Ecto
The system SHALL persist runs, signals, trades, snapshots, and news in a SQLite database via Ecto on the `/data` volume, and SHALL use compact typed rows for each.

#### Scenario: Run row persisted
- **WHEN** a pipeline run starts and finishes
- **THEN** a `runs` row exists with `started_at`, `finished_at`, and `kind` (`standard` | `deep` | `forced`)

#### Scenario: Signal rows linked to run
- **WHEN** a run produces signals
- **THEN** each signal row references the run and stores symbol, action, confidence, model, and price

### Requirement: Hour/day/month aggregates
The system SHALL answer aggregate queries: equity delta over the last 60 minutes, day aggregates (equity, trades, P&L), and 30-day diary rows, all computed from DB rows.

#### Scenario: Hourly delta
- **WHEN** `/hour` data is requested and snapshots exist for the last 60 minutes
- **THEN** the equity delta between the newest and the snapshot 60 minutes earlier is returned with the trade count

#### Scenario: Monthly diary
- **WHEN** `/month` data is requested
- **THEN** one row per day for the last 30 days is returned (date, equity, P&L, trades, gate countdown)

### Requirement: Legacy JSON auto-migration on boot
The system SHALL, on first boot with legacy JSON files present, import portfolio/trades/snapshots into SQLite and rename the JSON files to `*.json.archived`.

#### Scenario: Migration imports and archives
- **WHEN** the app boots with `portfolio.json`, `trades.json`, `snapshots.json` in `BOT_STATE_DIR`
- **THEN** SQLite contains the imported rows and the JSON files are renamed to end in `.archived`

#### Scenario: Idempotent migration
- **WHEN** the app boots a second time with no JSON files present
- **THEN** no migration runs and existing SQLite rows are untouched

### Requirement: Telegram polling offset persistence
The system SHALL persist the Telegram `getUpdates` offset so no message is lost or duplicated across restarts.

#### Scenario: Offset survives restart
- **WHEN** the poller processed update_id 100 and the app restarts
- **THEN** polling resumes from update_id 101
