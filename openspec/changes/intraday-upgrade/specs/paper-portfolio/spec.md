# paper-portfolio

## MODIFIED Requirements

### Requirement: Order execution applies fees and slippage
The system MUST apply the configured fee (crypto 0.1% of notional, US stock $1 flat, B3 stock R$5 flat) and 0.05% adverse slippage to every executed order, and the resulting cash and position quantities MUST reflect them. Trades MUST carry an `opened_at` timestamp for entry trades.

#### Scenario: Crypto buy with fee and slippage
- **WHEN** a BUY of R$ 100 of BTC at price 300000 BRL is executed
- **THEN** cash decreases by exactly `100 + 100 * 0.001` (fee) and position quantity equals `(100 * (1 - 0.0005)) / 300000` (slippage-adjusted)

#### Scenario: Entry trade has opened_at
- **WHEN** a BUY executes
- **THEN** the trade record includes `opened_at` with the execution timestamp

## ADDED Requirements

### Requirement: Minimum holding time
The system MUST reject reversal orders (SELL or CLOSE) for a position opened less than 15 minutes ago with `{:error, :min_hold}`. Stop-loss closes are exempt from this check.

#### Scenario: Fresh position cannot be closed
- **WHEN** a position was opened 3 minutes ago and a SELL/CLOSE order arrives
- **THEN** the order is rejected with `{:error, :min_hold}` and no state change occurs

#### Scenario: Stop-loss exempt from min-hold
- **WHEN** a position was opened 3 minutes ago and its price breaches the 5% stop-loss
- **THEN** the stop-loss CLOSE executes immediately

#### Scenario: Old position closes normally
- **WHEN** a position was opened more than 15 minutes ago
- **THEN** SELL/CLOSE orders pass the min-hold check
