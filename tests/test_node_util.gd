extends GutTest
## F-004: NodeUtil component lookup.

class FakeComponent extends Node:
	pass

var root: Node3D
var plain: Node
var timer_a: Timer
var timer_b: Timer
var fake: FakeComponent


func before_each() -> void:
	root = autofree(Node3D.new())
	plain = Node.new()
	timer_a = Timer.new()
	timer_b = Timer.new()
	fake = FakeComponent.new()
	root.add_child(plain)
	root.add_child(timer_a)
	root.add_child(timer_b)
	plain.add_child(fake)  # grandchild


func test_find_component_native_type() -> void:
	assert_eq(NodeUtil.find_component(root, Timer), timer_a)


func test_find_component_direct_children_only() -> void:
	assert_null(NodeUtil.find_component(root, FakeComponent))


func test_find_component_recursive_script_type() -> void:
	assert_eq(NodeUtil.find_component_recursive(root, FakeComponent), fake)


func test_find_components_returns_all() -> void:
	assert_eq(NodeUtil.find_components(root, Timer), [timer_a, timer_b] as Array[Node])


func test_find_ancestor() -> void:
	assert_eq(NodeUtil.find_ancestor(fake, Node3D), root)
	assert_eq(NodeUtil.find_ancestor(fake, Node), plain, "nearest ancestor wins")


func test_no_match_returns_null() -> void:
	assert_null(NodeUtil.find_component(root, Camera3D))
	assert_null(NodeUtil.find_component_recursive(root, Camera3D))
	assert_null(NodeUtil.find_ancestor(root, Timer))
