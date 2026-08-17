# telegram-notifications

## MODIFIED Requirements

### Requirement: Run failure alert
The system SHALL send a Telegram alert when a run fails before completing, including which symbols were skipped.

#### Scenario: Alert on failed run
- **WHEN** a run aborts or degrades (e.g. LLM unreachable)
- **THEN** a Telegram alert is sent listing the failure and affected symbols

### Requirement: Degraded alert cap
The system SHALL send the degraded-symbols alert at most once per rolling 24h window. Subsequent degraded runs within the window SHALL be silent (noted in the run record only).

#### Scenario: First degraded run alerts
- **WHEN** a run degrades and no degraded alert was sent in the last 24h
- **THEN** the calm alert is sent and the timestamp is recorded

#### Scenario: Repeat within 24h silent
- **WHEN** a run degrades and a degraded alert was sent less than 24h ago
- **THEN** no degraded alert is sent

### Requirement: Calm wording
The degraded alert SHALL read "⚠️ Analysis degraded for: SYMBOLS — retrying next run" and SHALL NOT contain "run FAILED".

#### Scenario: Wording check
- **WHEN** a degraded alert is formatted
- **THEN** the message contains "Analysis degraded" and does not contain "FAILED"
