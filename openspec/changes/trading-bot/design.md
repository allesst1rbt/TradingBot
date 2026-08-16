# Trading Bot Design

## Context

Greenfield project at `/Users/carlos/dev/bot_trader`. The user wants an autonomous trading bot powered by DeepSeek v4 pro (via their opencode-go API key, OpenAI-compatible HTTP), covering BR stocks (B3), US stocks, and crypto. It runs paper trading on R$ 1.000 virtual capital for 30 days; if the evaluation gate passes (return ≥ 2%, max drawdown ≤ 5%, ≥ 10 trades), the bot is authorized to move to real money — but no broker exists yet, so real execution stays an unimplemented adapter interface.

Constraints decided with the user: Elixir (not Python), plain Mix/OTP app (no Phoenix), JSON files for state (no DB), free market data now with pluggable providers later, swing (daily) cadence, fully autonomous execution, hard risk limits, Telegram as the sole reporting channel with **every transaction announced**, Railway (Hobby plan) as deployment target, brief backtest before the paper period.

## Goals / Non-Goals

**Goals:**
- Daily autonomous pipeline: fetch → analyze (DeepSeek) → paper trade → report → Telegram.
- Honest paper P&L: fees + slippage simulated, restart-safe state.
- Per-transaction Telegram announcements + daily digest.
- 30-day go/no-go gate with hard numbers.
- Railway cron deployment with persistent volume.
- Brief backtest sanity check before paper period starts.

**Non-Goals:**
- No real broker integration yet (adapter interface only, stub).
- No web dashboard; Telegram + JSON/Markdown files are the only outputs.
- No intraday trading, no high-frequency execution.
- No backtesting engine beyond the brief daily-candle replay.
- No user-approval flow for trades (fully autonomous).

## Decisions

### D1: Plain Mix/OTP app, run-and-exit CLI commands

The bot is not a long-running server. Railway cron requires tasks to terminate; every run is a fresh boot that rebuilds state from JSON. The daily pipeline is `mix bot.daily` (single run, exits). Same command runs locally.

**Alternatives rejected:** GenServer scheduler inside a 24/7 app (Railway cron skips overlapping runs and bills idle time; in-code schedulers are explicitly discouraged by Railway for this shape); Phoenix (no web UI needed).

### D2: JSON state files on a Railway volume

State lives in `$BOT_STATE_DIR` (default `./data`, mounted `/data` on Railway, 5GB Hobby volume). Files: `portfolio.json`, `trades.json`, `snapshots.json`, `reports/YYYY-MM-DD.md`. Atomic writes (write-temp-then-rename). Portfolio is a pure functional core: `Portfolio.apply(portfolio, order)` returns a new portfolio; the State module persists it.

**Alternatives rejected:** SQLite/Ecto (user chose plain JSON); in-memory only (not restart-safe, Railway recreates containers every cron run).

### D3: Pluggable market data behaviour

`BotTrader.MarketData` behaviour: `candles(symbol, range)` returning normalized `%{symbol, timeframe, candles: [{ts, open, high, low, close, volume}]}`. Providers: `YahooFinance` (chart API `query1.finance.yahoo.com/v8/finance/chart/`, B3 via `.SA` suffix), `CoinGecko` (`/coins/{id}/market_chart`). Provider selection by asset class config.

**Alternatives rejected:** yfinance Python lib (would require Python runtime inside Elixir); paid APIs (user chose free now, pluggable later).

### D4: DeepSeek via OpenAI-compatible HTTP, JSON signals

`BotTrader.LLM` uses Req to POST `/chat/completions` against a configurable `DEEPSEEK_BASE_URL` (default `https://api.deepseek.com/v1`, user may point to opencode-go endpoint), model default `deepseek-v4-pro`. Requests use `response_format: {"type": "json_object"}` and a strict JSON schema for signals: `{action: BUY|SELL|HOLD|CLOSE, confidence: 0-1, rationale: string, target_weight: number}`. Invalid JSON → no trade (fail safe), error logged in report.

**Alternatives rejected:** opencode CLI subagent per analysis (user explicitly chose direct API); local Ollama models (user chose DeepSeek).

### D5: Research pipeline = indicators + LLM, hybrid universe

Deterministic Elixir computes RSI(14), EMA(20/50), and daily return from candles. These + watchlist context (last close, position, allocation) feed the LLM prompt. LLM may also request qualitative research: the prompt includes a news-summary section the LLM fills from its own knowledge of recent events, kept as a qualitative section of the report. Universe = seed watchlist (`config/watchlist.json`) + candidates the LLM proposes, capped at N per day.

