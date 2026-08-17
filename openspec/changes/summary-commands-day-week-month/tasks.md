# Summary Commands Tasks

## 1. Store period summary

- [x] 1.1 `Store.period_summary/2` — window-bounded trades, realized sum, current unrealized + open count
- [x] 1.2 Test window bounds, realized nil-safety, unrealized sum (RED→GREEN)

## 2. Commands

- [x] 2.1 `/day` unified reply (equity + trades + realized + unrealized + open)
- [x] 2.2 `/week` unified reply (no equity)
- [x] 2.3 `/month` summary-only (no diary, no gate footer)
- [x] 2.4 Poller ctx: period summaries for day/week/month windows
- [x] 2.5 Menu descriptions updated (add /week)
- [x] 2.6 Test all reply shapes + menu (RED→GREEN)

## 3. Deploy

- [x] 3.1 Regression, prod compile, deploy
