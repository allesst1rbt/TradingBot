# Fix LLM Degraded Alerts Tasks

## 1. LLM Retry

- [x] 1.1 `LLM.chat/2` retry loop: 3 attempts, backoff `[1000, 3000]` ms, injectable `retry_delays` opt, `retry: false` on Req
- [x] 1.2 Test: transient fail then success (2 attempts, ok); all fail (3 attempts, error) (RED→GREEN)

## 2. Alert Cap + Wording

- [x] 2.1 Store: `put_degraded_alert_ts/1`, `degraded_alert_due?/1` (rolling 24h, poller_state key)
- [x] 2.2 Runner: send degraded alert only when due; record ts
- [x] 2.3 `format_degraded_alert/1` — calm wording, no "FAILED"
- [x] 2.4 Test: first alerts, repeat silent, wording (RED→GREEN)

## 3. Close Open Changes

- [x] 3.1 Archive market-universe-watchlist, intraday-upgrade, trading-bot (archive-only)
- [x] 3.2 Structural: `openspec list` shows zero active changes
