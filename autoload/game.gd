extends Node
## Game: app state machine, time scale and player settings (GDD §3.2).
##
## Any transition is currently allowed; features add guards when they need them.
## Planned additions:
##   F-017 tactical pause (RUN only) built on set_time_scale / pausable group.
##   F-084 GAME_OVER / ENDING flows.
##   F-088 menu pause (PAUSED).

enum State { MENU, TOWN, SHOP_OPEN, RUN, PAUSED, GAME_OVER, ENDING }

const TIME_SCALE_MIN: float = 0.0
const TIME_SCALE_MAX: float = 4.0

## Current state. Read-only by convention: change it through set_state().
var state: State = State.MENU
## Player settings, loaded from user://settings.cfg at startup.
var settings: GameSettings


func _ready() -> void:
	settings = GameSettings.load_from()


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old_state := state
	state = new_state
	EventBus.game_state_changed.emit(old_state, new_state)


func is_state(s: State) -> bool:
	return state == s


func set_time_scale(scale: float) -> void:
	Engine.time_scale = clampf(scale, TIME_SCALE_MIN, TIME_SCALE_MAX)


func get_time_scale() -> float:
	return Engine.time_scale


func save_settings() -> Error:
	return settings.save_to()
