extends GutTest
## F-004: RNG determinism and distribution.


func _sequence(rng: RNG) -> Array:
	var out: Array = []
	for i: int in 40:
		out.append(rng.randi_range(0, 1000))
		out.append(rng.roll_range(Vector2i(1, 6)))
		out.append(rng.chance(0.3))
		out.append(rng.weighted_index([1, 2, 3]))
		out.append(rng.pick(["a", "b", "c"]))
	var arr := [1, 2, 3, 4, 5, 6, 7, 8]
	rng.shuffle(arr)
	out.append(arr)
	return out


func test_same_seed_same_sequence() -> void:
	assert_eq(_sequence(RNG.new(1234)), _sequence(RNG.new(1234)))


func test_different_seed_different_sequence() -> void:
	assert_ne(_sequence(RNG.new(1234)), _sequence(RNG.new(4321)))


func test_seed_zero_picks_random_seed() -> void:
	assert_ne(RNG.new(0).seed_value, 0)


func test_state_save_and_restore_replays() -> void:
	var rng := RNG.new(99)
	rng.randf()
	var state := rng.get_state()
	var first := [rng.randf(), rng.randi_range(0, 100)]
	rng.set_state(state)
	assert_eq([rng.randf(), rng.randi_range(0, 100)], first)


func test_derive_is_deterministic_and_independent() -> void:
	var a := RNG.new(5)
	var b := RNG.new(5)
	assert_eq(a.derive("loot").randf(), b.derive("loot").randf(), "same name -> same child")
	assert_ne(a.derive("loot").randf(), a.derive("ai").randf(), "different names differ")
	var parent := RNG.new(5)
	var reference := RNG.new(5)
	var child := parent.derive("loot")
	for i: int in 10:
		child.randf()
	assert_eq(parent.randf(), reference.randf(), "child draws don't move parent")


func test_weighted_distribution_sane() -> void:
	var rng := RNG.new(42)
	var counts := [0, 0, 0]
	var n := 20000
	for i: int in n:
		counts[rng.weighted_index([1, 2, 7])] += 1
	var expected := [0.10, 0.20, 0.70]
	for i: int in 3:
		var share := float(counts[i]) / n
		assert_almost_eq(share, expected[i], 0.015, "bucket %d share %.3f" % [i, share])


func test_zero_and_negative_weights_never_picked() -> void:
	var rng := RNG.new(7)
	for i: int in 5000:
		assert_eq(rng.weighted_index(PackedFloat32Array([0.0, 3.0, -1.0, 0.0])), 1)


func test_all_zero_weights_returns_minus_one() -> void:
	assert_eq(RNG.new(1).weighted_index([0, 0]), -1)
	assert_push_warning("no positive weights")


func test_weighted_pick_and_dict() -> void:
	var rng := RNG.new(3)
	assert_eq(rng.weighted_pick(["never", "always"], [0, 1]), "always")
	assert_eq(rng.weighted_pick_dict({"x": 0.0, "y": 5.0}), "y")


func test_weighted_pick_length_mismatch() -> void:
	assert_null(RNG.new(3).weighted_pick(["a", "b"], [1]))
	assert_push_error("differ in length")


func test_roll_range_inclusive_and_normalised() -> void:
	var rng := RNG.new(11)
	var seen := {}
	for i: int in 2000:
		var v := rng.roll_range(Vector2i(1, 4))
		assert_between(v, 1, 4)
		seen[v] = true
	assert_true(seen.has(1) and seen.has(4), "both bounds reached")
	for i: int in 200:
		assert_between(rng.roll_range(Vector2i(4, 1)), 1, 4)
		assert_between(rng.roll_rangef(Vector2(2.0, 1.0)), 1.0, 2.0)


func test_chance_extremes_consume_one_draw() -> void:
	var a := RNG.new(8)
	var b := RNG.new(8)
	for i: int in 50:
		assert_false(a.chance(0.0))
		b.randf()
		assert_true(a.chance(1.0))
		b.randf()
	assert_eq(a.randf(), b.randf(), "sequences still aligned")


func test_shuffle_is_deterministic_permutation() -> void:
	var a := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var b := a.duplicate()
	RNG.new(21).shuffle(a)
	RNG.new(21).shuffle(b)
	assert_eq(a, b)
	var sorted := a.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])


func test_pick_empty_returns_null() -> void:
	assert_null(RNG.new(1).pick([]))
