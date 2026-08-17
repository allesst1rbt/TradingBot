## MODIFIED Requirements

### Requirement: Structured LLM evidence
The system SHALL send shortlisted symbols to the LLM using structured TradingView snapshot fields, recent compact history, and current position context rather than rendered page text.

#### Scenario: Prompt uses structured snapshot
- **WHEN** a VIVT3 snapshot is shortlisted
- **THEN** the prompt contains its price, change, technical rating, RSI, MACD, moving averages, timestamp, and position context

#### Scenario: Top-N limit
- **WHEN** more than 10 valid snapshots are available
- **THEN** the LLM receives no more than 10 symbol analyses
