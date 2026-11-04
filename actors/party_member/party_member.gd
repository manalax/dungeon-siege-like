class_name PartyMember extends CharacterBody3D
## Placeholder party member (F-011): capsule body, nav-driven movement, selection ring, name label.
## Label shows while selected or hovered; ring shows while selected.

const GROUP: StringName = &"party_members"
const PICK_RADIUS_SCALE: float = 1.3

@export var data: ActorData
@export var display_name_override: String = ""

var _selected: bool = false
var _hovered: bool = false

@onready var locomotion: LocomotionComponent = $Locomotion
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _facing: MeshInstance3D = $Body/Facing
@onready var _ring: MeshInstance3D = $SelectionRing
@onready var _label: Label3D = $NameLabel
@onready var pickable: Pickable = $Pickable
@onready var _pick_shape: CollisionShape3D = $Pickable/CollisionShape3D


func _ready() -> void:
	if data == null:
		data = ActorData.new()
	locomotion.data = data
	add_to_group(DebugConsole.ACTORS_GROUP)
	add_to_group(GROUP)
	_apply_data()
	_refresh_indicators()
	_register_debug_commands()


## Enter/exit pair (not _ready) so a re-parented member re-registers. Party only touches
## the visuals of members it selects, which happens after _ready.
func _enter_tree() -> void:
	Party.register_member(self)


func _exit_tree() -> void:
	Party.unregister_member(self)


func _physics_process(delta: float) -> void:
	locomotion.physics_tick(delta)


func move_to(target: Vector3) -> Vector3:
	return locomotion.move_to(target)


func stop() -> void:
	locomotion.stop()


## Instantly place the member (spawns, respawns). Resets physics interpolation so the
## visual doesn't streak from the old position.
func teleport(pos: Vector3) -> void:
	locomotion.stop()
	global_position = pos
	velocity = Vector3.ZERO
	reset_physics_interpolation()


## Screen-space test point for box selection (body centre).
func selection_point() -> Vector3:
	return global_position + Vector3.UP * data.capsule_height * 0.5


func get_display_name() -> String:
	return display_name_override if not display_name_override.is_empty() else data.display_name


## Visual hook only: Party (F-014) owns selection state and calls this.
func set_selected(on: bool) -> void:
	_selected = on
	_refresh_indicators()


func is_selected() -> bool:
	return _selected


func set_hovered(on: bool) -> void:
	_hovered = on
	_refresh_indicators()


func _refresh_indicators() -> void:
	_ring.visible = _selected
	_label.visible = _selected or _hovered


## Sizes collision/visuals from ActorData. Resources are duplicated so instances with
## different data don't share (and overwrite) one shape/mesh/material.
func _apply_data() -> void:
	var r := data.capsule_radius
	var h := data.capsule_height

	var shape := (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	shape.radius = r
	shape.height = h
	_collision.shape = shape
	_collision.position.y = h * 0.5

	var mesh := (_body_mesh.mesh as CapsuleMesh).duplicate() as CapsuleMesh
	mesh.radius = r
	mesh.height = h
	var mat := (mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = data.color
	mesh.material = mat
	_body_mesh.mesh = mesh
	_body_mesh.position.y = h * 0.5
	_facing.position = Vector3(0.0, h * 0.2, -r)

	var torus := (_ring.mesh as TorusMesh).duplicate() as TorusMesh
	torus.inner_radius = r + 0.05
	torus.outer_radius = r + 0.15
	_ring.mesh = torus

	# Click target is a bit larger than the body so moving members are easy to click.
	var pick := (_pick_shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	pick.radius = r * PICK_RADIUS_SCALE
	pick.height = h + 0.15
	_pick_shape.shape = pick
	_pick_shape.position.y = pick.height * 0.5

	_label.text = get_display_name()
	_label.position.y = h + 0.35


# --- Debug commands (registered once, static so they never bind to a freed instance) ---

func _register_debug_commands() -> void:
	if not DebugConsole.has_command("pm_move"):
		DebugConsole.register("pm_move", PartyMember._cmd_move,
				"Move party member(s) to x,z.", "pm_move <x> <z> [index]")
	if not DebugConsole.has_command("pm_select"):
		DebugConsole.register("pm_select", PartyMember._cmd_select,
				"Toggle a party member in/out of the selection (Party slot order).", "pm_select <index>")


static func _members() -> Array[Node]:
	return (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP)


static func _cmd_move(args: PackedStringArray) -> String:
	if args.size() < 2 or not args[0].is_valid_float() or not args[1].is_valid_float():
		return "Usage: pm_move <x> <z> [index]"
	var target := Vector3(args[0].to_float(), 0.0, args[1].to_float())
	var members := _members()
	if args.size() >= 3:
		var i := args[2].to_int()
		if i < 0 or i >= members.size():
			return "No party member %d (have %d)." % [i, members.size()]
		members = [members[i]]
	var lines := PackedStringArray()
	for m: Node in members:
		var dest := (m as PartyMember).move_to(target)
		lines.append("%s -> (%.1f, %.1f)" % [(m as PartyMember).get_display_name(), dest.x, dest.z])
	return "\n".join(lines) if not lines.is_empty() else "No party members."


static func _cmd_select(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_int():
		return "Usage: pm_select <index>"
	var m := Party.get_member(args[0].to_int())
	if m == null:
		return "No party member %s (have %d)." % [args[0], Party.members.size()]
	Party.toggle(m)
	return "%s selected: %s" % [m.get_display_name(), Party.is_selected(m)]
