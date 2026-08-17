# backtest

## ADDED Requirements

### Requirement: Brief historical replay
The system SHALL provide `mix bot.backtest` that replays ~90 days of daily candles through the same indicator signal rules and paper portfolio engine used by the live pipeline, printing total return %, max drawdown %, and trade count.

#### Scenario: Deterministic backtest on fixtures
- **WHEN** backtest runs on a fixed fixture of 90 daily candles for a rising symbol
- **THEN** it prints return %, max drawdown %, and trade count matching pre-computed expected values from the fixture

### Requirement: Backtest does not call the LLM
The system MUST NOT make network calls to the LLM during backtest; signals come from deterministic indicator rules only.

#### Scenario: Indicator-only signals
- **WHEN** backtest runs
- **THEN** the report is labeled "indicator-only" and no LLM HTTP request is issued

### Requirement: Backtest never touches live state
The system MUST NOT read or write the live `$BOT_STATE_DIR` files during backtest.

#### Scenario: Isolated backtest
- **WHEN** backtest runs with live state files present
- **THEN** the live `portfolio.json` and `trades.json` remain byte-identical
