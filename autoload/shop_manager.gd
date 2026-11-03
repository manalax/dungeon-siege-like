extends Node
## ShopManager: Shop layout, displays, storage, merchant level, reputation and customer spawning (GDD §2.12, §2.13).
##
## Stub (F-002). Implemented in F-075, F-090 – F-099.
## Planned public API:
##   storage: InventoryComponent, displays, layout (decor placements)
##   shop_profile (tag totals, appeal), merchant_level, merchant_xp, reputation[npc_type]
##   open_shop_phase(), spawn_customer()
##   emits EventBus.item_sold / item_bought / merchant_leveled / reputation_changed
