# market-data

## MODIFIED Requirements

### Requirement: Normalized candles via provider behaviour
The system SHALL expose a `BotTrader.MarketData` behaviour whose providers return normalized OHLCV candles for a given symbol, day range, and interval. Candle maps MUST contain `ts`, `open`, `high`, `low`, `close`, and `volume` fields. Providers MUST drop candles with nil close.

#### Scenario: Fetch intraday candles
- **WHEN** `YahooFinance.candles("PETR4.SA", 1, "15m")` is called
- **THEN** a list of 15-minute candles for the last day is returned, each with `ts`, `open`, `high`, `low`, `close`, `volume`

#### Scenario: Nil-close candles dropped
- **WHEN** a provider response contains candles with nil close
- **THEN** those candles are excluded from the result

## ADDED Requirements

### Requirement: Intraday interval support
The system SHALL support `5m`/`15m`/`30m`/`1d` intervals for Yahoo (via `interval` param and matching range) and SHALL bucket CoinGecko hourly data into the requested interval when finer data is unavailable.

#### Scenario: Yahoo interval param
- **WHEN** a `15m` interval is requested from YahooFinance
- **THEN** the request URL carries `interval=15m` and a range consistent with intraday data (`1d`)

#### Scenario: CoinGecko bucketing
- **WHEN** a `15m` interval is requested from CoinGecko and hourly data is returned
- **THEN** candles are aggregated into 15-minute buckets (same OHLCV shape)

### Requirement: Empty window aborts analysis
The system MUST treat an empty or all-nil candle window as `{:error, :no_data, symbol}` and MUST NOT invoke the LLM for that symbol in that run.

#### Scenario: Empty intraday window
- **WHEN** the provider returns no usable candles for a symbol
- **THEN** the run records the symbol as skipped and performs no LLM call for it
