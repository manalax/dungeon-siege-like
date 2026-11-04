extends GutTest
## F-012: RtsCamera zoom/pitch, rotation, pan, follow, bounds, settings-driven speeds, smoothness.

const CAMERA_SCENE: PackedScene = preload("res://actors/camera/rts_camera.tscn")
const DT: float = 1.0 / 60.0

var _saved_settings: Dictionary = {}


func before_each() -> void:
	for field: String in GameSettings.FIELDS:
		_saved_settings[field] = Game.settings.get(field)


func after_each() -> void:
	for field: String in _saved_settings:
		Game.settings.set(field, _saved_settings[field])
	for action: String in ["camera_rotate_left", "camera_rotate_right", "camera_pan_forward",
			"camera_pan_back", "camera_pan_left", "camera_pan_right"]:
		Input.action_release(action)
	Engine.time_scale = 1.0


func _profile(use_bounds: bool = false) -> CameraProfile:
	var p := CameraProfile.new()
	p.use_bounds = use_bounds
	return p


func _target(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var t := Node3D.new()
	t.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # interpolated == actual
	add_child_autofree(t)
	t.global_position = pos
	return t


func _cam(profile: CameraProfile = null, target: Node3D = null, auto: bool = false) -> RtsCamera:
	var cam := CAMERA_SCENE.instantiate() as RtsCamera
	cam.auto_process = auto
	cam.profile = profile if profile != null else _profile()
	cam.follow_target = target
	add_child_autofree(cam)
	return cam


func _settle(cam: RtsCamera, seconds: float = 3.0) -> void:
	for i: int in int(seconds / DT):
		cam.step(DT)


# --- Zoom & pitch -------------------------------------------------------------

func test_zoom_clamped() -> void:
	var cam := _cam()
	cam.zoom_steps(100)
	assert_almost_eq(cam.get_distance_target(), cam.profile.min_distance, 0.001)
	cam.zoom_steps(-100)
	assert_almost_eq(cam.get_distance_target(), cam.profile.max_distance, 0.001)


func test_pitch_tied_to_zoom() -> void:
	var cam := _cam()
	cam.zoom_steps(100)
	_settle(cam)
	assert_almost_eq(cam.get_pitch(), 40.0, 0.5, "zoomed in")
	cam.zoom_steps(-100)
	_settle(cam)
	assert_almost_eq(cam.get_pitch(), 60.0, 0.5, "zoomed out")
	cam._distance = (cam.profile.min_distance + cam.profile.max_distance) * 0.5
	assert_almost_eq(cam.get_pitch(), 50.0, 0.5, "midpoint")


func test_zoom_speed_from_settings() -> void:
	var cam := _cam()
	var d0 := cam.get_distance_target()
	cam.zoom_steps(1)
	assert_almost_eq(cam.get_distance_target(), d0 * (1.0 - 0.12), 0.001, "one notch at speed 1")
	var cam2 := _cam()
	Game.settings.camera_zoom_speed = 2.0
	cam2.zoom_steps(1)
	assert_almost_eq(cam2.get_distance_target(), d0 * (1.0 - 0.24), 0.001, "double speed doubles the change")


# --- Rotation -----------------------------------------------------------------

func test_rotate_converges() -> void:
	var cam := _cam()
	cam.rotate_by(90)
	_settle(cam, 2.0)
	assert_almost_eq(cam.get_yaw(), 90.0, 0.1)


func test_yaw_wraps_the_short_way() -> void:
	var cam := _cam()
	cam.rotate_by(170)
	_settle(cam)
	cam.rotate_by(20)
	assert_almost_eq(cam.get_yaw_target(), -170.0, 0.001)
	for i: int in 120:
		cam.step(DT)
		assert_gt(absf(cam.get_yaw()), 165.0, "eases across ±180, never back through 0")
		if absf(cam.get_yaw()) <= 165.0:
			break
	assert_almost_eq(cam.get_yaw(), -170.0, 0.1)


func test_q_rotate_speed_from_settings() -> void:
	var cam := _cam()
	Game.settings.camera_rotate_speed = 90.0
	Input.action_press("camera_rotate_left")
	cam.process_input(1.0)
	assert_almost_eq(cam.get_yaw_target(), 90.0, 0.01)
	Input.action_release("camera_rotate_left")
	Game.settings.camera_rotate_speed = 30.0
	Input.action_press("camera_rotate_right")
	cam.process_input(1.0)
	assert_almost_eq(cam.get_yaw_target(), 60.0, 0.01)


# --- Pan ----------------------------------------------------------------------

func test_pan_is_camera_relative() -> void:
	var cam := _cam()
	cam.rotate_by(90)
	_settle(cam)
	var before := cam.get_pivot_target()
	cam.pan_by(Vector2(0, 1))  # forward 1 m
	var moved := cam.get_pivot_target() - before
	var cam_forward := MathUtil.flatten_y(-cam.camera.global_basis.z).normalized()
	assert_almost_eq(moved.length(), 1.0, 0.001)
	assert_almost_eq(moved.normalized().dot(cam_forward), 1.0, 0.001, "moves along the camera's view on XZ")


func test_pan_speed_from_settings_and_scales_with_zoom() -> void:
	var cam := _cam()
	Game.settings.camera_pan_speed = 10.0
	Input.action_press("camera_pan_forward")
	var p0 := cam.get_pivot_target()
	cam.process_input(1.0)
	assert_almost_eq(MathUtil.planar_distance(p0, cam.get_pivot_target()), 10.0, 0.01, "settings speed at default zoom")
	cam.zoom_steps(-100)  # to max distance (32 vs default 18)
	_settle(cam)
	var p1 := cam.get_pivot_target()
	cam.process_input(1.0)
	var expected := 10.0 * cam.get_distance() / cam.profile.default_distance
	assert_almost_eq(MathUtil.planar_distance(p1, cam.get_pivot_target()), expected, 0.05, "faster when zoomed out")


func test_pan_breaks_follow() -> void:
	var cam := _cam(null, _target(Vector3(3, 0, 3)))
	assert_true(cam.is_following())
	cam.pan_by(Vector2(1, 0))
	assert_false(cam.is_following())


func test_keyboard_ignored_while_ui_has_focus() -> void:
	var cam := _cam()
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	await wait_process_frames(1)
	Input.action_press("camera_pan_forward")
	var p0 := cam.get_pivot_target()
	cam.process_input(1.0)
	assert_eq(cam.get_pivot_target(), p0, "typing in a text field doesn't pan")
	edit.release_focus()


func test_bounds_clamp_pivot() -> void:
	var cam := _cam(_profile(true))
	cam.pan_by(Vector2(0, 1000))  # far "forward" (-Z at yaw 0)
	assert_almost_eq(cam.get_pivot_target().z, -20.0, 0.001)
	cam.pan_by(Vector2(1000, 0))
	assert_almost_eq(cam.get_pivot_target().x, 20.0, 0.001)


func test_edge_pan_direction() -> void:
	var size := Vector2(1000, 800)
	assert_eq(RtsCamera.edge_pan_direction(Vector2(5, 400), size, 12), Vector2(-1, 0), "left edge")
	assert_eq(RtsCamera.edge_pan_direction(Vector2(995, 400), size, 12), Vector2(1, 0), "right edge")
	assert_eq(RtsCamera.edge_pan_direction(Vector2(500, 3), size, 12), Vector2(0, 1), "top = forward")
	assert_eq(RtsCamera.edge_pan_direction(Vector2(500, 0), size, 12).y, 1.0)
	assert_eq(RtsCamera.edge_pan_direction(Vector2(500, 795), size, 12), Vector2(0, -1), "bottom = back")
	assert_almost_eq(RtsCamera.edge_pan_direction(Vector2(2, 2), size, 12), Vector2(-1, 1).normalized(), Vector2.ONE * 0.001, "corner")
	assert_eq(RtsCamera.edge_pan_direction(Vector2(500, 400), size, 12), Vector2.ZERO, "centre")
	assert_eq(RtsCamera.edge_pan_direction(Vector2(-50, 400), size, 12), Vector2.ZERO, "outside the window")


# --- Follow -------------------------------------------------------------------

func test_starts_following_target() -> void:
	var t := _target(Vector3(5, 0, -4))
	var cam := _cam(null, t)
	assert_true(cam.is_following())
	assert_almost_eq(cam.get_pivot(), Vector3(5, 1, -4), Vector3.ONE * 0.001, "centred on target + pivot height")


func test_toggle_follow_snaps_back() -> void:
	var t := _target(Vector3(2, 0, 2))
	var cam := _cam(null, t)
	cam.pan_by(Vector2(10, 0))
	assert_false(cam.is_following())
	cam.toggle_follow()
	assert_true(cam.is_following())
	assert_almost_eq(cam.get_pivot_target(), Vector3(2, 1, 2), Vector3.ONE * 0.001)
	cam.toggle_follow()
	assert_false(cam.is_following())


func test_follow_has_no_jitter_and_no_overshoot() -> void:
	var t := _target(Vector3.ZERO)
	var cam := _cam(null, t)
	var velocity := Vector3(4, 0, 0)
	var render_dt := 1.0 / 144.0
	var time := 0.0
	var positions: Array[Vector3] = []
	# Target moves at constant speed; camera steps at a rate unrelated to physics (144 Hz).
	for i: int in 432:  # 3 s
		time += render_dt
		t.global_position = velocity * time
		cam.step(render_dt)
		positions.append(cam.camera.global_position)
	var speeds: Array[float] = []
	for i: int in range(288, positions.size()):  # after 2 s of settling
		var d := positions[i] - positions[i - 1]
		assert_gt(d.x, 0.0, "never moves backwards")
		speeds.append(d.length() / render_dt)
	var lo: float = speeds.min()
	var hi: float = speeds.max()
	assert_lt((hi - lo) / ((hi + lo) * 0.5), 0.02, "frame-to-frame speed varies < 2%%")
	# Target stops: camera closes in monotonically without overshooting.
	var stop_point := t.global_position + Vector3.UP
	var last_gap := INF
	for i: int in 288:
		cam.step(render_dt)
		var gap := cam.get_pivot().x - stop_point.x
		assert_lt(gap, 0.0001, "no overshoot past the target")
		assert_lt(absf(gap), last_gap + 0.00001, "gap shrinks monotonically")
		last_gap = absf(gap)
	assert_lt(last_gap, 0.05, "settles on the stopped target")


# --- Timing -------------------------------------------------------------------

func test_uses_real_time_when_time_scale_is_zero() -> void:
	var cam := _cam(null, null, true)
	Engine.time_scale = 0.0
	Input.action_press("camera_rotate_left")
	for i: int in 20:
		await get_tree().process_frame
	Input.action_release("camera_rotate_left")
	Engine.time_scale = 1.0
	assert_gt(cam.get_yaw_target(), 0.0, "Q still rotates while the game is paused")


func test_overlay_row() -> void:
	_cam()
	DebugConsole.refresh_overlay()
	assert_string_contains(DebugConsole.overlay_text(), "Camera: free")


func test_no_edge_pan_until_mouse_enters_window() -> void:
	var cam := _cam()
	var p0 := cam.get_pivot_target()
	cam.process_input(1.0)  # headless: mouse reads (0,0) = a corner, but it never entered
	assert_eq(cam.get_pivot_target(), p0)
