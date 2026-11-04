extends GutTest
## F-014: every selection mode with 3 test members in the arena, driven by injected input.

const ARENA_SCENE: PackedScene = preload("res://dungeon/test/test_arena.tscn")
const MEMBER_SCENE: PackedScene = preload("res://actors/party_member/party_member.tscn")
const FOCUS: Vector3 = Vector3(-12, 0, 10)  # open floor west of the wall
const OFFSETS: Array[Vector3] = [Vector3(-2.5, 0, 0), Vector3(0, 0, 0), Vector3(2.5, 0, 0)]
const FLOOR_POINT: Vector3 = Vector3(-12, 0, 13)

var arena: TestArena
var cam: RtsCamera
var sel: SelectionController
var m: Array[PartyMember] = []
var _gut_gui_filters: Dictionary = {}  # Control -> original mouse_filter


func before_each() -> void:
	Party.clear_selection()
	arena = ARENA_SCENE.instantiate() as TestArena
	add_child_autofree(arena)
	if not arena.is_navmesh_ready:
		await wait_for_signal(arena.navmesh_ready, 5.0, "arena navmesh ready")
	cam = arena.camera
	cam.auto_process = false
	cam.picker.auto_hover = false
	sel = cam.selection
	m.clear()
	for i: int in 3:
		var pm := MEMBER_SCENE.instantiate() as PartyMember
		pm.display_name_override = "M%d" % i
		arena.add_child(pm)
		pm.teleport(FOCUS + OFFSETS[i])
		m.append(pm)
	var focus_node := Node3D.new()
	focus_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arena.add_child(focus_node)
	focus_node.global_position = FOCUS
	cam.set_follow_target(focus_node)
	for i: int in 5:
		cam.step(1.0)
	await wait_physics_frames(2)
	_let_clicks_through_gut_gui()
	get_viewport().gui_release_focus()


func after_each() -> void:
	_restore_gut_gui()
	Party.clear_selection()


func _let_clicks_through_gut_gui() -> void:
	var runner := get_tree().root.get_node_or_null("GutRunner")
	if runner == null:
		return
	for c: Node in runner.find_children("*", "Control", true, false):
		var ctrl := c as Control
		_gut_gui_filters[ctrl] = ctrl.mouse_filter
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _restore_gut_gui() -> void:
	for ctrl: Variant in _gut_gui_filters:
		if is_instance_valid(ctrl):
			(ctrl as Control).mouse_filter = _gut_gui_filters[ctrl]
	_gut_gui_filters.clear()


func _screen(world: Vector3) -> Vector2:
	return cam.camera.unproject_position(world)


func _member_screen(i: int) -> Vector2:
	return _screen(m[i].selection_point())


func _selected() -> Array[PartyMember]:
	return Party.get_selection()


# --- Input injection ----------------------------------------------------------------

