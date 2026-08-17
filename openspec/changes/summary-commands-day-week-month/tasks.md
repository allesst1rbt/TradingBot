# Summary Commands Tasks

## 1. Store period summary

- [ ] 1.1 `Store.period_summary/2` — window-bounded trades, realized sum, current unrealized + open count
- [ ] 1.2 Test window bounds, realized nil-safety, unrealized sum (RED→GREEN)

## 2. Commands

- [ ] 2.1 `/day` unified reply (equity + trades + realized + unrealized + open)
- [ ] 2.2 `/week` unified reply (no equity)
- [ ] 2.3 `/month` summary-only (no diary, no gate footer)
- [ ] 2.4 Poller ctx: period summaries for day/week/month windows
- [ ] 2.5 Menu descriptions updated (add /week)
- [ ] 2.6 Test all reply shapes + menu (RED→GREEN)

## 3. Deploy

- [ ] 3.1 Regression, prod compile, deploy
