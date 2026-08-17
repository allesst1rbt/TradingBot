# data-store

## ADDED Requirements

### Requirement: Period summary aggregate
The system SHALL compute a period summary bounded by a start timestamp and now: trade count (all trades in window), realized P&L (sum of realized_pnl), current unrealized (sum of open positions' unrealized), and current open positions count.

#### Scenario: Bounded window
- **WHEN** 3 trades exist inside the window and 2 outside (older)
- **THEN** the summary's trade count is 3 and realized P&L includes only in-window trades

#### Scenario: Unrealized from open positions
- **WHEN** open positions exist with unrealized values 1.2 and −0.4
- **THEN** the summary's unrealized is 0.8 and open positions count is 2
