# Fix LLM Degraded Alerts Design

## Context

Crystallized with the user (11 discovery answers): root cause verified in the container (Go endpoint throttling → Req retries exhaust → degraded alert on most runs). Decisions: same-model 2 retries with backoff inside LLM.chat; one degraded alert per rolling 24h; calmer wording; archive the 3 remaining open changes.

## Decisions

### D1: Retry in LLM.chat
`LLM.chat/2` wraps the Req.post in a retry loop: up to 3 attempts total (initial + 2), with 1s and 3s sleeps between attempts, on any non-200 or transport error. Returns `{:ok, body}` on first success; `{:error, :http_error}` after all attempts. Injectable `retry_delays` opt for tests (default `[1000, 3000]`). Req's own retry remains disabled (`retry: false`) to keep timing deterministic.

### D2: Degraded alert cap (rolling 24h)
`Store.put_degraded_alert_ts/1` + `Store.degraded_alert_due?/1` backed by a `poller_state` key storing the last alert timestamp. `degraded_alert_due?` is true when no alert in the last 24h (rolling). The runner sends the alert only when due, then records the timestamp.

### D3: Wording
`format_failure_alert` (or a new `format_degraded_alert`) produces "⚠️ Analysis degraded for: X — retrying next run". The "run FAILED" prefix is gone; run-level failures (corrupt state etc.) keep their existing wording.

### D4: Closing open changes
After apply + deploy, archive `market-universe-watchlist`, `intraday-upgrade`, `trading-bot` (archive-only, no commits/push) — same flow as positions-hermes-memory.

## Risks / Trade-offs

- [Retries add latency] → max ~4s extra per failed symbol; acceptable at 5-min cadence.
- [Alert cap hides persistent failure] → the run record still notes degradations; the daily alert still fires at least once.
- [Rolling 24h vs UTC day] → user chose rolling.
