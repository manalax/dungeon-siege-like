extends GutTest
## F-001: every action in InputActions exists in the project's InputMap.

const SPEC_ACTIONS: PackedStringArray = [
	"move_click", "select_all", "tactical_pause",
	"ability_1", "ability_2", "ability_3", "ability_4", "ability_5", "ability_6",
	"potion_health", "build_mode", "haggle_up",
]


func test_all_table_actions_exist_with_events() -> void:
	for action: String in InputActions.ACTIONS:
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "%s has a binding" % action)


func test_spec_named_actions_present() -> void:
	for action: String in SPEC_ACTIONS:
		assert_true(InputActions.ACTIONS.has(action), "table has %s" % action)
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)


func test_project_bindings_match_table() -> void:
	for action: String in InputActions.ACTIONS:
		var expected := InputActions.build_events(action)
		var actual := InputMap.action_get_events(action)
		assert_eq(actual.size(), expected.size(), "%s binding count" % action)
		for event: InputEvent in expected:
			assert_true(InputMap.action_has_event(action, event), "%s has %s" % [action, event.as_text()])


func test_select_all_uses_ctrl_cmd_autoremap() -> void:
	var found := false
	for event: InputEvent in InputMap.action_get_events("select_all"):
		if event is InputEventKey and (event as InputEventKey).command_or_control_autoremap:
			found = true
	assert_true(found, "select_all has a Ctrl/Cmd+A binding")


func test_camera_pan_uses_physical_keys() -> void:
	var event := InputMap.action_get_events("camera_pan_forward")[0] as InputEventKey
	assert_eq(event.physical_keycode, KEY_W)
	assert_eq(event.keycode, KEY_NONE)


func test_register_missing_restores_erased_action() -> void:
	InputMap.erase_action("map_toggle")
	var added := InputActions.register_missing()
	assert_eq(added, PackedStringArray(["map_toggle"]))
	assert_true(InputMap.has_action("map_toggle"))
