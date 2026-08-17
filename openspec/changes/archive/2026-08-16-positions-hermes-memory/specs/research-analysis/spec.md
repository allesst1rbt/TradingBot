# research-analysis

## MODIFIED Requirements

### Requirement: Compact rolling context
The system SHALL build prompts with a compact rolling 24h summary (last signal, position, recent news notes, equity) from DB aggregates instead of raw history, keeping prompt size roughly constant across runs. The position field SHALL reflect the bot's actual open position for the analyzed symbol (quantity and average entry), or be "none" when flat.

#### Scenario: Prompt shows open position
- **WHEN** a run analyzes a symbol the bot holds 0.06 BTC at entry 100
- **THEN** the prompt's rolling summary position contains the quantity and entry

#### Scenario: Prompt shows none when flat
- **WHEN** a run analyzes a symbol with no open position
- **THEN** the prompt's rolling summary position is "none"
