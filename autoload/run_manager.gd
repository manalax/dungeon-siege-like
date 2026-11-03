extends Node
## RunManager: Run lifecycle, run gold, found-this-run tracking, wipe/extract resolution, discovered extraction points (GDD §2.10).
##
## Stub (F-002). Implemented in F-070 – F-076.
## Planned public API:
##   state (PREP/ACTIVE/EXTRACTED/WIPED/ABANDONED/SUMMARY), start_run(party, start_point)
##   run_gold, extract(), on_party_wiped(), discovered_extraction_points
##   emits EventBus.run_started / run_ended / extraction_point_discovered
