extends GutTest
## F-005: EventBus signal contract. Every declared signal must appear here, and vice versa.

var actor: Node
var killer: Node
var item: RefCounted
var contract: Dictionary  # signal name -> sample args
var received: Array


func before_all() -> void:
	actor = Node.new()
	killer = Node.new()
	item = RefCounted.new()
	contract = {
		"game_state_changed": [0, 1],
		"actor_died": [actor, killer],
		"item_picked_up": [actor, item],
		"member_leveled": [actor, 5],
		"party_wiped": [],
		"party_changed": [],
		"selection_changed": [],
		"tactical_pause_toggled": [true],
		"chunk_loaded": [&"cave_01"],
		"chunk_unloaded": [&"cave_01"],
		"run_started": [&"entrance"],
		"run_ended": [1],
		"extraction_point_discovered": [&"lift_02"],
		"day_started": [3],
		"phase_changed": [2],
		"weekly_settlement": [7],
		"gold_changed": [1250],
		"debt_paid": [500, 9500],
		"item_sold": [item, 180, &"farmer"],
		"item_bought": [item, 40, &"wanderer"],
		"customer_walked_out": [&"noble"],
		"merchant_leveled": [4],
		"reputation_changed": [&"farmer", 30],
	}


func after_all() -> void:
	actor.free()
	killer.free()


func _declared_signals() -> Dictionary:
	var inherited := {}
	for s: Dictionary in ClassDB.class_get_signal_list("Node"):
		inherited[s.name] = true
	var declared := {}
	for s: Dictionary in EventBus.get_signal_list():
		if not inherited.has(s.name):
			declared[s.name] = s
	return declared


func _capture(a0: Variant = null, a1: Variant = null, a2: Variant = null) -> void:
	received = [a0, a1, a2]


func test_declared_signals_match_contract() -> void:
	var declared := _declared_signals().keys()
	declared.sort()
	var expected := contract.keys()
	expected.sort()
	assert_eq(declared, expected)


func test_arg_counts_match() -> void:
	var declared := _declared_signals()
	for signal_name: String in contract:
		if declared.has(signal_name):
			assert_eq(declared[signal_name].args.size(), contract[signal_name].size(), signal_name)


func test_each_signal_emits_and_is_received() -> void:
	watch_signals(EventBus)
	for signal_name: String in contract:
		var args: Array = contract[signal_name]
		received = []
		EventBus.connect(signal_name, _capture)
		EventBus.callv("emit_signal", [signal_name] + args)
		EventBus.disconnect(signal_name, _capture)
		assert_signal_emitted_with_parameters(EventBus, signal_name, args)
		var expected_received := args.duplicate()
		expected_received.resize(3)
		assert_eq(received, expected_received, "%s received by listener" % signal_name)
