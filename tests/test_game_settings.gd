extends GutTest
## F-001: GameSettings persistence.

const TEST_PATH: String = "user://test_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_round_trip_all_fields() -> void:
	var s := GameSettings.new()
	s.camera_rotate_speed = 45.0
	s.camera_drag_rotate_sensitivity = 0.7
	s.camera_zoom_speed = 2.5
	s.camera_pan_speed = 33.0
	s.edge_scroll_enabled = false
	s.edge_scroll_margin_px = 30
	s.ui_scale = 1.5
	assert_eq(s.save_to(TEST_PATH), OK)

	var loaded := GameSettings.load_from(TEST_PATH)
	for field: String in GameSettings.FIELDS:
		assert_eq(loaded.get(field), s.get(field), field)


func test_missing_file_returns_defaults() -> void:
	var loaded := GameSettings.load_from("user://does_not_exist.cfg")
	var defaults := GameSettings.new()
	for field: String in GameSettings.FIELDS:
		assert_eq(loaded.get(field), defaults.get(field), field)


func test_partial_file_keeps_defaults() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "camera_pan_speed", 5.0)
	cfg.set_value("ui", "unknown_future_key", 123)
	cfg.save(TEST_PATH)

	var loaded := GameSettings.load_from(TEST_PATH)
	assert_eq(loaded.camera_pan_speed, 5.0)
	assert_eq(loaded.ui_scale, GameSettings.new().ui_scale)
	assert_true(loaded.edge_scroll_enabled)


func test_ui_scale_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "ui_scale", 9.0)
	cfg.save(TEST_PATH)
	assert_eq(GameSettings.load_from(TEST_PATH).ui_scale, GameSettings.UI_SCALE_MAX)


func test_wrong_type_ignored() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "edge_scroll_enabled", "nope")
	cfg.save(TEST_PATH)
	assert_true(GameSettings.load_from(TEST_PATH).edge_scroll_enabled)
