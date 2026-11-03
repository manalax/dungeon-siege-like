extends Node
## Economy: Shared gold wallet, debt schedule & payments, weekly salary ledger (GDD §2.2, §2.3).
##
## Stub (F-002). Implemented in F-083, F-084.
## Planned public API:
##   gold: int, add_gold(n), spend_gold(n) -> bool
##   debt_due_this_week() -> int, pay_debt_early(n), run_settlement()
##   weekly_salary_total() -> int
##   emits EventBus.gold_changed / debt_paid
