extends Node
## EventBus: the canonical global signal contract (GDD §3.2, F-005).
##
## Rules:
## - Emit a signal only from its documented owner: `EventBus.<signal>.emit(...)`.
## - Listeners connect to EventBus, never directly to each other.
## - Adding a signal means adding it here AND to the GDD F-005 list; tests/test_event_bus.gd
##   fails on any signal missing from its contract table.
## Argument types: actors are Node, ids StringName, money/levels/days/enums int.
## `item` args are Object until ItemInstance exists (F-040), then tighten to ItemInstance.

@warning_ignore_start("unused_signal")

# --- App ----------------------------------------------------------------------

## Game state changed. Args are Game.State values. Emitted by Game.set_state() (F-002).
signal game_state_changed(old_state: int, new_state: int)

# --- Combat & party -----------------------------------------------------------

## An actor (party member or monster) died. killer may be null. Emitted by combat/death (F-024).
signal actor_died(actor: Node, killer: Node)
## An actor picked up an item from the ground. Emitted by ground-item pickup (F-044).
signal item_picked_up(actor: Node, item: Object)
## A party member reached a new level. Emitted by LevelComponent (F-030).
signal member_leveled(actor: Node, level: int)
## Every deployed non-mule member is dead. Emitted once by Party (F-028).
signal party_wiped()
## The deployed party's membership or leader changed. Emitted by Party (F-050).
signal party_changed()
## The selected party members changed. Emitted by Party (F-014).
signal selection_changed()
## Tactical pause turned on/off (dungeon only). Emitted by Game (F-017).
signal tactical_pause_toggled(paused: bool)

# --- Dungeon & runs -----------------------------------------------------------

## A dungeon chunk finished loading. id = ChunkData.id. Emitted by WorldStreamer (F-062).
signal chunk_loaded(id: StringName)
## A dungeon chunk was unloaded. Emitted by WorldStreamer (F-062).
signal chunk_unloaded(id: StringName)
## A run began at the given start point (ExtractionPointData.id). Emitted by RunManager (F-070).
signal run_started(start_point_id: StringName)
## A run ended. result = RunManager result enum (EXTRACTED / WIPED / ABANDONED, defined in F-070).
## Emitted by RunManager (F-070).
signal run_ended(result: int)
## An extraction point was discovered (persists across runs). Emitted by RunManager (F-071).
signal extraction_point_discovered(id: StringName)

# --- Calendar & economy -------------------------------------------------------

## A new day began (1-based). Emitted by Calendar (F-082).
signal day_started(day: int)
## The town-day phase changed. phase = Calendar phase enum (defined in F-082). Emitted by Calendar (F-082).
signal phase_changed(phase: int)
## End-of-week settlement is happening on this day. Emitted by Calendar (F-082).
signal weekly_settlement(day: int)
## The shared wallet changed. amount = the NEW BALANCE, not the delta. Emitted by Economy (F-083).
signal gold_changed(amount: int)
## A debt payment was made. remaining = total debt still owed. Emitted by Economy (F-083).
signal debt_paid(amount: int, remaining: int)

# --- Shop ---------------------------------------------------------------------

## The shop sold an item to a customer. npc_type = NpcTypeData.id. Emitted by ShopManager (F-094).
signal item_sold(item: Object, price: int, npc_type: StringName)
## The shop bought an item from a customer. Emitted by ShopManager (F-095).
signal item_bought(item: Object, price: int, npc_type: StringName)
## A customer left mid-haggle without a deal. Emitted by ShopManager (F-094).
signal customer_walked_out(npc_type: StringName)
## Merchant level increased to level. Emitted by ShopManager (F-098).
signal merchant_leveled(level: int)
## Reputation with an NPC type changed. value = the NEW value (0–100). Emitted by ShopManager (F-099).
signal reputation_changed(npc_type: StringName, value: int)

@warning_ignore_restore("unused_signal")
