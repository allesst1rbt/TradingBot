# Potentials Report + News Runner Proposal

## Why

The bot observes and ranks the full TradingView universe but never surfaces the analysis to the user, and it reasons over open positions without current news. The user wants (a) a Telegram batch report of observed potentials once per full screening cycle, and (b) a separate news runner that fetches TradingView news for every open position, classifies sentiment, and feeds it into position re-analysis.

## What Changes

- New `BotTrader.Potentials.Report` builds a compact Telegram batch report from screened TradingView snapshots and sends it once per full round-robin cycle (cursor wrap).
- New `BotTrader.NewsRunner` GenServer with its own 5-minute tick:
  - Loads open positions from the trades-derived Store.
  - Fetches public TradingView news (headline, source, timestamp) per position page.
  - Deduplicates headlines; stores structured news rows; prunes to the latest 50 per symbol.
  - Classifies sentiment in one LLM batch per cycle.
  - On a new negative headline or signal change, sends a risk Telegram alert and triggers an LLM re-analysis (HOLD/SELL/CLOSE).
  - Feeds structured news into position reasoning prompts.
- New `news`-capable schema and Store queries; TradingView page news extraction.

## Capabilities

### New Capabilities
- `potentials-report`: once-per-cycle Telegram batch report of screened potentials.
- `news-runner`: separate 5-minute news GenServer, dedup, sentiment, risk alerts, and position re-analysis.

### Modified Capabilities
- `market-data`: TradingView page news extraction.
- `research-analysis`: structured news context in position reasoning.
- `telegram-notifications`: risk alerts + batch potential report.
