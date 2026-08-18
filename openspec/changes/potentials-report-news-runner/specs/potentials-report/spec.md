# potentials-report

## ADDED Requirements

### Requirement: Once-per-cycle potentials report
The system SHALL send a single Telegram report containing the screened TradingView potentials once per full universe round-robin cycle (cursor wrap), excluding empty or stale symbols.

#### Scenario: Cycle wrap report
- **WHEN** the scraper cursor wraps to the start of the universe after the final batch
- **THEN** exactly one Telegram message is sent listing each screened symbol's symbol, price, change percentage, and technical rating

#### Scenario: No report mid-cycle
- **WHEN** the scraper advances within a cycle without wrapping
- **THEN** no potentials report is sent

### Requirement: Report formatting
The report SHALL be compact, one line per symbol, and exclude symbols with no valid snapshot.

#### Scenario: Stale exclusion
- **WHEN** a symbol's latest snapshot is stale or missing
- **THEN** that symbol is omitted from the potentials report
