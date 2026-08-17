# Summary Commands Apply Checklist

**Change:** `summary-commands-day-week-month`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/summary-commands-day-week-month/`
**Implementation plan:** `openspec/changes/summary-commands-day-week-month/tasks.md`
**Status:** planned

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Store period summary

- [ ] Complete
- **Acceptance behavior:** `Store.period_summary(start, now)` → `%{trades: n, realized: x, unrealized: y, open_positions: m}`; trades/realized bounded by `[start, now]`; realized nil-safe; unrealized = sum of open positions' unrealized.
- **RED test:** `test/bot_trader/store_test.exs` — `"period summary bounded window"`, `"period summary unrealized from open positions"`
- **RED command:** `mix test test/bot_trader/store_test.exs`
- **Expected RED:** `Store.period_summary/2` undefined.
- **GREEN scope:** `lib/bot_trader/store.ex` — `period_summary/2` (window query, coalesce sum realized, reuse open_positions).
- **GREEN command:** `mix test test/bot_trader/store_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** one query for trades+realized; unrealized reuses open_positions.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.2; plan N/A
- **Atomic commit:** `feat: add period summary aggregate to store yarr`
- **Evidence:** `<filled by /apply>`

### 2. Commands (day/week/month unified)

- [ ] Complete
- **Acceptance behavior:** /day replies equity + Trades/Realized/Unrealized/Open positions (UTC day window); /week same without equity (rolling 7d); /month summary-only (rolling 30d, no diary/gate footer); menu includes /week and updated descriptions.
- **RED test:** `test/bot_trader/telegram_commands_test.exs` — `"day reply unified"`, `"week reply no equity"`, `"month summary only"`; `test/bot_trader/telegram_poller_test.exs` — `"menu includes week"`
- **RED command:** `mix test test/bot_trader/telegram_commands_test.exs test/bot_trader/telegram_poller_test.exs`
- **Expected RED:** /week falls to no_reply; /month still contains diary/gate.
- **GREEN scope:** `lib/bot_trader/telegram/commands.ex` (`/week` clause; unified formatter shared by the three; `/month` diary removed), `lib/bot_trader/telegram/poller.ex` (ctx day/week/month summaries; menu `@commands`).
- **GREEN command:** `mix test test/bot_trader/telegram_commands_test.exs test/bot_trader/telegram_poller_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** one `format_summary/2` used by all three; window math helpers pure.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.6; plan N/A
- **Atomic commit:** `feat: unify day week month summary commands yarr`
- **Evidence:** `<filled by /apply>`

### 3. Deploy

- [ ] Complete
- **Acceptance behavior:** regression green, prod compile, deploy completes.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** README command descriptions update.
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** env/docs consistent.
- **Structural validation:** prod compile exits 0.
- **Source checkboxes:** OpenSpec 3.1; plan N/A
- **Atomic commit:** `chore: update docs for summary commands yarr`
- **Evidence:** `<filled by /apply>`

## Completion Gate

- [ ] Every item has passing validation evidence
- [ ] OpenSpec task checkboxes synchronized
- [ ] Regression suite passes
- [ ] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [ ] No unrelated files
