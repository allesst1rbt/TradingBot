# telegram-commands

## MODIFIED Requirements

### Requirement: /day command
The system SHALL reply to `/day` with the UTC-day summary: equity, trade count, realized P&L, unrealized P&L, and open positions count.

#### Scenario: Day reply
- **WHEN** `/day` is received and the day has 3 trades (realized +5.0) and 2 open positions (unrealized +1.2)
- **THEN** the reply contains "Trades: 3", "Realized: +5.00", "Unrealized: +1.20", "Open positions: 2", and the equity line

### Requirement: /week command
The system SHALL reply to `/week` with the rolling-7-day summary (trade count, realized, unrealized, open positions), without an equity line.

#### Scenario: Week reply
- **WHEN** `/week` is received with 4 trades in the last 7 days
- **THEN** the reply contains "Trades: 4" and no equity line

### Requirement: /month command
The system SHALL reply to `/month` with the rolling-30-day summary only (no diary rows, no gate countdown).

#### Scenario: Month summary
- **WHEN** `/month` is received
- **THEN** the reply contains the summary lines and does not contain "Gate evaluation" or per-day rows

### Requirement: Command menu registration
The system SHALL register /status, /hour, /day, /week, /month, /force, /positions in the command menu.

#### Scenario: Menu includes week
- **WHEN** the poller starts
- **THEN** the setMyCommands payload includes week
