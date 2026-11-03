extends Node
## SaveManager: Town-only JSON save/load, versioned with migration hooks (GDD §2.15, §7.9).
##
## Stub (F-002). Implemented in F-076.
## Planned public API:
##   save(slot), load(slot), autosave(), list_slots()
##   mark_run_in_progress(), resolve_abandoned_run_on_load()
