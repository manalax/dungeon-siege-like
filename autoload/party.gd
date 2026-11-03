extends Node
## Party: The deployed run party (max 6 incl. mules), leader, selection and formation (GDD §2.3, §2.7).
##
## Stub (F-002). Implemented in F-014, F-028, F-050, F-051.
## Planned public API:
##   members, leader, selection, deploy(members), set_leader(m)
##   select(m, additive), select_all(), formation, cycle_formation()
##   emits EventBus.party_changed / selection_changed / party_wiped
