extends GutTest
## F-010: test arena navmesh bakes and obstacles block pathing.

const ARENA_SCENE: PackedScene = preload("res://dungeon/test/test_arena.tscn")
const ARRIVE_TOLERANCE: float = 0.3
## Path samples must stay this far outside obstacle footprints (half the agent radius,
## leaving room for navmesh cell rounding).
const FOOTPRINT_MARGIN: float = 0.2

var arena: TestArena
var map: RID


func before_each() -> void:
	arena = ARENA_SCENE.instantiate() as TestArena
	add_child_autofree(arena)
	if not arena.is_navmesh_ready:
		await wait_for_signal(arena.navmesh_ready, 5.0, "arena navmesh ready")
	# Let the emit finish before the test (and autofree) can touch the arena.
	await wait_physics_frames(1)
	map = arena.nav_region.get_navigation_map()


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(map, from, to, true)


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i: int in range(1, path.size()):
		total += MathUtil.planar_distance(path[i - 1], path[i])
	return total


## {name: {"center": Vector2, "box": Vector2 half-extents} or {"center", "radius"}} from the scene's shapes.
func _footprints() -> Dictionary:
	var out := {}
	for body: Node in arena.get_node("NavigationRegion3D/Obstacles").get_children():
		var shape_node := NodeUtil.find_component(body, CollisionShape3D) as CollisionShape3D
		var p := (body as Node3D).global_position
		var center := Vector2(p.x, p.z)
		if shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			out[body.name] = {"center": center, "box": Vector2(size.x, size.z) * 0.5}
		elif shape_node.shape is CylinderShape3D:
			out[body.name] = {"center": center, "radius": (shape_node.shape as CylinderShape3D).radius}
	return out


func _inside(fp: Dictionary, pt: Vector2, margin: float) -> bool:
	var d: Vector2 = pt - fp.center
	if fp.has("box"):
		return absf(d.x) < fp.box.x + margin and absf(d.y) < fp.box.y + margin
	return d.length() < fp.radius + margin


func _assert_path_avoids_obstacles(path: PackedVector3Array) -> void:
	var fps := _footprints()
	for i: int in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		var steps := maxi(1, ceili(a.distance_to(b) / 0.25))
		for s: int in steps + 1:
			var pt := a.lerp(b, float(s) / steps)
			for obstacle_name: String in fps:
				assert_false(_inside(fps[obstacle_name], pt, FOOTPRINT_MARGIN),
						"path point %s inside %s" % [pt, obstacle_name])


func test_navmesh_bakes() -> void:
	assert_true(arena.is_navmesh_ready, "navmesh_ready fired")
	assert_gt(arena.nav_region.navigation_mesh.get_polygon_count(), 0, "navmesh has polygons")
	var west := arena.waypoint(&"West")
	var snapped := NavigationServer3D.map_get_closest_point(map, west)
	assert_lt(MathUtil.planar_distance(snapped, west), ARRIVE_TOLERANCE, "floor is walkable")


func test_wall_forces_detour() -> void:
	var west := arena.waypoint(&"West")
	var east := arena.waypoint(&"East")
	var path := _path(west, east)
	assert_gt(path.size(), 2, "path has turns")
	assert_lt(MathUtil.planar_distance(path[path.size() - 1], east), ARRIVE_TOLERANCE, "path reaches East")
	var straight := MathUtil.planar_distance(west, east)
	assert_gt(_path_length(path), straight * 1.5, "path detours around the wall")
	_assert_path_avoids_obstacles(path)


func test_obstacle_centres_not_walkable() -> void:
	var fps := _footprints()
	assert_eq(fps.size(), 7, "all obstacles found (wall, 3 crates, rock, 2 pillars)")
	for obstacle_name: String in fps:
		var c: Vector2 = fps[obstacle_name].center
		var snapped := NavigationServer3D.map_get_closest_point(map, Vector3(c.x, 0.0, c.y))
		assert_false(_inside(fps[obstacle_name], Vector2(snapped.x, snapped.z), 0.0),
				"closest walkable point to %s centre is outside it" % obstacle_name)


func test_narrow_gap_is_passable() -> void:
	var from := arena.waypoint(&"GapWest")
	var to := arena.waypoint(&"GapEast")
	var path := _path(from, to)
	assert_lt(MathUtil.planar_distance(path[path.size() - 1], to), ARRIVE_TOLERANCE, "path reaches GapEast")
	assert_lt(_path_length(path), MathUtil.planar_distance(from, to) * 1.1, "goes straight through the gap")
	_assert_path_avoids_obstacles(path)


func test_lighting_and_sky() -> void:
	var env_node := NodeUtil.find_component(arena, WorldEnvironment) as WorldEnvironment
	assert_not_null(env_node)
	assert_not_null(env_node.environment.sky, "environment has a sky")
	assert_not_null(NodeUtil.find_component(arena, DirectionalLight3D), "has a sun")


func test_spawn_points() -> void:
	for i: int in 3:
		var p := arena.spawn_point(i)
		var snapped := NavigationServer3D.map_get_closest_point(map, p)
		assert_lt(MathUtil.planar_distance(snapped, p), ARRIVE_TOLERANCE, "spawn %d on navmesh" % i)
