# positions-command

## ADDED Requirements

### Requirement: /positions command
The system SHALL reply to `/positions` (and `/positions N`) with an open-positions section derived from the trades table, followed by paginated trade history (20 per page, newest first) with a page indicator. Out-of-range pages SHALL reply "no such page".

#### Scenario: Page one with open section
- **WHEN** `/positions` is received and the bot holds BTC (from BUY − CLOSE trades) and has 25 trades
- **THEN** the reply lists the open BTC position (qty, avg entry, unrealized at last-known price) followed by history page 1/2 (20 newest trades)

#### Scenario: Page two
- **WHEN** `/positions 2` is received
- **THEN** the reply lists the remaining 5 oldest trades with indicator "2/2"

#### Scenario: Out of range
- **WHEN** `/positions 9` is received and there are only 2 pages
- **THEN** the reply is "no such page"

#### Scenario: No open positions
- **WHEN** `/positions` is received and all positions are closed
- **THEN** the open section says "No open positions" and history follows

### Requirement: Command menu registration
The system SHALL register `/positions` in the Telegram command menu on boot.

#### Scenario: Menu includes positions
- **WHEN** the poller starts
- **THEN** the setMyCommands payload includes positions
