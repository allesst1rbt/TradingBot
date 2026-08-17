# Positions Command + Hermes Memory Design

## Context

Bounded extension of the live intraday bot. 14 discovery questions resolved with the user: full-history paginated /positions; positions derived from the SQLite trades table; every trade absorbed into Hermes memory (facts + rationale); immediate per-trade writes; non-fatal failures; open section + history reply; last-known pricing; append unbounded; both Hermes memory AND the live prompt get position data; silent absorption; memory on the /data volume.

## Decisions

### D1: Open positions derived from trades
`Store.open_positions(now)` aggregates the trades table: per symbol, qty = sum(BUY qty) − sum(SELL/CLOSE qty); avg entry = weighted mean of BUY prices; unrealized P&L = qty × (last_known_price − avg_entry) where last-known price comes from the most recent signal row for that symbol (no HTTP). Positions with qty ≤ 0 are excluded.

### D2: Paginated history
`Store.list_trades_paginated(page, page_size \\ 20)` — newest first by id, returns `{trades, total_pages}`. `/positions` → page 1; `/positions N` → page N; N out of range → "no such page".

### D3: /positions reply
Open section first ("Open now") with symbol, qty, avg entry, unrealized at last-known; then "History (page P/N)" with one compact line per trade (symbol, side, qty, price, fee, P&L, reason, ts). Empty open section → "No open positions".

### D4: Hermes memory absorption
`BotTrader.HermesMemory.append_trade(trade, rationale, opts)`:
- path = `HERMES_MEMORY_PATH` (default `/data/hermes_memory.md`)
- atomic append: write to `path.tmp`, rename; create parent dirs + file if missing
- entry format (Hermes-readable markdown):
  ```
  - Trade {ts}: {SIDE} {symbol} qty={qty} price={price} fee={fee} pnl={realized} reason={reason}
    Rationale: {signal rationale}
  ```
- returns `:ok | {:error, reason}` — caller (runner) treats failure as non-fatal: run record notes it, trading continues.

### D5: Runner wiring
After each executed trade: look up the signal rationale for that symbol in the current run (or last signal row), call `HermesMemory.append_trade`. Wrap in try/catch — never crashes the run. Failure is recorded on the run row (extend finish status or a note field — use `runs.note` via a lightweight column? Simplest: log through the existing run record by appending to `runs` via an update; use `Store.note_run(run, note)`).

### D6: Rolling summary position
`Store.open_positions(now)` reused by `runner.rolling_summary(symbol)`: position = first open position for the symbol → `%{quantity: qty, entry_price: avg_entry}` or nil. `Research.build_rolling_summary` already handles `%{quantity: qty}`.

### D7: Menu registration
`Poller` command list adds `%{command: "positions", description: "Trade history and open positions"}`.

## Risks / Trade-offs

- [Memory file growth] → append unbounded per user choice; Hermes manages compaction.
- [Last-known pricing staleness] → acceptable; no live HTTP to avoid Yahoo 429s.
- [Memory write failure] → non-fatal by design; verified by test.
- [Large histories] → pagination bounds reply size (20/page).

## Migration

No schema changes (trades/signals tables exist). Deploy: new code path active; memory file created on first trade after deploy.
