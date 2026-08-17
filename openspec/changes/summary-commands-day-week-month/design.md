# Summary Commands (day/week/month) Design

## Context

Bounded extension. Crystallized with the user (11 discovery answers): realized + current unrealized P&L, all trades in window, current open positions count, /month becomes summary-only (diary + gate footer dropped), /day keeps equity, split P&L lines, UTC-day / rolling-7d / rolling-30d windows, menu updated.

## Decisions

### D1: Store.period_summary(start_ts, now)
Returns `%{trades: n, realized: x, unrealized: y, open_positions: m}`:
- trades: count of all trade rows with `ts >= start_ts and ts <= now`
- realized: sum of `realized_pnl` over those trades (nil-safe)
- unrealized: sum over `Store.open_positions()` of `unrealized` (current, at last-known prices)
- open_positions: length of `Store.open_positions()`

### D2: Command windows
- /day: start = today UTC 00:00
- /week: start = now − 7×24h
- /month: start = now − 30×24h

### D3: Unified reply format
```
📅 Today: equity {fmt}
Trades: {n}
Realized: {sign}{fmt}
Unrealized: {sign}{fmt}
Open positions: {m}
```
/day includes the equity line; /week and /month omit it.

### D4: /month replaces diary
The month diary rows and the "Gate evaluation in N days" footer are removed. `ctx.month` becomes the summary map (diary query deleted from the poller ctx builder).

### D5: Menu
`@commands` list: /day "Today's trades, P&L and open positions", /week "Last 7 days summary", /month "Last 30 days summary".

## Risks / Trade-offs

- [Unrealized uses last-known prices] → consistent with /positions; no live HTTP.
- [Diary loss] → user chose summary-only; historical daily detail remains queryable in the DB.
