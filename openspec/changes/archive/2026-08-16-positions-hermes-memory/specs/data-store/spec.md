# data-store

## ADDED Requirements

### Requirement: Open positions derived from trades
The system SHALL derive current holdings from the trades table: per symbol, quantity = sum(BUY) − sum(SELL/CLOSE), average entry = weighted mean of BUY prices, unrealized P&L at the last-known signal price. Symbols with quantity ≤ 0 SHALL be excluded.

#### Scenario: Holdings from buy and close
- **WHEN** trades exist: BUY BTC 0.1 @ 100, CLOSE BTC 0.04 @ 110, and the last signal price for BTC is 120
- **THEN** open positions contain BTC with quantity 0.06, entry 100, unrealized = 0.06 × (120 − 100)

#### Scenario: Fully closed excluded
- **WHEN** a symbol's BUY quantity equals its CLOSE quantity
- **THEN** the symbol is absent from open positions

### Requirement: Paginated trade history
The system SHALL list trades newest-first with pagination, returning the page and the total page count.

#### Scenario: Pagination math
- **WHEN** 45 trades exist and page 3 with page size 20 is requested
- **THEN** the result is the 5 oldest trades and total pages = 3
