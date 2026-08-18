# Potentials Report + News Runner Design

## Context

Built on the deployed TradingView scraper: snapshots are persisted in SQLite, the round-robin cursor advances per 5-minute tick, and mover reasoning already consumes structured snapshots. This change adds (1) a once-per-cycle Telegram potentials report and (2) a separate news GenServer that watches open positions, dedupes/sentiment-classifies headlines, alerts on risk, and re-analyzes positions.

## Goals / Non-Goals

**Goals:**
- Deliver one compact Telegram report per full universe cycle.
- Watch every open position every 5 minutes for news.
- Store headline, source, timestamp, sentiment; prune to latest 50/symbol.
- Trigger risk alerts and position re-analysis on new negative news.
- Keep news fully internal: no public endpoint, no auth bypass.

**Non-Goals:**
- No full article text storage.
- No news alerts for every headline (only risk).
- No new external news provider.

## Decisions

### D1: Once-per-cycle potentials report
`Potentials.Report.build(snapshots)` formats a compact Telegram message (symbol, price, change, technical rating). The scraper scheduler detects cursor wrap and sends it once per cycle via the existing Telegram client. Empty/stale symbols are excluded.

### D2: Separate NewsRunner GenServer
A dedicated supervised process ticks every 5 minutes, independent of the scraper and main runner. It loads open positions via `Store.open_positions()`, maps each to its TradingView page news, and persists normalized news rows.

### D3: News extraction from TradingView pages
The Node Playwright script extends the existing page extraction with news headline/source/timestamp lists from the public page. Extraction is best-effort; missing news marks that symbol's news as empty without failing the cycle.

### D4: Dedup and retention
Headlines are deduplicated by normalized text hash per symbol; rows are pruned to the latest 50 per symbol after each cycle.

### D5: LLM batch sentiment
All new headlines in a cycle are sent to the LLM in one call, requesting JSON sentiment per headline (positive/negative/neutral). Invalid or failed classification falls back to neutral. Sentiment is advisory context, not a standalone trade trigger.

### D6: Risk alerts and re-analysis
On a new headline with negative sentiment, or when a re-analysis changes the position signal, the NewsRunner sends a compact Telegram risk alert. It then runs the existing LLM position analysis with the structured news context and stores the resulting signal with source `news`.

### D7: Retention and storage
New `news_runner` rows: symbol, headline, source, timestamp, sentiment, hash, inserted_at. A V6 migration adds the table; prune keeps latest 50 per symbol.

## Risks / Trade-offs

- TradingView news extraction is brittle → best-effort, empty-on-failure, dedup by hash.
- LLM sentiment cost → one batch call per cycle, fallback neutral.
- Re-analysis can change signals → same risk gates and confidence threshold apply; news never bypasses risk checks.
- Telegram noise → risk-only alerts plus once-per-cycle potentials report.
