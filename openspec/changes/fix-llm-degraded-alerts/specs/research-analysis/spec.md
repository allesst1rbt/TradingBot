# research-analysis

## MODIFIED Requirements

### Requirement: DeepSeek signal via JSON-mode LLM call
The system SHALL obtain signals from the configured LLM with `response_format: json_object` and MUST parse a strict JSON signal with fields `action`, `confidence`, `rationale`, `target_weight`. On transient failure the call SHALL be retried with the same model twice (1s and 3s backoff) before returning an error.

#### Scenario: Retry succeeds
- **WHEN** the first LLM call fails transiently and the second succeeds
- **THEN** the call returns `{:ok, body}` and exactly two HTTP attempts were made

#### Scenario: All retries exhausted
- **WHEN** three consecutive LLM calls fail
- **THEN** the call returns `{:error, :http_error}` after exactly three attempts
