class_name Pickable extends Area3D
## Makes its parent clickable/hoverable by the Picker (F-013). Lives on the click_pick
## layer only; give it a CollisionShape3D child (it may be larger than the body for easy clicking).

enum Kind { ACTOR, PICKUP, INTERACTABLE }

const CLICK_PICK_LAYER: int = 1 << 7  # layer 8 "click_pick"
const OUTLINE_MATERIAL: ShaderMaterial = preload("res://fx/materials/outline.tres")
const KIND_COLORS: Dictionary = {
	Kind.ACTOR: Color.WHITE,  # monsters override with red
	Kind.PICKUP: Color("#ffcc33"),
	Kind.INTERACTABLE: Color("#66ccff"),
}

@export var kind: Kind = Kind.ACTOR
## Alpha 0 = use the kind's default colour.
@export var highlight_color: Color = Color(0, 0, 0, 0)
## Meshes to outline. Empty = every MeshInstance3D under the target.
@export var highlight_meshes: Array[NodePath] = []
@export var outline_width: float = 0.04

## The node this Pickable represents (reported as PickResult.node).
var target: Node

var _highlighted: bool = false
var _material: ShaderMaterial


func _ready() -> void:
	collision_layer = CLICK_PICK_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	target = get_parent()


func get_highlight_color() -> Color:
	return highlight_color if highlight_color.a > 0.0 else KIND_COLORS[kind]


func is_highlighted() -> bool:
	return _highlighted


func set_highlighted(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	if on and _material == null:
		_material = OUTLINE_MATERIAL.duplicate() as ShaderMaterial
	if _material != null:
		_material.set_shader_parameter("color", get_highlight_color())
		_material.set_shader_parameter("width", outline_width)
	for mesh: MeshInstance3D in _meshes():
		mesh.material_overlay = _material if on else null
	if target != null and target.has_method("set_hovered"):
		target.set_hovered(on)


func _meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if not highlight_meshes.is_empty():
		for path: NodePath in highlight_meshes:
			var m := get_node_or_null(path) as MeshInstance3D
			if m != null:
				out.append(m)
		return out
	if target != null:
		_collect_meshes(target, out)
	return out


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child == self:
			continue
		if child is MeshInstance3D:
			out.append(child)
		_collect_meshes(child, out)
