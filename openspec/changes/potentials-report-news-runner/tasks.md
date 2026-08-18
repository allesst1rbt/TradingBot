# Potentials Report + News Runner Tasks

## 1. Storage and Report

- [ ] 1.1 V6 migration for news_runner rows (symbol, headline, source, timestamp, sentiment, hash, inserted_at)
- [ ] 1.2 `NewsStore` schema/queries: insert, dedup by hash, latest, prune to 50/symbol
- [ ] 1.3 `Potentials.Report.build/1` + Telegram send once per cycle
- [ ] 1.4 Test dedup, prune, report formatting, cycle-wrap send (RED→GREEN)

## 2. News Extraction

- [ ] 2.1 Extend TradingView Playwright extraction with headline/source/timestamp lists
- [ ] 2.2 Test fixture extraction and empty-on-failure (RED→GREEN)

## 3. News Runner

- [ ] 3.1 `NewsRunner` GenServer: 5-min tick, open positions, fetch, dedup, persist
- [ ] 3.2 LLM batch sentiment (one call per cycle, neutral fallback)
- [ ] 3.3 Risk alert on negative headline or signal change
- [ ] 3.4 Position re-analysis with structured news context; signal source `news`
- [ ] 3.5 Test tick, dedup, sentiment, alert gating, re-analysis (RED→GREEN)

## 4. Potentials Report Wiring

- [ ] 4.1 Scraper cursor wrap triggers one Telegram potentials report
- [ ] 4.2 Test wrap triggers send; mid-cycle no send (RED→GREEN)

## 5. Railway Rollout

- [ ] 5.1 Add NewsRunner to supervision tree; README env/docs
- [ ] 5.2 Deploy and validate in production
