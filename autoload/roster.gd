extends Node
## Roster: Every employed adventurer and mule, the recruitment pool, and injuries (GDD §2.3).
##
## Stub (F-002). Implemented in F-030, F-074, F-085.
## Planned public API:
##   members: Array[RecruitInstance], hire(candidate), dismiss(member)
##   available_for_deploy() -> Array (excludes injured), injure(member, days)
##   recruitment_pool, reroll_pool()
