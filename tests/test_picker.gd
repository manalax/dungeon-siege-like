extends GutTest
## F-013: Picker returns correct kinds for hover & click in the test arena; UI blocks clicks.

const ARENA_SCENE: PackedScene = preload("res://dungeon/test/test_arena.tscn")
const MEMBER_SCENE: PackedScene = preload("res://actors/party_member/party_member.tscn")
const PICKUP_SCENE: PackedScene = preload("res://tests/scenes/props/test_pickup.tscn")
const LEVER_SCENE: PackedScene = preload("res://tests/scenes/props/test_lever.tscn")
const FOCUS: Vector3 = Vector3(-12, 0, 10)  # open floor west of the wall
const FLOOR_POINT: Vector3 = Vector3(-12, 0, 13)

var arena: TestArena
var cam: RtsCamera
var picker: Picker
var member: PartyMember
var pickup: Node3D
var lever: Node3D
var _gut_gui_filters: Dictionary = {}  # Control -> original mouse_filter


func before_each() -> void:
	arena = ARENA_SCENE.instantiate() as TestArena
	add_child_autofree(arena)
	if not arena.is_navmesh_ready:
		await wait_for_signal(arena.navmesh_ready, 5.0, "arena navmesh ready")
	cam = arena.camera
	cam.auto_process = false
	picker = cam.picker
	picker.auto_hover = false
	member = MEMBER_SCENE.instantiate() as PartyMember
	arena.add_child(member)
	member.teleport(FOCUS)
	pickup = _prop(PICKUP_SCENE, FOCUS + Vector3(3, 0, 0))
	lever = _prop(LEVER_SCENE, FOCUS + Vector3(-3, 0, 0))
	var focus_node := Node3D.new()
	focus_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arena.add_child(focus_node)
	focus_node.global_position = FOCUS
	cam.set_follow_target(focus_node)
	for i: int in 5:
		cam.step(1.0)  # snap onto the focus
	await wait_physics_frames(2)  # let the physics space see the new areas


func after_each() -> void:
	_restore_gut_gui()


## GUT's own on-screen panel covers the tiny headless viewport and would swallow every
## injected click (correctly, as UI). Let clicks pass through it while a click test runs.
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


func _prop(scene: PackedScene, pos: Vector3) -> Node3D:
	var p := scene.instantiate() as Node3D
	arena.add_child(p)
	p.global_position = pos
	return p


func _screen(world: Vector3) -> Vector2:
	return cam.camera.unproject_position(world)


func _overlay_color(mesh: MeshInstance3D) -> Variant:
	var mat := mesh.material_overlay as ShaderMaterial
	return null if mat == null else mat.get_shader_parameter("color")


# --- pick_at kinds --------------------------------------------------------------

func test_picks_actor() -> void:
	var r := picker.pick_at(_screen(FOCUS + Vector3.UP * 0.9))
	assert_eq(r.kind, PickResult.Kind.ACTOR)
	assert_eq(r.node, member)
	assert_eq(r.pickable, member.pickable)


func test_picks_pickup_and_interactable() -> void:
	var a := picker.pick_at(_screen(pickup.global_position + Vector3.UP * 0.2))
	assert_eq(a.kind, PickResult.Kind.PICKUP)
	assert_eq(a.node, pickup)
	var b := picker.pick_at(_screen(lever.global_position + Vector3.UP * 0.6))
	assert_eq(b.kind, PickResult.Kind.INTERACTABLE)
	assert_eq(b.node, lever)


func test_picks_ground_with_position() -> void:
	var r := picker.pick_at(_screen(FLOOR_POINT))
	assert_eq(r.kind, PickResult.Kind.GROUND)
	assert_true(r.is_ground())
	assert_lt(r.position.distance_to(FLOOR_POINT), 0.1, "hit point is the floor point")
	assert_eq(r.to_dict().kind, "ground")


func test_nothing_hit_is_none() -> void:
	var size := cam.camera.get_viewport().get_visible_rect().size
	var r := picker.pick_at(Vector2(size.x * 0.5, 0.0))  # top edge looks past the arena
	assert_eq(r.kind, PickResult.Kind.NONE)


func test_actor_wins_over_ground_behind_it() -> void:
	var r := picker.pick_at(_screen(FOCUS + Vector3.UP * 0.05))  # at the member's feet
	assert_eq(r.kind, PickResult.Kind.ACTOR)


# --- Hover ----------------------------------------------------------------------

