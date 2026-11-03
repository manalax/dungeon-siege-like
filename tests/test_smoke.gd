extends GutTest
## F-000 smoke tests: project wiring sanity checks.

const EXPECTED_LAYERS: PackedStringArray = [
	"world", "party", "monsters", "npcs", "projectiles",
	"pickups", "triggers", "click_pick", "build_grid",
]


func test_trivial() -> void:
	assert_eq(1 + 1, 2)


func test_collision_layer_names() -> void:
	for i: int in EXPECTED_LAYERS.size():
		var key := "layer_names/3d_physics/layer_%d" % (i + 1)
		assert_eq(ProjectSettings.get_setting(key, ""), EXPECTED_LAYERS[i], key)


func test_main_scene_is_node3d() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var packed := load(path) as PackedScene
	assert_not_null(packed, "main scene loads")
	var root := packed.instantiate()
	assert_true(root is Node3D, "main scene root is Node3D")
	root.free()
