# Trading Bot Proposal

## Why

Build an autonomous trading bot that researches markets (BR stocks, US stocks, crypto), produces LLM-powered analysis, and executes trades on a virtual R$ 1.000 portfolio. After a 30-day paper evaluation, if performance passes a hard go/no-go gate (return ≥ 2%, max drawdown ≤ 5%, ≥ 10 trades), the bot is authorized to switch to real money via a broker adapter (no broker integrated yet). The bot must keep the user informed via Telegram on every action it takes.

## What Changes

- New Elixir/OTP application `bot_trader` (plain Mix app, no web framework), deployed on Railway (Hobby plan) as a cron job.
- Daily run-and-exit pipeline (`mix bot.daily`): fetch market data → DeepSeek analysis → paper order execution → JSON report → Telegram digest.
- Market data layer with pluggable providers, starting free (Yahoo Finance chart API for US/BR stocks, CoinGecko for crypto).
- LLM client calling DeepSeek v4 pro through a configurable OpenAI-compatible endpoint (user's opencode-go API key).
- Research pipeline: technical indicators (RSI, EMA) + news/fundamental context + qualitative LLM research reports; hybrid universe (seed watchlist + bot-discovered candidates).
- Paper portfolio engine: fees (crypto 0.1%, US $1 flat, B3 R$5 flat), 0.05% slippage, hard risk limits (max 25% per position, max 6 positions, 5% stop-loss, 3% daily loss limit), restart-safe via JSON state files.
- **Telegram notifications for every transaction** (order opened/closed, fills, fees, stop-loss triggers) plus a daily digest.
- 30-day evaluation gate computing return, max drawdown, and trade count, emitting a PASS/FAIL verdict.
- `mix bot.backtest` sanity check: replay ~90 days of historical daily candles through the signal + portfolio logic.
- Railway deployment: Nixpacks Elixir build, cron schedule (21:30 UTC daily = after B3 and US closes), 5GB volume mounted at `/data` for JSON state, secrets via env vars.

## Capabilities

### New Capabilities
- `market-data`: normalized OHLCV candles for BR stocks, US stocks, and crypto from free providers behind a pluggable behaviour.
- `research-analysis`: technical indicators, LLM signal generation via DeepSeek, qualitative research reports, hybrid watchlist/candidate discovery.
- `paper-portfolio`: virtual R$ 1.000 account with order execution, fee + slippage simulation, hard risk limits, and restart-safe JSON persistence.
- `telegram-notifications`: per-transaction announcements and daily digest sent to a Telegram chat.
- `evaluation-gate`: 30-day performance evaluation emitting a go/no-go verdict against configurable thresholds.
- `backtest`: brief historical replay of the signal + portfolio pipeline with summary metrics.

### Modified Capabilities
<!-- none — greenfield project -->

## Impact

- New codebase: Elixir Mix project in `/Users/carlos/dev/bot_trader` (repo-local OpenSpec).
- External dependencies: Yahoo Finance chart API, CoinGecko API, DeepSeek API (OpenAI-compatible), Telegram Bot API.
- Infrastructure: Railway project with cron service + volume; local dev via `mix bot.daily` run manually or from launchd/cron.
- No existing code, APIs, or systems affected.
