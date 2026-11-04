extends GutTest
## F-014: Party selection state (pure logic on bare members; no arena or input).

const MEMBER_SCENE: PackedScene = preload("res://actors/party_member/party_member.tscn")

var a: PartyMember
var b: PartyMember
var c: PartyMember


func before_each() -> void:
	Party.clear_selection()
	a = _member("A")
	b = _member("B")
	c = _member("C")


func after_each() -> void:
	Party.clear_selection()


func _member(n: String) -> PartyMember:
	var m := MEMBER_SCENE.instantiate() as PartyMember
	m.display_name_override = n
	add_child_autofree(m)
	return m


func _ring(m: PartyMember) -> bool:
	return (m.get_node("SelectionRing") as MeshInstance3D).visible


# --- Roster -----------------------------------------------------------------------

func test_members_register_in_spawn_order() -> void:
	assert_eq(Party.members, [a, b, c] as Array[PartyMember])
	assert_eq(Party.get_member(0), a)
	assert_eq(Party.get_member(2), c)
	assert_null(Party.get_member(3), "empty slot")
	assert_null(Party.get_member(-1))
	assert_eq(Party.slot_of(b), 1)


func test_register_twice_is_ignored() -> void:
	Party.register_member(a)
	assert_eq(Party.members.size(), 3)


func test_freeing_member_unregisters_and_deselects() -> void:
	Party.select_all()
	watch_signals(EventBus)
	remove_child(b)
	assert_false(Party.members.has(b))
	assert_eq(Party.get_selection(), [a, c] as Array[PartyMember])
	assert_signal_emit_count(EventBus, "selection_changed", 1)
	b.free()


func test_unselected_member_leaving_does_not_emit() -> void:
	Party.select_only(a)
	watch_signals(EventBus)
	remove_child(c)
	assert_signal_not_emitted(EventBus, "selection_changed")
	c.free()


# --- Selection --------------------------------------------------------------------

func test_select_only_replaces() -> void:
	Party.select_all()
	Party.select_only(b)
	assert_eq(Party.get_selection(), [b] as Array[PartyMember])
	assert_true(Party.is_selected(b))
	assert_false(Party.is_selected(a))


func test_additive_select_keeps_slot_order() -> void:
	Party.select_only(c)
	Party.select(a, true)
	assert_eq(Party.get_selection(), [a, c] as Array[PartyMember], "ordered by slot, not by click")
	Party.select(b)
	assert_eq(Party.get_selection(), [b] as Array[PartyMember], "non-additive replaces")


func test_toggle_adds_and_removes() -> void:
	Party.select_only(a)
	Party.toggle(b)
	assert_eq(Party.selection_count(), 2)
	Party.toggle(a)
	assert_eq(Party.get_selection(), [b] as Array[PartyMember])


func test_toggle_never_empties_selection() -> void:
	Party.select_only(a)
	watch_signals(EventBus)
	Party.toggle(a)
	assert_eq(Party.get_selection(), [a] as Array[PartyMember])
	assert_signal_not_emitted(EventBus, "selection_changed")


func test_select_set_replace_add_and_empty() -> void:
	Party.select_only(a)
	Party.select_set([b, c])
	assert_eq(Party.get_selection(), [b, c] as Array[PartyMember])
	Party.select_set([a], true)
	assert_eq(Party.get_selection(), [a, b, c] as Array[PartyMember])
	Party.select_only(a)
	watch_signals(EventBus)
	Party.select_set([])
	assert_eq(Party.get_selection(), [a] as Array[PartyMember], "empty set is a no-op")
	assert_signal_not_emitted(EventBus, "selection_changed")


func test_select_all() -> void:
	Party.select_all()
	assert_eq(Party.get_selection(), [a, b, c] as Array[PartyMember])


func test_emits_once_per_change_and_not_on_noop() -> void:
	watch_signals(EventBus)
	Party.select_all()
	assert_signal_emit_count(EventBus, "selection_changed", 1)
	Party.select_all()
	Party.select(a, true)
	Party.select_set([a, b], true)
	assert_signal_emit_count(EventBus, "selection_changed", 1, "no-ops don't emit")
	Party.select_only(a)
	assert_signal_emit_count(EventBus, "selection_changed", 2)


func test_unregistered_nodes_ignored() -> void:
	var outsider := MEMBER_SCENE.instantiate() as PartyMember  # never enters the tree
	Party.select_only(a)
	watch_signals(EventBus)
	Party.select_only(outsider)
	Party.toggle(outsider)
	var plain := Node3D.new()
	Party.select_set([outsider, plain])
	assert_eq(Party.get_selection(), [a] as Array[PartyMember])
	assert_signal_not_emitted(EventBus, "selection_changed")
	outsider.free()
	plain.free()


func test_get_selection_is_a_copy() -> void:
	Party.select_only(a)
	Party.get_selection().append(b)
	assert_eq(Party.selection_count(), 1)


func test_rings_follow_selection() -> void:
	Party.select_set([a, b])
	assert_true(_ring(a))
	assert_true(_ring(b))
	assert_false(_ring(c))
	Party.select_only(c)
	assert_false(_ring(a))
	assert_false(_ring(b))
	assert_true(_ring(c))


# --- Debug ------------------------------------------------------------------------

func test_overlay_row_lists_names() -> void:
	Party.select_set([a, c])
	DebugConsole.refresh_overlay()
	assert_string_contains(DebugConsole.overlay_text(), "Selected: A, C")
	Party.clear_selection()
	DebugConsole.refresh_overlay()
	assert_string_contains(DebugConsole.overlay_text(), "Selected: —")


func test_select_command() -> void:
	DebugConsole.execute("select 1")
	assert_eq(Party.get_selection(), [b] as Array[PartyMember])
	DebugConsole.execute("select all")
	assert_eq(Party.selection_count(), 3)
	DebugConsole.execute("select none")
	assert_eq(Party.selection_count(), 0)
	var r: Dictionary = DebugConsole.execute("select 9")
	assert_eq(Party.selection_count(), 0)
	assert_string_contains(str(r), "No party member 9")


func test_pm_select_routes_through_party() -> void:
	DebugConsole.execute("pm_select 2")
	assert_true(Party.is_selected(c))
	assert_true(_ring(c))
	DebugConsole.execute("pm_select 0")
	assert_eq(Party.get_selection(), [a, c] as Array[PartyMember])
