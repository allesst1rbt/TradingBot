## MODIFIED Requirements

### Requirement: Market data provider selection
The system SHALL select TradingView as the primary provider for configured US/BR stock snapshots and SHALL retain Yahoo as a fallback provider.

#### Scenario: TradingView primary
- **WHEN** a stock snapshot is requested and TradingView returns valid data
- **THEN** the snapshot provenance is `tradingview`

#### Scenario: Yahoo fallback
- **WHEN** TradingView fails and Yahoo returns valid data
- **THEN** the snapshot provenance is `yahoo` and the symbol is marked as fallback data