**Alternatives rejected:** pure-LLM qualitative only (unverifiable, expensive); pure-technical only (user asked for news/fundamentals + qualitative reports).

### D6: Paper engine with fees, slippage, hard risk limits

Order execution applies fee (crypto 0.1% of notional, US $1 flat, B3 R$5 flat) and slippage (0.05% adverse price). Risk engine enforces: max 25% of capital per position, max 6 concurrent positions, 5% stop-loss (checked on each run; breach → auto-close at open price with slippage), 3% max daily loss (blocks new buys for the day). R$ 1.000 starting capital. All limits configurable via env.

**Alternatives rejected:** zero-fee simulation (flatters results, invalidates gate); LLM-sized positions without hard caps (risk).

### D7: Telegram as single channel, per-transaction + digest

`BotTrader.Telegram` sends two message types: (a) immediate per-transaction announcements — order opened/closed, fill price, fee, resulting position/cash; (b) end-of-run digest — P&L today, positions, risk status, gate countdown. Uses Bot API `sendMessage`; token + chat id from env; failures logged and retried once.

**Alternatives rejected:** email, web dashboard (user chose Telegram).

### D8: Evaluation gate with hard numbers

`BotTrader.Evaluation` computes over the 30-day window: total return %, max drawdown %, trade count. PASS iff return ≥ 2% AND max drawdown ≤ 5% AND trades ≥ 10. Verdict emitted in the day-30 digest. On PASS: since the broker adapter is unimplemented, the bot stays paper and notifies "GO — attach broker to enable real mode". Configurable thresholds.

**Alternatives rejected:** subjective human call (user chose hard numbers); benchmark-relative (user chose return/drawdown/trade-count).

### D9: Railway cron + Nixpacks + volume

`railway.toml` defines one cron service: start command `mix bot.daily`, schedule `30 21 * * *` UTC (18:30 BRT, after B3 17:00 BRT and US 16:00 ET closes), volume mounted at `/data`. Nixpacks auto-detects Elixir via `mix.exs` (MIX_ENV=prod). Secrets as Railway env vars: `DEEPSEEK_API_KEY`, `DEEPSEEK_BASE_URL`, `DEEPSEEK_MODEL`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `BOT_STATE_DIR=/data`.

**Alternatives rejected:** local Mac launchd as primary (user chose Railway); Dockerfile (Nixpacks native Elixir support is sufficient).

### D10: Brief backtest only

`mix bot.backtest` replays ~90 days of daily candles through the same signal + portfolio pipeline (no LLM network calls during backtest — signals come from the deterministic indicator rules, with a clearly-labeled "indicator-only" flag in the report, since historical LLM analysis is not reproducible). Prints return, max drawdown, trade count.

**Alternatives rejected:** full backtesting engine with walk-forward optimization (out of scope for a sanity check).

## Risks / Trade-offs

- [DeepSeek endpoint specifics unknown] → All LLM config (base URL, model, key) is env-driven; default to `api.deepseek.com/v1`, switch base URL without code changes.
- [BR stock data quality on free Yahoo API (delays, gaps)] → `.SA` tickers validated in a smoke test; report flags missing data instead of trading on stale candles.
- [Railway cron UTC + no sub-5min scheduling] → Only daily runs needed; schedule 21:30 UTC covers both closes year-round.
- [LLM signal quality varies] → Confidence threshold minimum (default 0.6) before any BUY/SELL executes; HOLD otherwise.
- [Telegram outage loses announcements] → One retry + the daily digest and JSON reports remain the audit trail.
- [Paper P&L ≠ real P&L (liquidity, spread)] → Fees+slippage modeled; gate thresholds set above fee drag; real mode still requires broker adapter with its own dry-run.
- [State file corruption] → Atomic write-temp-rename; on parse failure the run aborts with a Telegram alert, never overwrites good state.

## Migration Plan

1. Greenfield: `mix new` scaffold, local dev with `mix bot.daily`.
2. Railway: create project → add volume at `/data` → deploy service with cron schedule → set env vars → first monitored run.
3. Rollback: keep `BOT_STATE_DIR` portable; delete Railway service and run locally; state JSON is the migration unit (copy `data/` between environments).

## Open Questions

- Exact DeepSeek endpoint URL/format for the opencode-go key — resolved at first run via env config, no code change.
- Seed watchlist contents — `config/watchlist.json` editable by user; defaults provided (PETR4, VALE3, ITUB4, AAPL, MSFT, BTC, ETH).
