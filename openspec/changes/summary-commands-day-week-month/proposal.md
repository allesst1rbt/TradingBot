# Summary Commands (day/week/month) Proposal

## Why

The user wants /day, /week, and /month to answer three questions per period: how many trades, how much money earned or lost, and how many open positions. /day and /month exist but with different shapes (equity+pnl+trades; 30-day diary). /week doesn't exist. Unify all three into one summary format.

## What Changes

- New `BotTrader.Store.period_summary/2` aggregate: window-bounded trade count, realized P&L (sum of closed-trade realized_pnl), current unrealized (sum of open positions' unrealized), current open positions count.
- `/day` (UTC day), `/week` (rolling 7×24h), `/month` (rolling 30×24h) all reply with the unified summary: equity (day only), trades count, realized line, unrealized line, open positions count.
- `/month` summary replaces the 30-day diary; the gate countdown footer is dropped.
- Telegram command menu descriptions updated (add /week; reword /day and /month).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `data-store`: period_summary aggregate.
- `telegram-commands`: unified /day /week /month summaries + menu.
