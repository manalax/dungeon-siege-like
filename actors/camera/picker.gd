class_name Picker extends Node
## Mouse picking for its parent RtsCamera (F-013): hover highlight + click results.
##
## - pick_at(screen_pos) raycasts world (layer 1) and Pickable areas (click_pick, layer 8).
## - Hover is re-evaluated every physics frame (targets/camera move under a still mouse).
## - Clicks arrive via _unhandled_input, so clicks consumed by UI never reach the Picker.
## Consumers: connect to `clicked` (F-014 selection, F-015 move) and `hover_changed`.

signal hover_changed(result: PickResult)
signal clicked(result: PickResult, event: InputEventMouseButton)

const WORLD_LAYER: int = 1 << 0
const PICK_MASK: int = WORLD_LAYER | Pickable.CLICK_PICK_LAYER

## Tests turn this off and call update_hover() directly.
@export var auto_hover: bool = true
## Tests set this to simulate the mouse being over UI.
var force_over_ui: bool = false

var _hover := PickResult.new()
var _mouse_inside: bool = false


func _ready() -> void:
	# Methods (not lambdas) so Godot drops the connections when the Picker is freed.
	get_window().mouse_entered.connect(_on_mouse_entered)
	get_window().mouse_exited.connect(_on_mouse_exited)
	DebugConsole.set_overlay_row("Hover", _overlay_text)


func _exit_tree() -> void:
	_set_hover(PickResult.new())
	DebugConsole.remove_overlay_row("Hover", _overlay_text)


func _physics_process(_delta: float) -> void:
	if not auto_hover:
		return
	if _mouse_inside:
		update_hover(get_viewport().get_mouse_position())
	else:
		_set_hover(PickResult.new())


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	clicked.emit(pick_at(mb.position), mb)


func pick_at(screen_pos: Vector2) -> PickResult:
	var result := PickResult.new()
	var cam := _camera()
	if cam == null:
		return result
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * cam.far
	var query := PhysicsRayQueryParameters3D.create(from, to, PICK_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return result
	result.position = hit.position
	var collider := hit.collider as Node
	if collider is Pickable:
		var p := collider as Pickable
		result.pickable = p
		result.node = p.target
		result.kind = PickResult.from_pickable_kind(p.kind)
	else:
		result.node = collider
		result.kind = PickResult.Kind.GROUND
	return result


func update_hover(screen_pos: Vector2) -> void:
	_set_hover(PickResult.new() if is_over_ui() else pick_at(screen_pos))


func get_hover() -> PickResult:
	return _hover


func is_over_ui() -> bool:
	return force_over_ui or get_viewport().gui_get_hovered_control() != null


func _set_hover(result: PickResult) -> void:
	var changed := result.pickable != _hover.pickable or result.kind != _hover.kind
	if result.pickable != _hover.pickable:
		if is_instance_valid(_hover.pickable):
			_hover.pickable.set_highlighted(false)
		if result.pickable != null:
			result.pickable.set_highlighted(true)
	_hover = result
	if changed:
		hover_changed.emit(result)


func _on_mouse_entered() -> void:
	_mouse_inside = true


func _on_mouse_exited() -> void:
	_mouse_inside = false


func _camera() -> Camera3D:
	return get_parent().get_node_or_null("Camera3D") as Camera3D


func _overlay_text() -> String:
	match _hover.kind:
		PickResult.Kind.NONE:
			return "—"
		PickResult.Kind.GROUND:
			return "ground (%.1f, %.1f, %.1f)" % [_hover.position.x, _hover.position.y, _hover.position.z]
		_:
			var label: String = _hover.node.get_display_name() if _hover.node.has_method("get_display_name") else String(_hover.node.name)
			return "%s %s" % [_hover.kind_name(), label]
