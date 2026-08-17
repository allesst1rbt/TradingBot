# research-analysis

## ADDED Requirements

### Requirement: Technical indicators computed in Elixir
The system SHALL compute RSI(14), EMA(20), EMA(50), and the most recent daily return from normalized candles, deterministically and without network calls.

#### Scenario: RSI on trending series
- **WHEN** RSI(14) is computed on a candle series that rose steadily over 14 periods
- **THEN** the RSI value is ≥ 70

#### Scenario: EMA on flat series
- **WHEN** EMA(20) is computed on a flat candle series
- **THEN** the EMA equals the flat price within a small epsilon

### Requirement: DeepSeek signal via JSON-mode LLM call
The system SHALL call the configured DeepSeek endpoint with `response_format: json_object` and MUST parse a strict JSON signal with fields `action` (one of `BUY`, `SELL`, `HOLD`, `CLOSE`), `confidence` (0..1), `rationale` (string), and `target_weight` (number).

#### Scenario: Valid signal parsed
- **WHEN** the LLM returns valid signal JSON with `action: "BUY"`, `confidence: 0.8`
- **THEN** the system returns `{:ok, %Signal{action: :buy, confidence: 0.8, ...}}`

#### Scenario: Invalid JSON fails safe
- **WHEN** the LLM returns malformed JSON or an action outside the enum
- **THEN** the system returns `{:error, :invalid_signal}` and the pipeline executes no trade for that symbol

### Requirement: Confidence threshold gates execution
The system MUST NOT execute a BUY or SELL when the signal confidence is below the configured minimum (default 0.6).

#### Scenario: Low confidence rejected
- **WHEN** a signal has `confidence: 0.5` and threshold is 0.6
- **THEN** the order stage treats the signal as HOLD

### Requirement: Hybrid universe with seed watchlist and candidates
The system SHALL load a seed watchlist from `config/watchlist.json` and MAY add LLM-proposed candidate symbols, capped at a configurable maximum per day (default 3).

#### Scenario: Watchlist loaded at startup
- **WHEN** the daily pipeline starts
- **THEN** every symbol in `config/watchlist.json` is included in the analysis universe

#### Scenario: Candidate cap enforced
- **WHEN** the LLM proposes 5 new candidate symbols and the daily cap is 3
- **THEN** only the first 3 candidates are added to the universe for the run

### Requirement: Qualitative research report section
The system SHALL include a qualitative analysis section in each daily report, produced by the LLM from the symbol's recent context, labeled as qualitative and kept separate from indicator signals.

#### Scenario: Report contains qualitative section
- **WHEN** the daily report for a symbol is generated
- **THEN** the report contains a "Qualitative analysis" section with LLM prose and a visible label stating it is non-deterministic
