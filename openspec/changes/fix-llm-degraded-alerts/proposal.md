# Fix LLM Degraded Alerts Proposal

## Why

The bot sends "⚠️ bot_trader run FAILED: LLM degraded for: X" on most runs. Verified root cause: the opencode-go endpoint chronically throttles us (5xx/429 under the 5-min × 7-symbol call volume), Req's built-in retries exhaust, and the run degrades. The alert fires every run, the "run FAILED" wording is misleading (runs complete), and the user wants the noise gone.

## What Changes

- `BotTrader.LLM.chat/2` retries the same model twice with short backoff (1s, 3s) on transient failure before returning `{:error, :http_error}`.
- Runner degraded alert is capped at one per rolling 24h (timestamp key in `poller_state`), reset rolling.
- Alert wording changes from "⚠️ bot_trader run FAILED: LLM degraded for: X" to "⚠️ Analysis degraded for: X — retrying next run".
- Close all remaining open changes (market-universe-watchlist, intraday-upgrade, trading-bot) via archive-only after this change lands.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `research-analysis`: LLM call retry behavior.
- `telegram-notifications`: degraded-alert cap + wording.
