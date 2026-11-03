extends GutTest
## F-003: DebugConsole autoload (registration from other code, toggle, output, overlay).


func after_each() -> void:
	DebugConsole.unregister("t_echo")
	DebugConsole.remove_overlay_row("T")
	DebugConsole.close()
	Engine.time_scale = 1.0


func test_register_from_other_code_and_execute() -> void:
	DebugConsole.register("t_echo", func(a: PackedStringArray) -> String: return " ".join(a), "test")
	var r := DebugConsole.execute("t_echo a b")
	assert_true(r.ok)
	assert_eq(r.text, "a b")
	assert_string_contains(DebugConsole.output_text(), "> t_echo a b")


func test_toggle_opens_and_closes() -> void:
	assert_false(DebugConsole.is_open())
	DebugConsole.toggle()
	assert_true(DebugConsole.is_open())
	DebugConsole.toggle()
	assert_false(DebugConsole.is_open())


func test_backtick_key_toggles() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_QUOTELEFT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	assert_true(DebugConsole.is_open(), "backtick opens console")
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.parse_input_event(press.duplicate())
	Input.flush_buffered_events()
	assert_false(DebugConsole.is_open(), "second backtick closes console")


func test_unknown_command_prints_error() -> void:
	var r := DebugConsole.execute("definitely_not_a_command")
	assert_false(r.ok)
	assert_string_contains(DebugConsole.output_text(), "Unknown command 'definitely_not_a_command'")


func test_overlay_row_registration() -> void:
	DebugConsole.set_overlay_row("T", func() -> String: return "x")
	DebugConsole.refresh_overlay()
	assert_string_contains(DebugConsole.overlay_text(), "T: x")
	for key: String in ["FPS", "State", "Actors", "Chunks", "Day"]:
		assert_string_contains(DebugConsole.overlay_text(), key + ":")


func test_timescale_builtin() -> void:
	DebugConsole.execute("timescale 2")
	assert_eq(Engine.time_scale, 2.0)


func test_state_builtin_sets_game_state() -> void:
	var before := Game.state
	DebugConsole.execute("state town")
	assert_eq(Game.state, Game.State.TOWN)
	Game.state = before
