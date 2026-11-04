extends GutTest
## F-011: PartyMember scene wiring (no navigation needed).

const MEMBER_SCENE: PackedScene = preload("res://actors/party_member/party_member.tscn")


func _make(data: ActorData = null, name_override: String = "") -> PartyMember:
	var m := MEMBER_SCENE.instantiate() as PartyMember
	if data != null:
		m.data = data
	m.display_name_override = name_override
	add_child_autofree(m)
	return m


func test_instantiates_with_data() -> void:
	var m := _make()
	assert_not_null(m.data)
	assert_eq(m.locomotion.data, m.data, "locomotion gets the same ActorData")


func test_capsule_sized_from_data() -> void:
	var d := ActorData.new()
	d.capsule_radius = 0.3
	d.capsule_height = 1.5
	var m := _make(d)
	var shape := (m.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost_eq(shape.radius, 0.3, 0.001)
	assert_almost_eq(shape.height, 1.5, 0.001)


func test_instances_do_not_share_shape_or_material() -> void:
	var a_data := ActorData.new()
	a_data.color = Color.RED
	var b_data := ActorData.new()
	b_data.capsule_radius = 0.25
	b_data.color = Color.BLUE
	var a := _make(a_data)
	var b := _make(b_data)
	var a_shape := (a.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost_eq(a_shape.radius, 0.4, 0.001, "a keeps its own radius")
	var a_mat := ((a.get_node("Body") as MeshInstance3D).mesh as CapsuleMesh).material as StandardMaterial3D
	var b_mat := ((b.get_node("Body") as MeshInstance3D).mesh as CapsuleMesh).material as StandardMaterial3D
	assert_eq(a_mat.albedo_color, Color.RED)
	assert_eq(b_mat.albedo_color, Color.BLUE)


func test_groups_and_collision_layers() -> void:
	var m := _make()
	assert_true(m.is_in_group(DebugConsole.ACTORS_GROUP))
	assert_true(m.is_in_group(PartyMember.GROUP))
	assert_eq(m.collision_layer, 2, "party layer")
	assert_eq(m.collision_mask, 1, "collides with world only")


func test_selection_shows_ring_and_label() -> void:
	var m := _make()
	var ring := m.get_node("SelectionRing") as MeshInstance3D
	var label := m.get_node("NameLabel") as Label3D
	assert_false(ring.visible)
	assert_false(label.visible)
	m.set_selected(true)
	assert_true(ring.visible)
	assert_true(label.visible)
	m.set_selected(false)
	assert_false(ring.visible)
	assert_false(label.visible)


func test_hover_shows_label_only() -> void:
	var m := _make()
	m.set_hovered(true)
	assert_true((m.get_node("NameLabel") as Label3D).visible)
	assert_false((m.get_node("SelectionRing") as MeshInstance3D).visible)


func test_label_text_uses_name_or_override() -> void:
	var d := ActorData.new()
	d.display_name = "Farmhand"
	assert_eq((_make(d).get_node("NameLabel") as Label3D).text, "Farmhand")
	assert_eq((_make(d, "Wren").get_node("NameLabel") as Label3D).text, "Wren")


func test_debug_commands_registered() -> void:
	_make()
	assert_true(DebugConsole.has_command("pm_move"))
	assert_true(DebugConsole.has_command("pm_select"))
	var r := DebugConsole.execute("pm_move nope")
	assert_string_contains(r.text, "Usage")
