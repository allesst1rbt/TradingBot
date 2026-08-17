# mover-trading

## ADDED Requirements

### Requirement: Top-mover screening
The system SHALL score every universe symbol by `abs(day_change_pct)` plus a volume bonus and return the top N symbols, excluding held positions and watchlist symbols.

#### Scenario: Top movers ranked
- **WHEN** quotes exist for 20 symbols with varying day changes and the exclude list contains the top scorer
- **THEN** the result is the next-highest scorers, capped at N, with the excluded symbol absent

#### Scenario: No eligible movers
- **WHEN** every quote symbol is in the exclude list
- **THEN** the result is `:none`

### Requirement: Mover deep-dive
The system SHALL run the LLM analysis on each screened mover during a run, storing its signal with `source: "mover"` (watchlist signals store `source: "watchlist"`).

#### Scenario: Mover signal tagged
- **WHEN** a run analyzes a mover and the LLM returns a signal
- **THEN** the signal row's source is "mover"

### Requirement: Mover position sizing
The system SHALL limit each mover position to `MAX_MOVER_POSITION_PCT` (default 10%) of capital, distinct from the 25% watchlist limit.

#### Scenario: Mover buy over 10% rejected
- **WHEN** a mover BUY would allocate more than 10% of capital
- **THEN** the order is rejected with `{:error, :max_position_size}`

### Requirement: Market-hours gate
The system SHALL skip the mover screen when all tracked markets are closed; watchlist analysis continues regardless.

#### Scenario: Weekend screen skipped
- **WHEN** a run executes on a weekend
- **THEN** no mover analysis occurs and the run completes normally
