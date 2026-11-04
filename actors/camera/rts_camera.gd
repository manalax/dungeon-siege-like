class_name RtsCamera extends Node3D
## Orbit camera (F-012): pivot + yaw + distance, pitch tied to zoom, smoothed follow.
##
## - Speeds come from Game.settings (read live); limits/feel from `profile` (CameraProfile).
## - Any manual pan (WASD / screen edge) turns follow off; V snaps back and resumes.
## - Uses real elapsed time, so it keeps working during tactical pause / time_scale changes.
## - Follows `get_global_transform_interpolated()` (physics interpolation is on project-wide),
##   so a target moving at 60 Hz physics doesn't jitter on high-refresh displays.

@export var profile: CameraProfile
@export var follow_target: Node3D
## Tests turn this off and drive process_input()/step() with fixed deltas.
@export var auto_process: bool = true

var _pivot: Vector3
var _pivot_target: Vector3
var _yaw: float = 0.0  # degrees, wrapped
var _yaw_target: float = 0.0
var _distance: float
var _distance_target: float
var _following: bool = false
var _last_usec: int = 0
## Edge pan needs the cursor really inside the window; before it ever enters (and in
## headless runs) the reported mouse position is (0, 0), which reads as a corner.
var _mouse_inside: bool = false

@onready var camera: Camera3D = $Camera3D
@onready var picker: Picker = $Picker


func _ready() -> void:
	if profile == null:
		profile = CameraProfile.new()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_ALWAYS
	_yaw = MathUtil.wrap_degrees(rad_to_deg(global_rotation.y))
	_yaw_target = _yaw
	_distance = profile.default_distance
	_distance_target = _distance
	_pivot = _clamp_to_bounds(global_position)
	_pivot_target = _pivot
	if follow_target != null:
		set_following(true)
		_pivot = _pivot_target
	_last_usec = Time.get_ticks_usec()
	get_window().mouse_entered.connect(_on_mouse_entered)
	get_window().mouse_exited.connect(_on_mouse_exited)
	step(0.0)
	DebugConsole.set_overlay_row("Camera", _overlay_text)


func _exit_tree() -> void:
	DebugConsole.remove_overlay_row("Camera", _overlay_text)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _last_usec) / 1_000_000.0, 0.0, 0.1)
	_last_usec = now
	if not auto_process:
		return
	process_input(dt)
	step(dt)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		zoom_steps(1.0)
	elif event.is_action_pressed("camera_zoom_out"):
		zoom_steps(-1.0)
	elif event.is_action_pressed("camera_follow_toggle"):
		toggle_follow()
	elif event is InputEventMouseMotion and Input.is_action_pressed("camera_rotate_drag"):
		rotate_by(-(event as InputEventMouseMotion).relative.x * _settings().camera_drag_rotate_sensitivity)


# --- Public API -------------------------------------------------------------

func set_follow_target(target: Node3D) -> void:
	follow_target = target
	set_following(target != null)


func set_following(on: bool) -> void:
	_following = on and follow_target != null
	if _following:
		_pivot_target = _clamp_to_bounds(_follow_point())


func toggle_follow() -> void:
	set_following(not _following)


func is_following() -> bool:
	return _following


## Positive n zooms in. Each notch scales distance by (1 - zoom_step × settings zoom speed).
func zoom_steps(n: float) -> void:
	var s := clampf(profile.zoom_step * _settings().camera_zoom_speed, 0.0, 0.9)
	_distance_target = clampf(_distance_target * pow(1.0 - s, n), profile.min_distance, profile.max_distance)


func rotate_by(degrees: float) -> void:
	_yaw_target = MathUtil.wrap_degrees(_yaw_target + degrees)


## Camera-relative pan in metres: x = right, y = forward. Turns follow off.
func pan_by(local: Vector2) -> void:
	if local == Vector2.ZERO:
		return
	_following = false
	var basis_yaw := Basis(Vector3.UP, deg_to_rad(_yaw))
	var right := basis_yaw * Vector3.RIGHT
	var forward := basis_yaw * Vector3.FORWARD
	_pivot_target = _clamp_to_bounds(_pivot_target + right * local.x + forward * local.y)


