# Positions + Hermes Memory Apply Checklist

**Change:** `positions-hermes-memory`
**Current branch:** `<observed-by-apply; not changed>`
**OpenSpec change root:** `openspec/changes/positions-hermes-memory/`
**Implementation plan:** `openspec/changes/positions-hermes-memory/tasks.md`
**Status:** complete

## Validation Baseline

- Focused tests: `mix test <test-file>`
- Regression tests: `mix test`
- Lint: `mix compile --warnings-as-errors && mix format --check-formatted`
- Build: `MIX_ENV=prod mix compile`

## Apply Items

### 1. Store: open positions + pagination

- [x] Complete
- **Acceptance behavior:** BUY BTC 0.1@100 + CLOSE BTC 0.04@110 + last signal price 120 → open position BTC qty 0.06, entry 100, unrealized 1.2. Fully-closed symbols absent. 45 trades, page 3 of 20 → 5 oldest trades, total pages 3. `note_run` updates the run row.
- **RED test:** `test/bot_trader/store_test.exs` — `"open positions derived from trades"`, `"fully closed excluded"`, `"pagination math"`, `"run note recorded"`
- **RED command:** `mix test test/bot_trader/store_test.exs`
- **Expected RED:** `Store.open_positions/1` undefined.
- **GREEN scope:** `lib/bot_trader/store.ex` — `open_positions/1` (aggregate trades, join last signal price via `get_last_signal`), `list_trades_paginated/3`, `note_run/2`.
- **GREEN command:** `mix test test/bot_trader/store_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** aggregation is pure SQL/one pass; no per-symbol N+1 beyond last-signal lookup.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 1.1–1.4; plan N/A
- **Atomic commit:** `feat: derive open positions and paginate trades in store yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 2. Hermes memory writer

- [x] Complete
- **Acceptance behavior:** `HermesMemory.append_trade(trade, rationale)` writes a markdown entry (facts + rationale) atomically (tmp+rename) to `HERMES_MEMORY_PATH` (default `/data/hermes_memory.md`), creating the file if missing; no `.tmp` remains.
- **RED test:** `test/bot_trader/hermes_memory_test.exs` — `"appends trade with rationale"`, `"creates file when missing"`, `"atomic write leaves no tmp"`
- **RED command:** `mix test test/bot_trader/hermes_memory_test.exs`
- **Expected RED:** `BotTrader.HermesMemory` undefined.
- **GREEN scope:** `lib/bot_trader/hermes_memory.ex` (append_trade/2 with opts[:path] override, File.mkdir_p + tmp write + rename, entry format with rationale line), Config `hermes_memory_path/0`.
- **GREEN command:** `mix test test/bot_trader/hermes_memory_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** entry formatting is a pure `format_entry/2`; write path is one function.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 2.1–2.3; plan N/A
- **Atomic commit:** `feat: add hermes memory writer with atomic append yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 3. /positions command

- [x] Complete
- **Acceptance behavior:** `/positions` replies open section + history page 1/2 (20 newest); `/positions 2` → page 2/2; `/positions 9` (out of range) → "no such page"; no open positions → "No open positions" + history; menu registers positions.
- **RED test:** `test/bot_trader/telegram_commands_test.exs` — `"positions page one with open section"`, `"positions page two"`, `"positions out of range"`, `"positions no open"`; poller test — `"menu includes positions"`
- **RED command:** `mix test test/bot_trader/telegram_commands_test.exs test/bot_trader/telegram_poller_test.exs`
- **Expected RED:** `/positions` dispatch falls to `{:no_reply, _}`.
- **GREEN scope:** `lib/bot_trader/telegram/commands.ex` (dispatch clauses for `"/positions"` and `"/positions N"`; formatting helpers), `lib/bot_trader/telegram/poller.ex` (ctx positions data + `@commands` list + `positions_page` handling in ctx_builder).
- **GREEN command:** `mix test test/bot_trader/telegram_commands_test.exs test/bot_trader/telegram_poller_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** reply formatting pure functions; page parsing via regex once.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 3.1–3.4; plan N/A
- **Atomic commit:** `feat: add paginated positions telegram command yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 4. Runner wiring

- [x] Complete
- **Acceptance behavior:** Each executed trade appends facts+rationale to Hermes memory; memory failure → run completes, trade persists, run record notes it. `rolling_summary` position reflects open holdings (or "none" when flat).
- **RED test:** `test/bot_trader/runner_test.exs` — `"trade absorbed into hermes memory"`, `"memory failure non-fatal with run note"`, `"rolling summary shows open position"`, `"rolling summary none when flat"`
- **RED command:** `mix test test/bot_trader/runner_test.exs`
- **Expected RED:** runner doesn't call HermesMemory; rolling summary position nil.
- **GREEN scope:** `lib/bot_trader/runner.ex` (after executed trades: resolve rationale from current signals, `HermesMemory.append_trade` in try/catch, `Store.note_run` on failure; `rolling_summary/1` uses `Store.open_positions/1`).
- **GREEN command:** `mix test test/bot_trader/runner_test.exs`
- **Regression validation:** `mix test`
- **REFACTOR check:** memory append isolated in one helper; rationale lookup reuses signals list.
- **Structural validation:** N/A
- **Source checkboxes:** OpenSpec 4.1–4.3; plan N/A
- **Atomic commit:** `feat: absorb trades into hermes memory and fill position context yarr`
- **Evidence:** RED→GREEN→regression green→committed.

### 5. Deploy

- [x] Complete
- **Acceptance behavior:** README documents /positions + HERMES_MEMORY_PATH; `MIX_ENV=prod mix compile` exits 0; deploy completes.
- **RED test:** N/A (structural)
- **RED command:** N/A
- **Expected RED:** N/A
- **GREEN scope:** README updates (command list + env table).
- **GREEN command:** `MIX_ENV=prod mix compile`
- **Regression validation:** `mix test`
- **REFACTOR check:** env names match Config defaults.
- **Structural validation:** prod compile exits 0.
- **Source checkboxes:** OpenSpec 5.1; plan N/A
- **Atomic commit:** `chore: document positions command and memory path yarr`
- **Evidence:** RED→GREEN→regression green→committed.

## Completion Gate

- [x] Every item has passing validation evidence
- [x] OpenSpec task checkboxes synchronized
- [x] Regression suite passes
- [x] `mix compile --warnings-as-errors && mix format --check-formatted` completed
- [x] No unrelated files