func _button(pos: Vector2, pressed: bool, shift: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.shift_pressed = shift
	Input.parse_input_event(e)


func _motion(pos: Vector2, shift: bool) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.shift_pressed = shift
	Input.parse_input_event(e)


func _click(pos: Vector2, shift: bool = false) -> void:
	_button(pos, true, shift)
	_button(pos, false, shift)
	Input.flush_buffered_events()


func _drag(from: Vector2, to: Vector2, shift: bool = false) -> void:
	_button(from, true, shift)
	_motion(from.lerp(to, 0.5), shift)
	_motion(to, shift)
	_button(to, false, shift)
	Input.flush_buffered_events()


func _key(keycode: Key, shift: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = true
	e.shift_pressed = shift
	Input.parse_input_event(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func _press_action_event(action: StringName) -> void:
	var e := InputMap.action_get_events(action)[0].duplicate() as InputEvent
	(e as InputEventKey).pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


## Screen rect spanning members [i, j], padded by under half the gap to a neighbour so it
## never reaches the next member whatever the viewport size.
func _rect_over(i: int, j: int) -> Array[Vector2]:
	var a := _member_screen(i)
	var b := _member_screen(j)
	var pad := _member_screen(0).distance_to(_member_screen(1)) * 0.4
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(pad, pad)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(pad, pad)
	return [lo, hi]


# --- Click ----------------------------------------------------------------------

func test_click_member_selects_only_it() -> void:
	Party.select_all()
	_click(_member_screen(1))
	assert_eq(_selected(), [m[1]] as Array[PartyMember])


func test_shift_click_adds_then_toggles_off() -> void:
	_click(_member_screen(0))
	_click(_member_screen(2), true)
	assert_eq(_selected(), [m[0], m[2]] as Array[PartyMember])
	_click(_member_screen(0), true)
	assert_eq(_selected(), [m[2]] as Array[PartyMember])


func test_shift_click_last_member_keeps_it() -> void:
	_click(_member_screen(1))
	_click(_member_screen(1), true)
	assert_eq(_selected(), [m[1]] as Array[PartyMember])


func test_ground_click_keeps_selection() -> void:
	Party.select_set([m[0], m[1]])
	watch_signals(sel)
	_click(_screen(FLOOR_POINT))
	assert_eq(_selected(), [m[0], m[1]] as Array[PartyMember])
	assert_signal_emitted(sel, "click_resolved")
	var params: Array = get_signal_parameters(sel, "click_resolved")
	assert_eq((params[0] as PickResult).kind, PickResult.Kind.GROUND)


func test_sub_threshold_drag_is_a_click() -> void:
	var p := _member_screen(2)
	_drag(p, p + Vector2(3, 2))
	assert_eq(_selected(), [m[2]] as Array[PartyMember])


func test_ui_covered_press_does_not_select() -> void:
	Party.select_only(m[0])
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child_autofree(blocker)
	await wait_process_frames(1)
	_click(_member_screen(2))
	r_assert_only(m[0], "UI consumed the click")
	var r := _rect_over(0, 2)
	_drag(r[0], r[1])
	r_assert_only(m[0], "UI consumed the drag")
	assert_false(sel.is_dragging())


func r_assert_only(pm: PartyMember, msg: String) -> void:
	assert_eq(_selected(), [pm] as Array[PartyMember], msg)


# --- Box ------------------------------------------------------------------------

func test_box_selects_exactly_covered_members() -> void:
	Party.select_only(m[2])
	var r := _rect_over(0, 1)
	watch_signals(sel)
	_drag(r[0], r[1])
	assert_eq(_selected(), [m[0], m[1]] as Array[PartyMember])
	assert_signal_emitted(sel, "drag_finished")
	assert_false(sel.is_dragging(), "box closed after release")


func test_box_any_drag_direction() -> void:
	var r := _rect_over(1, 2)
	_drag(r[1], r[0])
	assert_eq(_selected(), [m[1], m[2]] as Array[PartyMember])


func test_shift_box_adds() -> void:
	Party.select_only(m[2])
	var r := _rect_over(0, 0)
	_drag(r[0], r[1], true)
	assert_eq(_selected(), [m[0], m[2]] as Array[PartyMember])


func test_empty_box_changes_nothing() -> void:
	Party.select_only(m[1])
	var p := _screen(FLOOR_POINT)
	watch_signals(EventBus)
	_drag(p, p + Vector2(30, 20))
	assert_eq(_selected(), [m[1]] as Array[PartyMember])
	assert_signal_not_emitted(EventBus, "selection_changed")


func test_box_overlay_visible_only_while_dragging() -> void:
	var box := sel.get_node("SelectionOverlay/Box") as Control
	var p := _screen(FLOOR_POINT)
	_button(p, true, false)
	_motion(p + Vector2(40, 30), false)
	Input.flush_buffered_events()
	assert_true(sel.is_dragging())
	assert_true(box.visible)
	assert_eq(box.mouse_filter, Control.MOUSE_FILTER_IGNORE, "box never blocks input")
	_button(p + Vector2(40, 30), false, false)
	Input.flush_buffered_events()
	assert_false(box.visible)


func test_members_in_rect_skips_members_behind_camera() -> void:
	var behind := cam.camera.global_position + cam.camera.global_basis.z * 5.0
	m[0].teleport(behind)
	var full := cam.camera.get_viewport().get_visible_rect()
	var hit := sel.members_in_rect(full)
	assert_false(hit.has(m[0]), "behind the camera")
	assert_true(hit.has(m[1]))


# --- Keys -----------------------------------------------------------------------

func test_f_keys_select_slot() -> void:
	_key(KEY_F1)
	assert_eq(_selected(), [m[0]] as Array[PartyMember])
	_key(KEY_F3)
	assert_eq(_selected(), [m[2]] as Array[PartyMember])


func test_shift_f_key_toggles() -> void:
	_key(KEY_F1)
	_key(KEY_F2, true)
	assert_eq(_selected(), [m[0], m[1]] as Array[PartyMember])
	_key(KEY_F1, true)
	assert_eq(_selected(), [m[1]] as Array[PartyMember])
	_key(KEY_F2, true)
	assert_eq(_selected(), [m[1]] as Array[PartyMember], "last member stays")


func test_missing_slot_is_noop() -> void:
	_key(KEY_F2)
	_key(KEY_F6)
	assert_eq(_selected(), [m[1]] as Array[PartyMember])


func test_ctrl_a_and_home_select_all() -> void:
	_key(KEY_F1)
	_press_action_event(&"select_all")  # Ctrl+A (Cmd+A on macOS)
	assert_eq(_selected(), m)
	_key(KEY_F1)
	_key(KEY_HOME)
	assert_eq(_selected(), m)


func test_ctrl_a_does_not_pan_camera() -> void:
	var e := InputMap.action_get_events(&"select_all")[0].duplicate() as InputEventKey
	e.pressed = true
	assert_false(e.is_action(&"camera_pan_left"), "A no longer pans the camera")


func test_keys_ignored_while_control_focused() -> void:
	_key(KEY_F1)
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	await wait_process_frames(1)
	_key(KEY_F3)
	_key(KEY_HOME)
	assert_eq(_selected(), [m[0]] as Array[PartyMember])
	edit.release_focus()
