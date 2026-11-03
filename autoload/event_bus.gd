extends Node
## EventBus: global signals for decoupled communication (GDD §3.2).
## Emitters call `EventBus.<signal>.emit(...)`; listeners connect to EventBus, never to each other.
##
## F-002 declares only what Game needs. F-005 adds the full canonical contract
## (combat & party, dungeon & runs, calendar & economy, shop signals).

## Emitted by Game.set_state(). Args are Game.State values.
signal game_state_changed(old_state: int, new_state: int)
