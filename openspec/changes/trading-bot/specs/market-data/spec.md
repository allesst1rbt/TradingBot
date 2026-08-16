# market-data

## ADDED Requirements

### Requirement: Normalized candles via provider behaviour
The system SHALL expose a `BotTrader.MarketData` behaviour whose providers return normalized OHLCV candles for a given symbol and day range. Candle maps MUST contain `ts`, `open`, `high`, `low`, `close`, and `volume` fields.

#### Scenario: Fetch BR stock candles
- **WHEN** `YahooFinance.candles("PETR4.SA", 90)` is called
- **THEN** a list of daily candles for the last 90 calendar days is returned, each with `ts`, `open`, `high`, `low`, `close`, `volume`

#### Scenario: Fetch US stock candles
- **WHEN** `YahooFinance.candles("AAPL", 90)` is called
- **THEN** a list of daily candles for AAPL is returned with the normalized shape

#### Scenario: Fetch crypto candles
- **WHEN** `CoinGecko.candles("bitcoin", 90)` is called
- **THEN** a list of daily candles for BTC/USD is returned with the normalized shape

### Requirement: Provider selection by asset class
The system SHALL route a symbol to its provider based on asset class configuration (stock-br, stock-us, crypto) without the caller specifying the provider.

#### Scenario: Route B3 ticker
- **WHEN** candles are requested for a symbol configured as `stock-br` (e.g. `PETR4`)
- **THEN** the YahooFinance provider is invoked with the `.SA` suffix

#### Scenario: Route crypto ticker
- **WHEN** candles are requested for a symbol configured as `crypto` (e.g. `BTC`)
- **THEN** the CoinGecko provider is invoked with the configured coin id

### Requirement: Failure safety on missing data
The system MUST return an explicit error (not raise) when a provider fails or returns no candles, and the caller MUST NOT trade on stale or missing data.

#### Scenario: Provider returns empty
- **WHEN** the provider responds with no candles for a symbol
- **THEN** the fetch returns `{:error, :no_data, symbol}` and the symbol is excluded from the run
