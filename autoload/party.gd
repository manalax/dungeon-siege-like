extends Node
## Party: The deployed run party (max 6 incl. mules), leader, selection and formation (GDD §2.3, §2.7).
##
## Selection (F-014) is the source of truth for who is selected; PartyMember.set_selected()
## is only the visual hook and is driven from here.
## - Members register themselves on _ready and unregister on _exit_tree. Slot order (F1–F6)
##   is registration order. F-050's deploy() replaces auto-registration.
## - Only registered members can be selected; anything else is ignored.
## - toggle() never removes the last selected member, so clicks can't empty the selection.
## - EventBus.selection_changed is emitted once per actual change, never on a no-op.
## Input lives in SelectionController (actors/camera/selection_controller.gd).
##
## Still planned:
##   F-028 party_wiped detection
##   F-050 deploy(members), set_leader(m), leader, party_changed
##   F-051 formation, cycle_formation()

## Registered members in slot order. Read-only by convention.
var members: Array[PartyMember] = []

var _selection: Array[PartyMember] = []


func _ready() -> void:
	DebugConsole.set_overlay_row("Selected", _overlay_text)
	DebugConsole.register("select", _cmd_select, "Select party members by slot.", "select <index|all|none>")


# --- Roster (pre-F-050) -----------------------------------------------------------

func register_member(m: PartyMember) -> void:
	if m == null or members.has(m):
		return
	members.append(m)


func unregister_member(m: PartyMember) -> void:
	if not members.has(m):
		return
	members.erase(m)
	if _selection.has(m):
		var next := _selection.duplicate()
		next.erase(m)
		_apply(next)


## 0-based slot; null if empty.
func get_member(slot: int) -> PartyMember:
	return members[slot] if slot >= 0 and slot < members.size() else null


func slot_of(m: PartyMember) -> int:
	return members.find(m)


# --- Selection --------------------------------------------------------------------

func select_only(m: PartyMember) -> void:
	if not members.has(m):
		return
	_apply([m])


func select(m: PartyMember, additive: bool = false) -> void:
	if not additive:
		select_only(m)
		return
	if not members.has(m) or _selection.has(m):
		return
	var next := _selection.duplicate()
	next.append(m)
	_apply(next)


## Adds m, or removes it unless it is the only selected member.
func toggle(m: PartyMember) -> void:
	if not members.has(m):
		return
	if not _selection.has(m):
		select(m, true)
		return
	if _selection.size() <= 1:
		return
	var next := _selection.duplicate()
	next.erase(m)
	_apply(next)


## Replaces the selection with list (or adds it if additive). An empty or unregistered-only
## list changes nothing.
func select_set(list: Array, additive: bool = false) -> void:
	var valid: Array[PartyMember] = []
	for n: Variant in list:
		if n is PartyMember and members.has(n) and not valid.has(n):
			valid.append(n)
	if valid.is_empty():
		return
	var next: Array[PartyMember] = []
	if additive:
		next.assign(_selection)
	for m: PartyMember in valid:
		if not next.has(m):
			next.append(m)
	_apply(next)


func select_all() -> void:
	_apply(members.duplicate())


## For tests/teardown and debug; not bound to input.
func clear_selection() -> void:
	_apply([])


func get_selection() -> Array[PartyMember]:
	return _selection.duplicate()


func is_selected(m: PartyMember) -> bool:
	return _selection.has(m)


func selection_count() -> int:
	return _selection.size()


# --- Internals --------------------------------------------------------------------

## Sets the selection (kept in slot order), updates visuals for members that changed,
## and emits selection_changed once if anything changed.
func _apply(next: Array) -> void:
	var ordered: Array[PartyMember] = []
	for m: PartyMember in members:
		if next.has(m):
			ordered.append(m)
	if ordered == _selection:
		return
	var old := _selection
	_selection = ordered
	for m: PartyMember in old:
		if not ordered.has(m) and is_instance_valid(m):
			m.set_selected(false)
	for m: PartyMember in ordered:
		if not old.has(m):
			m.set_selected(true)
	EventBus.selection_changed.emit()


func _overlay_text() -> String:
	if _selection.is_empty():
		return DebugConsole.PLACEHOLDER
	var names := PackedStringArray()
	for m: PartyMember in _selection:
		names.append(m.get_display_name())
	return ", ".join(names)


func _cmd_select(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: select <index|all|none>"
	match args[0]:
		"all":
			select_all()
		"none":
			clear_selection()
		_:
			if not args[0].is_valid_int():
				return "Usage: select <index|all|none>"
			var m := get_member(args[0].to_int())
			if m == null:
				return "No party member %s (have %d)." % [args[0], members.size()]
			select_only(m)
	return "Selected: %s" % _overlay_text()
