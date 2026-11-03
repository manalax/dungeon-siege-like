extends Node
## Calendar: Day/phase tracking, day type (run vs town), advancing time, weekly settlement trigger (GDD §2.2).
##
## Stub (F-002). Implemented in F-082.
## Planned public API:
##   day: int, phase (Morning/Afternoon/Evening), day_type (unspent/town/run)
##   advance_phase(), end_day(), start_run_day(), is_settlement_day() -> bool
##   emits EventBus.day_started / phase_changed / weekly_settlement
