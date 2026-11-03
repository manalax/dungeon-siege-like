class_name NodeUtil
extends RefCounted
## Component lookup helpers (GDD §3.3). `type` may be a native class (Timer) or a
## class_name script (HealthComponent); matching uses is_instance_of.


## First direct child of the given type, or null.
static func find_component(owner_node: Node, type: Variant) -> Node:
	for child: Node in owner_node.get_children():
		if is_instance_of(child, type):
			return child
	return null


## All direct children of the given type.
static func find_components(owner_node: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in owner_node.get_children():
		if is_instance_of(child, type):
			found.append(child)
	return found


## Depth-first search over all descendants.
static func find_component_recursive(owner_node: Node, type: Variant) -> Node:
	for child: Node in owner_node.get_children():
		if is_instance_of(child, type):
			return child
		var deeper := find_component_recursive(child, type)
		if deeper != null:
			return deeper
	return null


## Nearest ancestor of the given type (excluding node itself), or null.
static func find_ancestor(node: Node, type: Variant) -> Node:
	var current := node.get_parent()
	while current != null:
		if is_instance_of(current, type):
			return current
		current = current.get_parent()
	return null
