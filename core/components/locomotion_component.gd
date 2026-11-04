class_name LocomotionComponent extends Node
## Navmesh-driven movement for a CharacterBody3D parent (F-011).
## The parent calls physics_tick(delta) from its _physics_process.
##
## Reference implementation of the project's actor FSM pattern:
## enum State + _set_state() with _enter_state/_exit_state hooks + match in the tick.
##
## Arrival is measured on the XZ plane: navmesh polygons sit slightly above the floor,
## so 3D distance to a navmesh point may never drop under arrive_distance.

signal move_started(target: Vector3)
signal arrived(position: Vector3)
signal move_stopped

enum State { IDLE, MOVE }

const MAX_PATH_HEIGHT_OFFSET: float = 1.0

@export var data: ActorData
@export var agent_path: NodePath = ^"../NavigationAgent3D"
@export var arrive_distance: float = 0.3

var state: State = State.IDLE

var _body: CharacterBody3D
var _agent: NavigationAgent3D
var _target: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	assert(_body != null, "LocomotionComponent must be a child of a CharacterBody3D")
	_agent = get_node(agent_path) as NavigationAgent3D
	assert(_agent != null, "LocomotionComponent needs a NavigationAgent3D at agent_path")
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = arrive_distance
	_agent.avoidance_enabled = false
	if data == null:
		data = ActorData.new()


## Walks to the navmesh point closest to target. Returns that (possibly adjusted) point.
func move_to(target: Vector3) -> Vector3:
	var map := _agent.get_navigation_map()
	_sync_path_height_offset(map)
	_target = NavigationServer3D.map_get_closest_point(map, target)
	_agent.target_position = _target
	_set_state(State.MOVE)
	move_started.emit(_target)
	return _target


func stop() -> void:
	if state == State.MOVE:
		_set_state(State.IDLE)
		move_stopped.emit()


func is_moving() -> bool:
	return state == State.MOVE


func get_target() -> Vector3:
	return _target


func physics_tick(delta: float) -> void:
	var desired := Vector3.ZERO
	match state:
		State.IDLE:
			pass
		State.MOVE:
			if MathUtil.planar_distance(_body.global_position, _target) <= arrive_distance:
				_set_state(State.IDLE)
				arrived.emit(_body.global_position)
			else:
				var dir := _steer_direction()
				desired = dir * data.move_speed
				_turn_toward(dir, delta)

	var v := _body.velocity
	var horizontal := Vector3(v.x, 0.0, v.z).move_toward(desired, data.acceleration * delta)
	v.x = horizontal.x
	v.z = horizontal.z
	if _body.is_on_floor():
		v.y = 0.0
	else:
		v.y -= _gravity * delta
	_body.velocity = v
	_body.move_and_slide()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	_exit_state(state)
	state = new_state
	_enter_state(new_state)


func _enter_state(s: State) -> void:
	match s:
		State.IDLE:
			_agent.target_position = _body.global_position
		State.MOVE:
			pass


func _exit_state(_s: State) -> void:
	pass


## Baked navmeshes sit a cell or two above the floor (0.5 m in the test arena). The agent
## compares path points to the body in 3D, so without this offset it never "reaches" the
## first path point and stalls. Measured from the navmesh point under the body.
func _sync_path_height_offset(map: RID) -> void:
	var under := NavigationServer3D.map_get_closest_point(map, _body.global_position)
	var offset := under.y - _body.global_position.y
	if absf(offset) <= MAX_PATH_HEIGHT_OFFSET:
		_agent.path_height_offset = offset


func _steer_direction() -> Vector3:
	var pos := _body.global_position
	var dir := MathUtil.flatten_y(_agent.get_next_path_position() - pos)
	if dir.length_squared() < 0.0001:
		dir = MathUtil.flatten_y(_target - pos)
	return dir.normalized()


func _turn_toward(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)  # forward is -Z
	_body.rotation.y = rotate_toward(_body.rotation.y, target_yaw, deg_to_rad(data.turn_speed) * delta)
