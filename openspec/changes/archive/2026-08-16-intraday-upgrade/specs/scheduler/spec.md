# scheduler

## ADDED Requirements

### Requirement: 5-minute ticker
The system SHALL trigger a standard run every 5 minutes, 24/7, via an in-app scheduler, and SHALL skip a tick when the previous run is still executing.

#### Scenario: Tick triggers run
- **WHEN** the scheduler ticks at a 5-minute boundary and no run is executing
- **THEN** a `standard` run starts

#### Scenario: Overlap skipped
- **WHEN** the scheduler ticks while a run is still executing
- **THEN** no new run starts and the next free tick proceeds normally

### Requirement: Daily deep run
The system SHALL run one `deep` run per day at 21:30 UTC using the pro model.

#### Scenario: Deep run at 21:30 UTC
- **WHEN** the scheduler clock reaches 21:30 UTC on a new day
- **THEN** a `deep` run executes with the pro model and writes a `runs` row of kind `deep`

### Requirement: Forced run
The system SHALL run a `forced` run immediately when requested via /force, or after the current run completes if one is executing.

#### Scenario: Forced run immediate
- **WHEN** /force is received and no run is executing
- **THEN** a `forced` run starts within one second

#### Scenario: Forced run queued during busy run
- **WHEN** /force is received while a run executes
- **THEN** exactly one forced run starts after the current run finishes (duplicates collapse)

### Requirement: Call budget guardrail
The system SHALL alert on Telegram when the daily LLM call count exceeds the configured budget (default 2400).

#### Scenario: Budget alert
- **WHEN** the run counter passes the daily call budget
- **THEN** a Telegram alert is sent once that day and runs continue
