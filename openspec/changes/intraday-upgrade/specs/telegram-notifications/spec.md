# telegram-notifications

## MODIFIED Requirements

### Requirement: Per-transaction Telegram announcements
The system SHALL send an immediate Telegram message for EVERY executed transaction — order opened or closed, including symbol, side, quantity, fill price, fee, and resulting cash or position summary. No transaction may complete silently.

#### Scenario: Buy announcement
- **WHEN** a BUY order is executed by the portfolio engine
- **THEN** a Telegram message is sent containing the symbol, side BUY, quantity, fill price, fee, and new cash balance

#### Scenario: Stop-loss close announcement
- **WHEN** the stop-loss closes a position
- **THEN** a Telegram message is sent containing the symbol, side CLOSE, reason stop-loss, realized P&L, and fee

### Requirement: Daily digest
The system SHALL send one digest at the end of each `deep` run (daily 21:30 UTC) summarizing day P&L, open positions, risk status, and the evaluation-gate countdown. Standard 5-minute runs MUST NOT send digests.

#### Scenario: Digest after deep run
- **WHEN** the daily deep run completes
- **THEN** a single digest message is sent containing today's P&L, the open positions list, and days remaining until the gate evaluation

#### Scenario: No digest on standard runs
- **WHEN** a standard 5-minute run completes
- **THEN** no digest message is sent

### Requirement: Delivery reliability
The system MUST retry a failed Telegram send once, and MUST log the failure into the run record if the retry also fails.

#### Scenario: First send fails, retry succeeds
- **WHEN** the first `sendMessage` call fails and the retry succeeds
- **THEN** exactly two send attempts occurred and the notification is delivered

#### Scenario: Both sends fail
- **WHEN** both send attempts fail
- **THEN** the failure is recorded in the run record and the pipeline continues (no crash)

## ADDED Requirements

### Requirement: Run failure alert
The system SHALL send a Telegram alert when a run fails before completing, including which symbols were skipped.

#### Scenario: Alert on failed run
- **WHEN** a run aborts or degrades (e.g. MCP unreachable)
- **THEN** a Telegram alert is sent listing the failure and affected symbols
