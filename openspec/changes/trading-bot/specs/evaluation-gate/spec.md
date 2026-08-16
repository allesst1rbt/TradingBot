# evaluation-gate

## ADDED Requirements

### Requirement: 30-day performance evaluation
The system SHALL, on the 30th daily run (or when 30 days of snapshots exist), compute total return %, max drawdown %, and trade count from persisted snapshots and trades.

#### Scenario: Metrics computed
- **WHEN** 30 daily snapshots and 12 closed trades exist
- **THEN** the evaluation returns total return %, max drawdown %, and trade count = 12

### Requirement: Go/no-go verdict with hard thresholds
The system SHALL emit PASS only when return ≥ 2% AND max drawdown ≤ 5% AND trade count ≥ 10; otherwise FAIL. Thresholds are configurable via env.

#### Scenario: All thresholds met
- **WHEN** evaluation computes return 3.1%, max drawdown 4.2%, trades 11
- **THEN** verdict is PASS

#### Scenario: Drawdown too high
- **WHEN** evaluation computes return 4.0%, max drawdown 7.0%, trades 15
- **THEN** verdict is FAIL

#### Scenario: Too few trades
- **WHEN** evaluation computes return 2.5%, max drawdown 1.0%, trades 6
- **THEN** verdict is FAIL

### Requirement: Verdict delivered and safe by default
The system SHALL include the verdict in the day-30 digest. On PASS with no broker adapter configured, the bot MUST remain in paper mode and MUST notify the user that a broker must be attached before real trading.

#### Scenario: PASS without broker stays paper
- **WHEN** the verdict is PASS and no broker adapter is configured
- **THEN** the bot continues paper trading and the digest states real mode requires attaching a broker

#### Scenario: FAIL resets nothing
- **WHEN** the verdict is FAIL
- **THEN** the bot continues paper trading and the digest states the gate was not met, with the failing metrics
