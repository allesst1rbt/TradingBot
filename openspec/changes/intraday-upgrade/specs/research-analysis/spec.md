# research-analysis

## MODIFIED Requirements

### Requirement: DeepSeek signal via JSON-mode LLM call
The system SHALL obtain signals from the configured LLM with `response_format: json_object` and MUST parse a strict JSON signal with fields `action` (one of `BUY`, `SELL`, `HOLD`, `CLOSE`), `confidence` (0..1), `rationale` (string), and `target_weight` (number).

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

## ADDED Requirements

### Requirement: Model split by run kind
The system SHALL use the flash model (default `deepseek-v4-flash`) for `standard` and `forced` runs, and the pro model (default `deepseek-v4-pro`) for `deep` runs.

#### Scenario: Flash on standard run
- **WHEN** a `standard` run calls the LLM
- **THEN** the request model is `deepseek-v4-flash`

#### Scenario: Pro on deep run
- **WHEN** a `deep` run calls the LLM
- **THEN** the request model is `deepseek-v4-pro`

### Requirement: Compact rolling context
The system SHALL build prompts with a compact rolling 24h summary (last signal, position, recent news notes, equity) from DB aggregates instead of raw history, keeping prompt size roughly constant across runs.

#### Scenario: Prompt contains rolling summary
- **WHEN** a run builds the prompt for a symbol with 100+ prior runs in DB
- **THEN** the prompt contains the rolling summary fields and its byte size is within 20% of a prompt built with 1 prior run

### Requirement: News integration
The system SHALL request one market-wide news note per run via the Hermes news tool, and SHALL request a deeper per-symbol news search when a symbol's 15m move exceeds the volatility threshold (default ±2%).

#### Scenario: Market-wide note every run
- **WHEN** a `standard` run executes
- **THEN** exactly one market-wide news request is made and its text is stored in the `news` table

#### Scenario: Trigger-based deep search
- **WHEN** a symbol's 15m price move exceeds ±2%
- **THEN** a per-symbol news request is made for that symbol and stored with the trigger value
