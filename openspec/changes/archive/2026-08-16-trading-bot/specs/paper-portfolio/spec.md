# paper-portfolio

## ADDED Requirements

### Requirement: Virtual account with R$ 1.000 starting capital
The system SHALL model a virtual account in BRL starting with R$ 1.000 cash, holding positions across BR stocks, US stocks, and crypto (crypto priced in USD converted to BRL at the configured rate).

#### Scenario: Fresh portfolio
- **WHEN** a new portfolio is initialized
- **THEN** it holds R$ 1.000 cash, zero positions, and zero realized P&L

### Requirement: Order execution applies fees and slippage
The system MUST apply the configured fee (crypto 0.1% of notional, US stock $1 flat, B3 stock R$5 flat) and 0.05% adverse slippage to every executed order, and the resulting cash and position quantities MUST reflect them.

#### Scenario: Crypto buy with fee and slippage
- **WHEN** a BUY of R$ 100 of BTC at price 300000 BRL is executed
- **THEN** cash decreases by exactly `100 + 100 * 0.001` (fee) and position quantity equals `(100 * (1 - 0.0005)) / 300000` (slippage-adjusted)

#### Scenario: US stock buy with flat fee
- **WHEN** a BUY of 2 shares of AAPL at $200 is executed
- **THEN** cash decreases by the notional plus US$ 1 converted to BRL at the configured rate

#### Scenario: B3 stock buy with flat fee
- **WHEN** a BUY of 10 shares of PETR4 at R$ 20 is executed
- **THEN** cash decreases by the notional plus R$ 5

### Requirement: Hard risk limits enforced
The system MUST reject any order that would make a position exceed 25% of current capital, MUST reject orders when 6 positions are already open, MUST auto-close a position whose loss since entry reaches 5% (stop-loss), and MUST block new buys after a 3% daily loss.

#### Scenario: Max position size rejected
- **WHEN** a BUY is submitted that would allocate more than 25% of capital to one symbol
- **THEN** the order is rejected with `{:error, :max_position_size}` and no state change occurs

#### Scenario: Max positions rejected
- **WHEN** a BUY is submitted while 6 positions are open
- **THEN** the order is rejected with `{:error, :max_positions}`

#### Scenario: Stop-loss auto-close
- **WHEN** a position's current price is 5% or more below its entry price
- **THEN** the position is closed at the current price (with slippage) and a CLOSE order record is appended

#### Scenario: Daily loss limit blocks buys
- **WHEN** the day's realized losses have reached 3% of start-of-day capital
- **THEN** all new BUY orders for the day are rejected with `{:error, :daily_loss_limit}` while CLOSE orders still execute

### Requirement: Restart-safe JSON persistence
The system MUST persist `portfolio.json`, `trades.json`, and `snapshots.json` atomically (temp-file + rename) under `$BOT_STATE_DIR`, and a fresh boot MUST reconstruct the identical portfolio from these files.

#### Scenario: Round-trip persistence
- **WHEN** a portfolio with positions and trades is saved and a new process loads it from `$BOT_STATE_DIR`
- **THEN** the loaded portfolio equals the saved one (cash, positions, realized P&L identical)

#### Scenario: Corrupt file aborts run
- **WHEN** `portfolio.json` is unparseable
- **THEN** the run aborts with an error and never overwrites the existing state files
