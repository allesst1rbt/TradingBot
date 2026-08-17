# Positions + Hermes Memory Tasks

## 1. Store: open positions + pagination

- [x] 1.1 `Store.open_positions/1` — derive holdings (BUY − SELL/CLOSE, weighted avg entry, unrealized at last-known signal price), exclude qty ≤ 0
- [x] 1.2 `Store.list_trades_paginated/3` — newest-first, page + total pages
- [x] 1.3 `Store.note_run/2` — record a note on the run row
- [x] 1.4 Test derivation, exclusion, pagination math, run note (RED→GREEN)

## 2. Hermes memory writer

- [x] 2.1 `BotTrader.HermesMemory.append_trade/2` — atomic append (tmp+rename), create-if-missing, facts + rationale entry format
- [x] 2.2 Config `HERMES_MEMORY_PATH` (default `/data/hermes_memory.md`)
- [x] 2.3 Test append with rationale, file-created, atomicity (RED→GREEN)

## 3. /positions command

- [x] 3.1 `Commands.dispatch("/positions", ctx)` + `/positions N` — open section + paginated history + page indicator + "no such page"
- [x] 3.2 Poller ctx_builder: positions data (open + page)
- [x] 3.3 Menu registration (setMyCommands includes positions)
- [x] 3.4 Test dispatch pages, out-of-range, no-open, menu (RED→GREEN)

## 4. Runner wiring

- [x] 4.1 Runner appends each executed trade to Hermes memory (facts + signal rationale); non-fatal, run note on failure
- [x] 4.2 `rolling_summary` position filled from `Store.open_positions/1`
- [x] 4.3 Test memory append on trade, failure non-fatal, rolling summary position (RED→GREEN)

## 5. Deploy

- [x] 5.1 README env + command docs; prod compile; deploy
