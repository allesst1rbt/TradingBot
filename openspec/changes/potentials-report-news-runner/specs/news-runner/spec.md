# news-runner

## ADDED Requirements

### Requirement: Separate news runner
The system SHALL run a dedicated supervised GenServer that checks every open position for TradingView news every 5 minutes, independent of the scraper scheduler and main runner.

#### Scenario: Open-position news check
- **WHEN** an open position exists for VIVT3 and the news runner ticks
- **THEN** the runner attempts to fetch VIVT3 public TradingView news (headline, source, timestamp)

#### Scenario: No open positions
- **WHEN** no open positions exist
- **THEN** the news runner completes the tick without fetching news

### Requirement: News normalization and dedup
The system SHALL store normalized news rows (symbol, headline, source, timestamp, sentiment, hash) and SHALL deduplicate headlines by hash per symbol.

#### Scenario: Duplicate headline skipped
- **WHEN** the same headline is fetched twice for a symbol
- **THEN** only one row is stored

### Requirement: LLM batch sentiment
The system SHALL classify new headlines in one LLM batch per cycle as positive, negative, or neutral, falling back to neutral on failure.

#### Scenario: Batch classification
- **WHEN** three new headlines exist across open positions in a cycle
- **THEN** one LLM call classifies all three and each row stores its sentiment

### Requirement: Risk alerts
The system SHALL send a Telegram risk alert for a held position only when a new headline is negative or a position re-analysis changes the signal.

#### Scenario: Negative headline alert
- **WHEN** a new headline for a held position is classified negative
- **THEN** a compact Telegram risk alert is sent with symbol, headline, and sentiment

#### Scenario: Neutral headline no alert
- **WHEN** a new headline is classified neutral
- **THEN** no risk alert is sent

### Requirement: Position re-analysis
The system SHALL run an LLM position re-analysis (HOLD/SELL/CLOSE) with structured news context when a new headline arrives, and SHALL store the resulting signal with source `news`.

#### Scenario: Re-analysis signal stored
- **WHEN** a new headline triggers re-analysis of a held position
- **THEN** the signal row has source `news` and the same risk gates and confidence threshold apply

### Requirement: News retention
The system SHALL prune stored news rows to the latest 50 per symbol after each cycle.

#### Scenario: Prune
- **WHEN** a symbol has 60 news rows
- **THEN** after pruning, 50 newest rows remain
