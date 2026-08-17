# Fix LLM Degraded Alerts Tasks

## 1. LLM Retry

- [ ] 1.1 `LLM.chat/2` retry loop: 3 attempts, backoff `[1000, 3000]` ms, injectable `retry_delays` opt, `retry: false` on Req
- [ ] 1.2 Test: transient fail then success (2 attempts, ok); all fail (3 attempts, error) (RED→GREEN)

## 2. Alert Cap + Wording

- [ ] 2.1 Store: `put_degraded_alert_ts/1`, `degraded_alert_due?/1` (rolling 24h, poller_state key)
- [ ] 2.2 Runner: send degraded alert only when due; record ts
- [ ] 2.3 `format_degraded_alert/1` — calm wording, no "FAILED"
- [ ] 2.4 Test: first alerts, repeat silent, wording (RED→GREEN)

## 3. Close Open Changes

- [ ] 3.1 Archive market-universe-watchlist, intraday-upgrade, trading-bot (archive-only)
- [ ] 3.2 Structural: `openspec list` shows zero active changes