## Reads held keys / screen edge and applies rotate & pan for this frame.
func process_input(dt: float) -> void:
	var s := _settings()
	if get_viewport().gui_get_focus_owner() == null:
		var rot := Input.get_action_strength("camera_rotate_left") - Input.get_action_strength("camera_rotate_right")
		if rot != 0.0:
			rotate_by(rot * s.camera_rotate_speed * dt)
		var pan := Vector2(
				Input.get_action_strength("camera_pan_right") - Input.get_action_strength("camera_pan_left"),
				Input.get_action_strength("camera_pan_forward") - Input.get_action_strength("camera_pan_back"))
		if pan != Vector2.ZERO:
			pan_by(pan.limit_length(1.0) * _pan_speed() * dt)
	if s.edge_scroll_enabled and _mouse_inside and get_window().has_focus():
		var vp := get_viewport()
		var edge := edge_pan_direction(vp.get_mouse_position(), vp.get_visible_rect().size, s.edge_scroll_margin_px)
		if edge != Vector2.ZERO:
			pan_by(edge * _pan_speed() * dt)


## Advances smoothing by dt seconds and positions the Camera3D.
func step(dt: float) -> void:
	if _following and is_instance_valid(follow_target):
		_pivot_target = _clamp_to_bounds(_follow_point())
	_pivot = _pivot.lerp(_pivot_target, _blend(profile.follow_sharpness, dt))
	_yaw = MathUtil.wrap_degrees(_yaw + MathUtil.wrap_degrees(_yaw_target - _yaw) * _blend(profile.rotate_sharpness, dt))
	_distance = lerpf(_distance, _distance_target, _blend(profile.zoom_sharpness, dt))
	var offset := Basis(Vector3.UP, deg_to_rad(_yaw)) * Basis(Vector3.RIGHT, -deg_to_rad(get_pitch())) * Vector3(0.0, 0.0, _distance)
	camera.global_position = _pivot + offset
	camera.look_at(_pivot, Vector3.UP)


func get_pitch() -> float:
	var t := clampf(inverse_lerp(profile.min_distance, profile.max_distance, _distance), 0.0, 1.0)
	return lerpf(profile.pitch_at_min, profile.pitch_at_max, t)


func get_pivot() -> Vector3:
	return _pivot


func get_pivot_target() -> Vector3:
	return _pivot_target


func get_yaw() -> float:
	return _yaw


func get_yaw_target() -> float:
	return _yaw_target


func get_distance() -> float:
	return _distance


func get_distance_target() -> float:
	return _distance_target


## Pure: pan direction (x = right, y = forward) for a mouse position near the viewport edge.
## Zero when the mouse is outside the viewport or away from every edge.
static func edge_pan_direction(mouse: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > viewport_size.x or mouse.y > viewport_size.y:
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x <= margin:
		dir.x = -1.0
	elif mouse.x >= viewport_size.x - margin:
		dir.x = 1.0
	if mouse.y <= margin:
		dir.y = 1.0
	elif mouse.y >= viewport_size.y - margin:
		dir.y = -1.0
	return dir.normalized()


# --- Internals --------------------------------------------------------------

func _on_mouse_entered() -> void:
	_mouse_inside = true


func _on_mouse_exited() -> void:
	_mouse_inside = false


func _settings() -> GameSettings:
	return Game.settings if Game.settings != null else GameSettings.new()


## Pan speed in m/s, scaled so on-screen speed stays constant across zoom levels.
func _pan_speed() -> float:
	return _settings().camera_pan_speed * _distance / profile.default_distance


func _follow_point() -> Vector3:
	return follow_target.get_global_transform_interpolated().origin + Vector3.UP * profile.pivot_height


func _clamp_to_bounds(p: Vector3) -> Vector3:
	if not profile.use_bounds:
		return p
	var b := profile.bounds
	return Vector3(clampf(p.x, b.position.x, b.end.x), p.y, clampf(p.z, b.position.y, b.end.y))


static func _blend(sharpness: float, dt: float) -> float:
	return 1.0 - exp(-sharpness * dt)


func _overlay_text() -> String:
	return "%s  d=%.1f  yaw=%d°  pitch=%d°" % ["follow" if _following else "free", _distance, roundi(_yaw), roundi(get_pitch())]
