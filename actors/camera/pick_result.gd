class_name PickResult extends RefCounted
## What's under the cursor (F-013). to_dict() matches the GDD's {kind, node, position}.

enum Kind { NONE, GROUND, ACTOR, PICKUP, INTERACTABLE }

var kind: Kind = Kind.NONE
## The represented node (Pickable.target) or, for GROUND, the world body hit.
var node: Node
## The Pickable hit, or null for GROUND / NONE.
var pickable: Pickable
var position: Vector3


func is_ground() -> bool:
	return kind == Kind.GROUND


func is_none() -> bool:
	return kind == Kind.NONE


func kind_name() -> String:
	return String(Kind.find_key(kind)).to_lower()


func to_dict() -> Dictionary:
	return {"kind": kind_name(), "node": node, "position": position}


static func from_pickable_kind(k: Pickable.Kind) -> Kind:
	match k:
		Pickable.Kind.ACTOR:
			return Kind.ACTOR
		Pickable.Kind.PICKUP:
			return Kind.PICKUP
		_:
			return Kind.INTERACTABLE
