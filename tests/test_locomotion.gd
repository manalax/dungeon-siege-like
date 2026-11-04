extends GutTest
## F-011: LocomotionComponent navigates around obstacles, stops within 0.3 m, speed from data.

const ARENA_SCENE: PackedScene = preload("res://dungeon/test/test_arena.tscn")
const MEMBER_SCENE: PackedScene = preload("res://actors/party_member/party_member.tscn")
const ARRIVE: float = 0.3

var arena: TestArena
var _trackers: Array[Callable] = []


func before_each() -> void:
	arena = ARENA_SCENE.instantiate() as TestArena
	add_child_autofree(arena)
	if not arena.is_navmesh_ready:
		await wait_for_signal(arena.navmesh_ready, 5.0, "arena navmesh ready")
	await wait_physics_frames(1)


func _spawn(pos: Vector3, speed: float = -1.0) -> PartyMember:
	var m := MEMBER_SCENE.instantiate() as PartyMember
	if speed > 0.0:
		var d := (m.data as ActorData).duplicate() as ActorData
		d.move_speed = speed
		m.data = d
	arena.add_child(m)
	m.global_position = pos
	return m


## Records the member's position every physics frame; returns the shared array.
func _track(m: PartyMember) -> Array[Vector3]:
	var trail: Array[Vector3] = []
	var cb := func() -> void:
		if is_instance_valid(m):
			trail.append(m.global_position)
	get_tree().physics_frame.connect(cb)
	_trackers.append(cb)
	return trail


func _untrack_all() -> void:
	for cb: Callable in _trackers:
		if get_tree().physics_frame.is_connected(cb):
			get_tree().physics_frame.disconnect(cb)
	_trackers.clear()


func after_each() -> void:
	_untrack_all()


func _trail_length(trail: Array[Vector3]) -> float:
	var total := 0.0
	for i: int in range(1, trail.size()):
		total += MathUtil.planar_distance(trail[i - 1], trail[i])
	return total


func test_navigates_around_wall_and_stops_within_tolerance() -> void:
	var start := arena.spawn_point(0)
	var east := arena.waypoint(&"East")
	var m := _spawn(start)
	await wait_physics_frames(1)
	var trail := _track(m)
	m.move_to(east)
	await wait_for_signal(m.locomotion.arrived, 20.0, "arrived at East")
	assert_lt(MathUtil.planar_distance(m.global_position, east), ARRIVE, "stopped within 0.3 m")
	assert_gt(_trail_length(trail), MathUtil.planar_distance(start, east) * 1.3, "walked around the wall")
	_untrack_all()
	# Wall is 1 m thick at x=0, spanning z -15..15; the capsule (r 0.4) must never overlap it.
	for p: Vector3 in trail:
		var dx := maxf(absf(p.x) - 0.5, 0.0)
		var dz := maxf(absf(p.z) - 15.0, 0.0)
		var overlaps := Vector2(dx, dz).length() < 0.4
		assert_false(overlaps, "member at %s overlaps the wall" % p)
		if overlaps:
			break


func test_stops_and_stays_put() -> void:
	var m := _spawn(Vector3(-18, 0, 14))
	await wait_physics_frames(1)
	m.move_to(Vector3(-14, 0, 14))
	await wait_for_signal(m.locomotion.arrived, 10.0, "arrived")
	assert_eq(m.locomotion.state, LocomotionComponent.State.IDLE)
	await wait_physics_frames(20)
	var settled := m.global_position
	await wait_physics_frames(10)
	assert_lt(MathUtil.planar_distance(m.global_position, settled), 0.05, "doesn't drift")
	assert_lt(MathUtil.flatten_y(m.velocity).length(), 0.01, "velocity ~0")
	assert_lt(MathUtil.planar_distance(m.global_position, Vector3(-14, 0, 14)), ARRIVE, "still within 0.3 m")


func test_speed_is_data_driven() -> void:
	var slow := _spawn(Vector3(-18, 0, 14), 2.0)
	var fast := _spawn(Vector3(-18, 0, 17), 6.0)
	await wait_physics_frames(1)
	var times := {}
	var t0 := Time.get_ticks_msec()
	slow.locomotion.arrived.connect(func(_p: Vector3) -> void: times["slow"] = Time.get_ticks_msec() - t0)
	fast.locomotion.arrived.connect(func(_p: Vector3) -> void: times["fast"] = Time.get_ticks_msec() - t0)
	slow.move_to(Vector3(-8, 0, 14))
	fast.move_to(Vector3(-8, 0, 17))
	await wait_for_signal(slow.locomotion.arrived, 15.0, "slow arrived")
	assert_true(times.has("fast") and times.has("slow"), "both arrived")
	if times.has("fast") and times.has("slow"):
		assert_lt(times.fast, times.slow, "fast arrives first")
		assert_gt(float(times.slow) / times.fast, 2.0, "fast is >2x quicker (speeds 6 vs 2)")


func test_unreachable_target_goes_to_closest_point() -> void:
	var rock := Vector3(-10, 0, -8)
	var m := _spawn(arena.spawn_point(0))
	await wait_physics_frames(1)
	var dest := m.move_to(rock)
	assert_gt(MathUtil.planar_distance(dest, rock), 1.5, "adjusted target is outside the rock (r 1.5)")
	await wait_for_signal(m.locomotion.arrived, 10.0, "arrived near rock")
	assert_lt(MathUtil.planar_distance(m.global_position, dest), ARRIVE, "arrived at the adjusted point")


func test_stop_mid_move() -> void:
	var m := _spawn(arena.spawn_point(1))
	await wait_physics_frames(1)
	watch_signals(m.locomotion)
	m.move_to(arena.waypoint(&"East"))
	await wait_physics_frames(30)
	m.stop()
	assert_eq(m.locomotion.state, LocomotionComponent.State.IDLE)
	await wait_physics_frames(20)
	assert_lt(MathUtil.flatten_y(m.velocity).length(), 0.01, "decelerated to rest")
	assert_signal_emitted(m.locomotion, "move_stopped")
	assert_signal_not_emitted(m.locomotion, "arrived")


func test_faces_travel_direction() -> void:
	var m := _spawn(Vector3(-18, 0, 12))
	await wait_physics_frames(1)
	m.move_to(Vector3(-12, 0, 12))  # straight along +X
	await wait_for_signal(m.locomotion.arrived, 10.0, "arrived")
	var forward := -m.global_transform.basis.z
	assert_lt(rad_to_deg(MathUtil.flatten_y(forward).angle_to(Vector3.RIGHT)), 10.0, "faces +X")


func test_agent_uses_arrive_distance() -> void:
	var m := _spawn(arena.spawn_point(2))
	await wait_physics_frames(1)
	assert_almost_eq(m.locomotion.arrive_distance, ARRIVE, 0.0001)
	assert_almost_eq(m.get_node("NavigationAgent3D").target_desired_distance, ARRIVE, 0.0001)
