# telegram-commands

## ADDED Requirements

### Requirement: Long-polling receive loop
The system SHALL receive Telegram messages via a long-polling `getUpdates` loop (no webhook), persist the offset, and dispatch slash commands.

#### Scenario: Command dispatch
- **WHEN** a Telegram message `/status` arrives for the configured chat
- **THEN** the bot replies in that chat with current equity, positions, and last-run age

#### Scenario: Non-command messages ignored
- **WHEN** a message that is not a known command arrives
- **THEN** no reply is sent

### Requirement: /hour command
The system SHALL reply to `/hour` with the equity delta and trade count over the last 60 minutes.

#### Scenario: Hour reply
- **WHEN** `/hour` is received
- **THEN** the reply contains equity change and trade count computed from snapshots/trades of the last 60 minutes

### Requirement: /day and /month commands
The system SHALL reply to `/day` with today's diary (equity, P&L, trades) and to `/month` with the 30-day diary (daily rows + gate countdown).

#### Scenario: Month reply
- **WHEN** `/month` is received
- **THEN** the reply lists one line per day for the last 30 days with date, equity, P&L, and trade count, ending with the days-until-gate count

### Requirement: /force command
The system SHALL reply to `/force` confirming the forced run was started or queued.

#### Scenario: Force ack
- **WHEN** `/force` is received and no run is executing
- **THEN** the bot replies "Forced run started" and a forced run begins
