# Trading Bot Tasks

## 1. Project Scaffold

- [x] 1.1 Create `bot_trader` Mix project (OTP app, `mix new bot_trader --sup`)
- [x] 1.2 Add deps: `req` (HTTP), `jason` (JSON); set Elixir ~> 1.17
- [x] 1.3 Add `BotTrader.Config` reading env vars (DeepSeek, Telegram, state dir, fees, risk thresholds) with defaults
- [x] 1.4 Add `config/watchlist.json` with seed symbols (PETR4, VALE3, ITUB4, AAPL, MSFT, BTC, ETH) and asset-class config
- [x] 1.5 Verify: `mix compile` and `mix test` pass on the scaffold

## 2. State Persistence

- [x] 2.1 Implement `BotTrader.State` with atomic write (temp + rename) for `portfolio.json`, `trades.json`, `snapshots.json` under `$BOT_STATE_DIR`
- [x] 2.2 Implement load with corrupt-file abort (never overwrite existing state)
- [x] 2.3 Test round-trip persistence and corrupt-file behavior (RED→GREEN)

## 3. Paper Portfolio Engine

- [x] 3.1 Implement pure `BotTrader.Portfolio` with `init/0` (R$ 1.000), `apply/2` order execution
- [x] 3.2 Apply fees (crypto 0.1%, US $1, B3 R$5) and 0.05% slippage on every order
- [x] 3.3 Implement `BotTrader.Risk` hard limits: 25% max position, 6 max positions, 5% stop-loss auto-close, 3% daily loss limit
- [x] 3.4 Test fee+slippage math, all four risk-limit scenarios, stop-loss close (RED→GREEN)

## 4. Market Data Providers

- [x] 4.1 Implement `BotTrader.MarketData` behaviour (`candles/2`)
- [x] 4.2 Implement `BotTrader.MarketData.YahooFinance` (chart API, `.SA` suffix for B3)
- [x] 4.3 Implement `BotTrader.MarketData.CoinGecko` (market_chart endpoint)
- [x] 4.4 Implement provider router by asset class with `{:error, :no_data, symbol}` on empty results
- [x] 4.5 Test with mocked HTTP: normalization, routing, error safety (RED→GREEN)

## 5. DeepSeek LLM Client

- [ ] 5.1 Implement `BotTrader.LLM` chat completion over OpenAI-compatible endpoint (configurable base URL/model, JSON mode)
- [ ] 5.2 Implement strict signal parsing: `action`, `confidence`, `rationale`, `target_weight`; invalid → `{:error, :invalid_signal}`
- [ ] 5.3 Implement confidence threshold gate (default 0.6)
- [ ] 5.4 Test valid signal, invalid JSON, low confidence (RED→GREEN)

## 6. Research Pipeline

- [ ] 6.1 Implement `BotTrader.Indicators`: RSI(14), EMA(20), EMA(50), daily return
- [ ] 6.2 Implement `BotTrader.Research` prompt builder (indicators + watchlist context) and qualitative section extraction
- [ ] 6.3 Implement hybrid universe: seed watchlist + LLM candidates capped per day (default 3)
- [ ] 6.4 Test indicator math and candidate cap (RED→GREEN)

## 7. Telegram Notifications

- [ ] 7.1 Implement `BotTrader.Telegram` send with one retry and failure logging
- [ ] 7.2 Implement per-transaction announcement formatting (symbol, side, quantity, fill, fee, cash/position summary)
- [ ] 7.3 Implement daily digest and run-failure alert
- [ ] 7.4 Test all announcement scenarios with mocked HTTP (RED→GREEN)

## 8. Daily Runner

- [ ] 8.1 Implement `mix bot.daily` orchestration: fetch → analyze → orders → state → report → Telegram (run-and-exit)
- [ ] 8.2 Implement Markdown + JSON report writing under `reports/`
- [ ] 8.3 Wire per-transaction announcements and digest into the pipeline
- [ ] 8.4 Test end-to-end run with mocked providers/LLM/Telegram (RED→GREEN)

## 9. Evaluation Gate

- [ ] 9.1 Implement `BotTrader.Evaluation` computing return %, max drawdown %, trade count from snapshots/trades
- [ ] 9.2 Implement verdict: PASS iff return ≥ 2% AND drawdown ≤ 5% AND trades ≥ 10 (env-configurable)
- [ ] 9.3 Implement day-30 digest verdict + stay-paper-no-broker behavior
- [ ] 9.4 Test all threshold scenarios (RED→GREEN)

## 10. Backtest

- [ ] 10.1 Implement `mix bot.backtest` replaying ~90 days of fixtures through indicators + portfolio engine
- [ ] 10.2 Enforce: no LLM calls, "indicator-only" label, never touches live state files
- [ ] 10.3 Test deterministic metrics and live-state isolation (RED→GREEN)

## 11. Railway Deployment

- [ ] 11.1 Add `railway.toml`: cron schedule `30 21 * * *`, start command `mix bot.daily`, volume mount `/data`
- [ ] 11.2 Document env vars and deployment steps in README
- [ ] 11.3 Validate: `mix compile` in prod env (`MIX_ENV=prod mix compile`)
