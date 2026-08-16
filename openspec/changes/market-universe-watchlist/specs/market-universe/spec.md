# market-universe

## ADDED Requirements

### Requirement: Static universe listing
The system SHALL expose the full US and BR stock universe from `config/market_universe.json` as `[{symbol, asset_class}]` entries.

#### Scenario: Universe loads
- **WHEN** `Universe.load_universe()` is called
- **THEN** a list of entries with `symbol` and `asset_class` (`stock-br` | `stock-us`) is returned, with count ≥ 500

### Requirement: Rules-based candidate pick
The system SHALL rank universe candidates by a deterministic rule score (absolute day-change % plus a volume bonus) and pick the top symbol not already in the watchlist, with no LLM call.

#### Scenario: Picks highest mover not in watchlist
- **WHEN** quotes include symbol A (day change +6.5%) and B (day change +3.0%), and A is already in the watchlist
- **THEN** the pick is `{:ok, B}`

#### Scenario: All in watchlist
- **WHEN** every quote symbol is already in the watchlist
- **THEN** the pick is `:none`

### Requirement: One candidate added per run
The system SHALL add exactly one new universe symbol to the watchlist on each run, and failures in scanning MUST NOT fail the run.

#### Scenario: Run grows watchlist
- **WHEN** a run executes with watchlist `[A]` and a universe quote for B available
- **THEN** the run completes and the watchlist contains `[A, B]`

#### Scenario: Scan failure non-fatal
- **WHEN** the universe quote fetch fails
- **THEN** the run completes normally and the watchlist is unchanged
