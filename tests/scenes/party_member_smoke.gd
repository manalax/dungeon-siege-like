extends Node3D
## F-011 smoke scene: arena + 3 party members exercising detour, narrow gap, and unreachable target.
## F-013 logs clicks; F-014 starts with member 0 selected and logs selection changes.

const ARENA_SCENE: PackedScene = preload("res://dungeon/test/test_arena.tscn")
const MEMBER_SCENE: PackedScene = preload("res://actors/party_member/party_member.tscn")
const PICKUP_SCENE: PackedScene = preload("res://tests/scenes/props/test_pickup.tscn")
const LEVER_SCENE: PackedScene = preload("res://tests/scenes/props/test_lever.tscn")
const NAMES: PackedStringArray = ["Detour", "Gap", "Rock"]

var arena: TestArena
var members: Array[PartyMember] = []


func _ready() -> void:
	arena = ARENA_SCENE.instantiate() as TestArena
	add_child(arena)
	for i: int in 3:
		var m := MEMBER_SCENE.instantiate() as PartyMember
		m.display_name_override = NAMES[i]
		add_child(m)
		m.teleport(arena.spawn_point(i))
		members.append(m)
	EventBus.selection_changed.connect(_on_selection_changed)
	Party.select_only(members[0])
	arena.camera.set_follow_target(members[0])
	_spawn_prop(PICKUP_SCENE, Vector3(-12, 0, 4))
	_spawn_prop(LEVER_SCENE, Vector3(-12, 0, 6))
	arena.camera.picker.clicked.connect(_on_clicked)
	if not arena.is_navmesh_ready:
		await arena.navmesh_ready
	await get_tree().physics_frame
	members[0].move_to(arena.waypoint(&"East"))
	members[1].move_to(arena.waypoint(&"GapEast"))
	members[2].move_to(Vector3(-10, 0, -8))  # rock centre: walks to the nearest reachable point
	for m: PartyMember in members:
		m.locomotion.arrived.connect(func(p: Vector3) -> void: print("%s arrived at %s" % [m.get_display_name(), p]))


func _spawn_prop(scene: PackedScene, pos: Vector3) -> void:
	var prop := scene.instantiate() as Node3D
	add_child(prop)
	prop.global_position = pos


func _on_clicked(result: PickResult, event: InputEventMouseButton) -> void:
	var button := "left" if event.button_index == MOUSE_BUTTON_LEFT else "right"
	var p := result.position
	var line := "%s click: %s %s @ (%.1f, %.1f, %.1f)" % [button, result.kind_name(), result.node.name if result.node else "-", p.x, p.y, p.z]
	print(line)
	DebugConsole.print_line(line)


func _on_selection_changed() -> void:
	var names := PackedStringArray()
	for m: PartyMember in Party.get_selection():
		names.append(m.get_display_name())
	var line := "selection: %s" % (", ".join(names) if not names.is_empty() else "—")
	print(line)
	DebugConsole.print_line(line)
