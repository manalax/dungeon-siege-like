class_name RNG
extends RefCounted
## Seedable random helper (GDD §3.3). ALL gameplay randomness goes through an RNG instance.
##
## Each system owns its own stream (or derives one: root.derive("loot")) so rolls in one
## system never shift another's sequence. Never use global randi()/randf() or Array.shuffle().
## chance() always consumes exactly one draw, even for p <= 0 or p >= 1.

## Seed actually in use (a random one is chosen when constructed with 0).
var seed_value: int:
	get:
		return _rng.seed

var _rng := RandomNumberGenerator.new()


func _init(seed_value_: int = 0) -> void:
	if seed_value_ == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value_


func get_state() -> int:
	return _rng.state


func set_state(s: int) -> void:
	_rng.state = s


## Independent child stream: same parent seed + name -> same child; drawing from it never moves the parent.
func derive(stream_name: String) -> RNG:
	var child_seed := hash([_rng.seed, stream_name])
	return RNG.new(child_seed if child_seed != 0 else 1)


func randi_range(lo: int, hi: int) -> int:
	return _rng.randi_range(lo, hi)


func randf() -> float:
	return _rng.randf()


func randf_range(lo: float, hi: float) -> float:
	return _rng.randf_range(lo, hi)


## Inclusive integer roll over [r.x, r.y]; a reversed range is normalised.
func roll_range(r: Vector2i) -> int:
	return _rng.randi_range(mini(r.x, r.y), maxi(r.x, r.y))


func roll_rangef(r: Vector2) -> float:
	return _rng.randf_range(minf(r.x, r.y), maxf(r.x, r.y))


## True with probability p (clamped to 0..1). Always consumes one draw.
func chance(p: float) -> bool:
	return _rng.randf() < clampf(p, 0.0, 1.0)


## Index picked proportionally to weights (Array or Packed*Array). Non-positive weights are never picked.
## Returns -1 if no weight is positive.
func weighted_index(weights: Variant) -> int:
	var total := 0.0
	for w: Variant in weights:
		if w > 0:
			total += w
	if total <= 0.0:
		push_warning("RNG.weighted_index: no positive weights")
		return -1
	var roll := _rng.randf() * total
	var last_valid := -1
	for i: int in weights.size():
		var w: float = weights[i]
		if w <= 0.0:
			continue
		last_valid = i
		roll -= w
		if roll < 0.0:
			return i
	return last_valid  # float rounding guard


func weighted_pick(items: Array, weights: Variant) -> Variant:
	if items.size() != weights.size():
		push_error("RNG.weighted_pick: items (%d) and weights (%d) differ in length" % [items.size(), weights.size()])
		return null
	var i := weighted_index(weights)
	return null if i == -1 else items[i]


## Picks a key from {item: weight}. Dictionary order is insertion order, so this is deterministic.
func weighted_pick_dict(weights: Dictionary) -> Variant:
	return weighted_pick(weights.keys(), weights.values())


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## In-place Fisher–Yates shuffle using this stream (Array.shuffle() uses the global RNG).
func shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