func test_hover_highlights_and_clears() -> void:
	var body := member.get_node("Body") as MeshInstance3D
	var label := member.get_node("NameLabel") as Label3D
	watch_signals(picker)
	picker.update_hover(_screen(FOCUS + Vector3.UP * 0.9))
	assert_eq(_overlay_color(body), Color.WHITE, "party member outlined white")
	assert_true(label.visible, "hover shows the name label")
	assert_eq(picker.get_hover().kind, PickResult.Kind.ACTOR)
	assert_signal_emitted(picker, "hover_changed")
	picker.update_hover(_screen(FLOOR_POINT))
	assert_null(body.material_overlay, "outline cleared")
	assert_false(label.visible, "label hidden again")
	assert_eq(picker.get_hover().kind, PickResult.Kind.GROUND)


func test_ring_and_nub_not_outlined() -> void:
	picker.update_hover(_screen(FOCUS + Vector3.UP * 0.9))
	assert_null((member.get_node("SelectionRing") as MeshInstance3D).material_overlay)
	assert_null((member.get_node("Body/Facing") as MeshInstance3D).material_overlay)


func test_hover_colours_by_kind_and_override() -> void:
	var pickup_mesh := pickup.get_node("Mesh") as MeshInstance3D
	var lever_mesh := lever.get_node("Mesh") as MeshInstance3D
	picker.update_hover(_screen(pickup.global_position + Vector3.UP * 0.2))
	assert_eq(_overlay_color(pickup_mesh), Color("#ffcc33"), "pickups gold")
	picker.update_hover(_screen(lever.global_position + Vector3.UP * 0.6))
	assert_eq(_overlay_color(lever_mesh), Color("#66ccff"), "interactables light blue")
	assert_null(pickup_mesh.material_overlay, "previous hover cleared")
	picker.update_hover(_screen(FLOOR_POINT))
	(lever.get_node("Pickable") as Pickable).highlight_color = Color.RED
	picker.update_hover(_screen(lever.global_position + Vector3.UP * 0.6))
	assert_eq(_overlay_color(lever_mesh), Color.RED, "override colour")


func test_hover_cleared_over_ui() -> void:
	picker.update_hover(_screen(FOCUS + Vector3.UP * 0.9))
	picker.force_over_ui = true
	picker.update_hover(_screen(FOCUS + Vector3.UP * 0.9))
	assert_eq(picker.get_hover().kind, PickResult.Kind.NONE)
	assert_null((member.get_node("Body") as MeshInstance3D).material_overlay)
	picker.force_over_ui = false


# --- Click ----------------------------------------------------------------------

func _click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func test_click_emits_result() -> void:
	_let_clicks_through_gut_gui()
	watch_signals(picker)
	_click(_screen(FOCUS + Vector3.UP * 0.9))
	assert_signal_emit_count(picker, "clicked", 1, "press emits once; release ignored")
	var params: Array = get_signal_parameters(picker, "clicked")
	assert_eq((params[0] as PickResult).kind, PickResult.Kind.ACTOR)
	assert_eq((params[1] as InputEventMouseButton).button_index, MOUSE_BUTTON_LEFT)
	_click(_screen(FLOOR_POINT), MOUSE_BUTTON_RIGHT)
	params = get_signal_parameters(picker, "clicked")
	assert_eq((params[0] as PickResult).kind, PickResult.Kind.GROUND)
	assert_eq((params[1] as InputEventMouseButton).button_index, MOUSE_BUTTON_RIGHT)


func test_wheel_and_middle_clicks_ignored() -> void:
	_let_clicks_through_gut_gui()
	watch_signals(picker)
	_click(_screen(FLOOR_POINT), MOUSE_BUTTON_MIDDLE)
	_click(_screen(FLOOR_POINT), MOUSE_BUTTON_WHEEL_UP)
	assert_signal_not_emitted(picker, "clicked")


func test_ui_covered_click_ignored() -> void:
	_let_clicks_through_gut_gui()  # before adding our blocker, which must keep STOP
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child_autofree(blocker)
	await wait_process_frames(1)
	watch_signals(picker)
	_click(_screen(FOCUS + Vector3.UP * 0.9))
	assert_signal_not_emitted(picker, "clicked", "UI consumed the click")
	blocker.queue_free()
	await wait_process_frames(1)
	_click(_screen(FOCUS + Vector3.UP * 0.9))
	assert_signal_emitted(picker, "clicked", "click reaches the picker without UI on top")


# --- Data -----------------------------------------------------------------------

func test_pick_shape_sized_from_data() -> void:
	var shape := (member.get_node("Pickable/CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost_eq(shape.radius, member.data.capsule_radius * PartyMember.PICK_RADIUS_SCALE, 0.001)
	assert_eq(member.pickable.collision_layer, Pickable.CLICK_PICK_LAYER)


func test_overlay_row_shows_hover() -> void:
	picker.update_hover(_screen(FOCUS + Vector3.UP * 0.9))
	DebugConsole.refresh_overlay()
	assert_string_contains(DebugConsole.overlay_text(), "Hover: actor Farmhand")
