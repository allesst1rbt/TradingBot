# Fix LLM Degraded Alerts Apply Checklist

**Change:** `fix-llm-degraded-alerts`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/fix-llm-degraded-alerts/`
**Implementation plan:** `openspec/changes/fix-llm-degraded-alerts/tasks.md`
**Status:** planned

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. LLM retry

- [ ] Complete
- **Acceptance behavior:** `LLM.chat/2` makes up to 3 attempts with backoff (default 1s/3s, injectable `retry_delays`) on non-200/transport errors, `retry: false` on Req; returns `{:ok, body}` on first success, `{:error, :http_error}` after all attempts.
- **RED test:** `test/bot_trader/llm_test.exs` — `"retries transient failure then succeeds"`, `"returns error after all retries"`
- **RED command:** `mix test test/bot_trader/llm_test.exs`
- **Expected RED:** single-attempt behavior — the two-attempt assertion fails (only 1 attempt made).
- **GREEN scope:** `lib/bot_trader/llm.ex` — `chat/2` retry loop (attempts count, `Process.sleep` on delays, injectable `retry_delays` opt), keep `retry: false` in Req opts.
- **GREEN command:** `mix test test/bot_trader/llm_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** retry loop is a small private function; no duplicated Req option building.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.2; plan N/A
- **Atomic commit:** `fix: retry llm calls with backoff before degrading yarr`
- **Evidence:** `<filled by /apply>`

### 2. Alert cap + wording

- [ ] Complete
- **Acceptance behavior:** one degraded alert per rolling 24h (Store-backed ts key); calm wording "⚠️ Analysis degraded for: X — retrying next run" with no "FAILED".
- **RED test:** `test/bot_trader/runner_test.exs` — `"degraded alert sent once per rolling 24h"`, `"degraded alert wording calm"`; `test/bot_trader/store_test.exs` — `"degraded alert due window"`
- **RED command:** `mix test test/bot_trader/runner_test.exs test/bot_trader/store_test.exs`
- **Expected RED:** alerts on every degraded run; wording contains FAILED.
- **GREEN scope:** `lib/bot_trader/store.ex` (`put_degraded_alert_ts/1`, `degraded_alert_due?/1` on poller_state key with rolling 24h), `lib/bot_trader/runner.ex` (due-check before alert + record ts), `lib/bot_trader/telegram.ex` (`format_degraded_alert/1`).
- **GREEN command:** `mix test test/bot_trader/runner_test.exs test/bot_trader/store_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** rolling-window logic shared with budget alert pattern; wording formatting pure.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.4; plan N/A
- **Atomic commit:** `fix: cap degraded alerts to once per day with calm wording yarr`
- **Evidence:** `<filled by /apply>`

### 3. Close open changes

- [ ] Complete
- **Acceptance behavior:** `openspec list` shows zero active changes; all three archives exist under `openspec/changes/archive/YYYY-MM-DD-<name>/`.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** `mv` each change root into `openspec/changes/archive/2026-08-16-<name>/` (no overwrite; preserve `.openspec.yaml`).
- **GREEN command:** `openspec list`
- **Regression validation:** `mix test`
- **REFACTOR check:** archive names date-prefixed, unique.
- **Structural validation:** `openspec list` shows zero active changes.
- **Source checkboxes:** OpenSpec 3.1–3.2; plan N/A
- **Atomic commit:** `chore: archive completed changes yarr` (after approval)
- **Evidence:** `<filled by /apply>`

## Completion Gate

- [ ] Every item has passing validation evidence
- [ ] OpenSpec task checkboxes synchronized
- [ ] Regression suite passes
- [ ] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [ ] No unrelated files
