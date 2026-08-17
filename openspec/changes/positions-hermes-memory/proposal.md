# Positions Command + Hermes Memory Proposal

## Why

The user wants to see every position the bot has taken (`/positions` Telegram command, full history, paginated) and have Hermes absorb the bot's trade activity into its memory so future analysis knows the bot's track record. Currently there is no positions command (only /status showing open positions), trades live in SQLite but aren't exposed, and the analysis prompt's position placeholder is never filled.

## What Changes

- New `/positions` Telegram command: open-positions section (derived from the SQLite trades table: BUY minus SELL/CLOSE per symbol, unrealized P&L at last-known price) + full trade history paginated 20/page (`/positions`, `/positions 2`...), newest first, page indicator, out-of-range → "no such page".
- `BotTrader.Store.open_positions/1` (derive holdings from trades) and `list_trades_paginated/2`.
- `BotTrader.HermesMemory.append_trade/2` — atomic append of every executed trade (facts + signal rationale) to `HERMES_MEMORY_PATH` (default `/data/hermes_memory.md`), create-if-missing. Non-fatal: failure recorded in the run record, trading continues.
- Runner: after each executed trade, append to Hermes memory (joining trade → run → signal rationale); fill `rolling_summary.position` from open positions (fixes the nil placeholder).
- Command menu (`setMyCommands`) adds `/positions`.

## Capabilities

### New Capabilities
- `positions-command`: paginated /positions with open section + history, page indicator.
- `hermes-memory`: per-trade memory absorption with rationale, atomic append, non-fatal.

### Modified Capabilities
- `data-store`: open-position derivation and paginated trade listing.
- `telegram-commands`: /positions handler + menu registration.
- `research-analysis`: rolling summary position field populated.
