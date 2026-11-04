class_name SelectionController extends Node
## Selection input for its parent RtsCamera (F-014). State lives in the Party autoload;
## this node only translates input into Party calls and draws the drag box.
##
## - Left press starts a gesture (via _unhandled_input, so presses on UI never start one).
##   Release resolves it: a drag past DRAG_THRESHOLD_PX box-selects, otherwise the press
##   position is picked and a PartyMember there is selected (Shift toggles). Ground/empty
##   clicks leave the selection alone (F-015 moves on them).
## - Box: members whose body centre projects inside replace the selection; Shift adds;
##   an empty box changes nothing.
## - F1–F6 select a slot (Shift toggles); Ctrl/Cmd+A or Home selects all. Keys are ignored
##   while a Control has focus (e.g. the debug console input).
## Consumers (F-015): `click_resolved` for non-drag clicks, `drag_finished` for boxes.

signal click_resolved(result: PickResult, additive: bool)
signal drag_finished(rect: Rect2, selected: Array[PartyMember])

const DRAG_THRESHOLD_PX: float = 6.0
const BOX_COLOR: Color = Color("#4dff66")
const BOX_FILL_ALPHA: float = 0.15
const OVERLAY_LAYER: int = 90  # below DebugConsole (100)
const SLOT_ACTIONS: Array[StringName] = [
	&"select_member_1", &"select_member_2", &"select_member_3",
	&"select_member_4", &"select_member_5", &"select_member_6",
]

var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2
var _current_pos: Vector2
var _overlay: CanvasLayer
var _box: Panel


func _ready() -> void:
	_build_overlay()
	get_window().focus_exited.connect(cancel_gesture)


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_pressing = true
			_dragging = false
			_press_pos = mb.position
			_current_pos = mb.position
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_handle_key(event as InputEventKey)


## Motion and release are taken from _input once we own the gesture, so a drag that
## ends over UI still resolves instead of leaving a stuck box.
func _input(event: InputEvent) -> void:
	if not _pressing:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_current_pos = motion.position
		if not _dragging and _current_pos.distance_to(_press_pos) > DRAG_THRESHOLD_PX:
			_dragging = true
		_update_box()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_current_pos = mb.position
		if not _dragging and _current_pos.distance_to(_press_pos) > DRAG_THRESHOLD_PX:
			_dragging = true
		_finish(_is_additive(mb))


func _handle_key(event: InputEventKey) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event.is_action_pressed(&"select_all"):
		Party.select_all()
		return
	for i: int in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			var m := Party.get_member(i)
			if m == null:
				return
			if _is_additive(event):
				Party.toggle(m)
			else:
				Party.select_only(m)
			return


# --- Public API -------------------------------------------------------------------

func is_dragging() -> bool:
	return _dragging


## Drops an in-progress press/drag without selecting (e.g. window lost focus).
func cancel_gesture() -> void:
	_pressing = false
	_dragging = false
	_update_box()


## Party members whose body centre projects inside the screen rect (any corner order).
func members_in_rect(rect: Rect2) -> Array[PartyMember]:
	var out: Array[PartyMember] = []
	var cam := _camera()
	if cam == null:
		return out
	var r := rect.abs()
	for m: PartyMember in Party.members:
		if not is_instance_valid(m):
			continue
		var p := m.selection_point()
		if cam.is_position_behind(p):
			continue
		if r.has_point(cam.unproject_position(p)):
			out.append(m)
	return out


func get_drag_rect() -> Rect2:
	return Rect2(_press_pos, _current_pos - _press_pos).abs()


# --- Internals --------------------------------------------------------------------

func _finish(additive: bool) -> void:
	var was_drag := _dragging
	var rect := get_drag_rect()
	_pressing = false
	_dragging = false
	_update_box()
	if was_drag:
		var hit := members_in_rect(rect)
		Party.select_set(hit, additive)
		drag_finished.emit(rect, hit)
		return
	var result := _picker().pick_at(_press_pos) if _picker() != null else PickResult.new()
	if result.kind == PickResult.Kind.ACTOR and result.node is PartyMember:
		var m := result.node as PartyMember
		if additive:
			Party.toggle(m)
		else:
			Party.select_only(m)
	click_resolved.emit(result, additive)


func _is_additive(event: InputEventWithModifiers) -> bool:
	return event.shift_pressed or Input.is_action_pressed(&"selection_add")


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "SelectionOverlay"
	_overlay.layer = OVERLAY_LAYER
	add_child(_overlay)
	_box = Panel.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BOX_COLOR, BOX_FILL_ALPHA)
	style.border_color = BOX_COLOR
	style.set_border_width_all(1)
	_box.add_theme_stylebox_override("panel", style)
	_box.visible = false
	_overlay.add_child(_box)


func _update_box() -> void:
	if _box == null:
		return
	_box.visible = _dragging
	if _dragging:
		var r := get_drag_rect()
		_box.position = r.position
		_box.size = r.size


func _camera() -> Camera3D:
	return get_parent().get_node_or_null("Camera3D") as Camera3D


func _picker() -> Picker:
	return get_parent().get_node_or_null("Picker") as Picker
