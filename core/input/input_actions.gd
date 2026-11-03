class_name InputActions
extends RefCounted
## Single source of truth for every input action and its default bindings (GDD §2.1).
## Used by tools/generate_input_map.gd (writes project.godot), tests, and the InputMapSetup autoload.
##
## Binding descriptors:
##   {"key": KEY_X}        logical keycode (mnemonic hotkeys)
##   {"physical": KEY_W}   physical keycode (layout-independent movement keys)
##   {"mouse": MOUSE_BUTTON_LEFT}
##   optional "ctrl": true maps to Ctrl on Windows/Linux and Cmd on macOS.
##
## Some keys are deliberately shared (Esc, Shift, mouse wheel). Dungeon, town and shop are
## never active at once, so the current Game state decides which action is consumed.

const DEADZONE: float = 0.2
const ALL_DEVICES: int = -1  ## matches bindings created in the editor's Input Map

const ACTIONS: Dictionary = {
	# Pointer & selection
	"move_click": [{"mouse": MOUSE_BUTTON_LEFT}],
	"selection_add": [{"key": KEY_SHIFT}],
	"select_all": [{"key": KEY_A, "ctrl": true}, {"key": KEY_HOME}],
	"select_member_1": [{"key": KEY_F1}],
	"select_member_2": [{"key": KEY_F2}],
	"select_member_3": [{"key": KEY_F3}],
	"select_member_4": [{"key": KEY_F4}],
	"select_member_5": [{"key": KEY_F5}],
	"select_member_6": [{"key": KEY_F6}],
	# Combat
	"tactical_pause": [{"key": KEY_SPACE}],
	"ability_1": [{"key": KEY_1}],
	"ability_2": [{"key": KEY_2}],
	"ability_3": [{"key": KEY_3}],
	"ability_4": [{"key": KEY_4}],
	"ability_5": [{"key": KEY_5}],
	"ability_6": [{"key": KEY_6}],
	"potion_health": [{"key": KEY_Z}],
	"potion_mana": [{"key": KEY_X}],
	# Camera
	"camera_rotate_drag": [{"mouse": MOUSE_BUTTON_MIDDLE}],
	"camera_rotate_left": [{"physical": KEY_Q}],
	"camera_rotate_right": [{"physical": KEY_E}],
	"camera_zoom_in": [{"mouse": MOUSE_BUTTON_WHEEL_UP}],
	"camera_zoom_out": [{"mouse": MOUSE_BUTTON_WHEEL_DOWN}],
	"camera_pan_forward": [{"physical": KEY_W}],
	"camera_pan_back": [{"physical": KEY_S}],
	"camera_pan_left": [{"physical": KEY_A}],
	"camera_pan_right": [{"physical": KEY_D}],
	"camera_follow_toggle": [{"key": KEY_V}],
	# Panels
	"inventory_toggle": [{"key": KEY_I}],
	"character_sheet_toggle": [{"key": KEY_C}],
	"abilities_toggle": [{"key": KEY_K}],
	"map_toggle": [{"key": KEY_M}],
	"calendar_toggle": [{"key": KEY_L}],
	"menu_toggle": [{"key": KEY_ESCAPE}],
	# Party
	"stance_cycle": [{"key": KEY_T}],
	"formation_cycle": [{"key": KEY_F}],
	"show_item_labels": [{"key": KEY_ALT}],
	# Shop
	"build_mode": [{"key": KEY_B}],
	"decor_rotate": [{"key": KEY_R}],
	"haggle_up": [{"key": KEY_UP}, {"mouse": MOUSE_BUTTON_WHEEL_UP}],
	"haggle_down": [{"key": KEY_DOWN}, {"mouse": MOUSE_BUTTON_WHEEL_DOWN}],
	"haggle_large_step": [{"key": KEY_SHIFT}],
	"haggle_confirm": [{"key": KEY_ENTER}, {"key": KEY_KP_ENTER}],
	"haggle_cancel": [{"key": KEY_ESCAPE}],
	# Debug
	"debug_console_toggle": [{"key": KEY_QUOTELEFT}],
}


static func build_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for desc: Dictionary in ACTIONS[String(action)]:
		events.append(_build_event(desc))
	return events


## Registers any action missing from InputMap. Returns the names that were added.
static func register_missing() -> PackedStringArray:
	var added := PackedStringArray()
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for event: InputEvent in build_events(action):
			InputMap.action_add_event(action, event)
		added.append(action)
	return added


static func _build_event(desc: Dictionary) -> InputEvent:
	if desc.has("mouse"):
		var mb := InputEventMouseButton.new()
		mb.device = ALL_DEVICES
		mb.button_index = desc["mouse"]
		return mb
	var key := InputEventKey.new()
	key.device = ALL_DEVICES
	if desc.has("physical"):
		key.physical_keycode = desc["physical"]
	else:
		key.keycode = desc["key"]
	if desc.get("ctrl", false):
		key.command_or_control_autoremap = true
	return key
