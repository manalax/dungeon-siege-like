extends GutTest
## F-002: autoloads are registered and Game's state machine / time scale work.

const EXPECTED: PackedStringArray = [
	"EventBus", "InputMapSetup", "Game", "Calendar", "Economy", "Roster", "Party",
	"RunManager", "WorldStreamer", "ItemFactory", "LootService", "ShopManager",
	"Market", "SaveManager", "AudioManager",
]

var _initial_state: int


func before_each() -> void:
	_initial_state = Game.state


func after_each() -> void:
	Game.state = _initial_state as Game.State
	Engine.time_scale = 1.0


func test_all_autoloads_present() -> void:
	for autoload_name: String in EXPECTED:
		assert_true(get_tree().root.has_node(autoload_name), "/root/%s exists" % autoload_name)


func test_initial_state_is_menu() -> void:
	assert_eq(Game.state, Game.State.MENU)


func test_set_state_emits_game_state_changed() -> void:
	watch_signals(EventBus)
	Game.set_state(Game.State.TOWN)
	assert_signal_emitted_with_parameters(EventBus, "game_state_changed", [Game.State.MENU, Game.State.TOWN])
	assert_true(Game.is_state(Game.State.TOWN))


func test_set_same_state_does_not_emit_twice() -> void:
	watch_signals(EventBus)
	Game.set_state(Game.State.RUN)
	Game.set_state(Game.State.RUN)
	assert_signal_emit_count(EventBus, "game_state_changed", 1)


func test_time_scale_clamped() -> void:
	Game.set_time_scale(10.0)
	assert_eq(Game.get_time_scale(), Game.TIME_SCALE_MAX)
	assert_eq(Engine.time_scale, Game.TIME_SCALE_MAX)
	Game.set_time_scale(-1.0)
	assert_eq(Engine.time_scale, Game.TIME_SCALE_MIN)
	Game.set_time_scale(0.5)
	assert_eq(Engine.time_scale, 0.5)


func test_settings_loaded_at_startup() -> void:
	assert_true(Game.settings is GameSettings)
