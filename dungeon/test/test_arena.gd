class_name TestArena
extends Node3D
## F-010 test arena: flat floor + obstacles, navmesh baked at runtime from static colliders
## (works headless; offline per-chunk baking arrives with the chunk format in F-060).
##
## navmesh_ready fires only once the navigation map actually serves this region's navmesh
## (the map syncs 1–2 physics frames after baking), so listeners can path immediately.

signal navmesh_ready

@export var bake_on_ready: bool = true

var is_navmesh_ready: bool = false

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var camera: RtsCamera = $RtsCamera


func _ready() -> void:
	nav_region.bake_finished.connect(_on_bake_finished)
	if bake_on_ready:
		nav_region.bake_navigation_mesh(false)


func _exit_tree() -> void:
	if NavigationServer3D.map_changed.is_connected(_on_map_changed):
		NavigationServer3D.map_changed.disconnect(_on_map_changed)


func spawn_point(i: int) -> Vector3:
	return ($SpawnPoints.get_child(i) as Marker3D).global_position


func waypoint(waypoint_name: StringName) -> Vector3:
	return ($Waypoints.get_node(NodePath(waypoint_name)) as Marker3D).global_position


func _on_bake_finished() -> void:
	is_navmesh_ready = false
	if not NavigationServer3D.map_changed.is_connected(_on_map_changed):
		NavigationServer3D.map_changed.connect(_on_map_changed)


func _on_map_changed(map: RID) -> void:
	if map != nav_region.get_navigation_map():
		return
	if NavigationServer3D.map_get_closest_point_owner(map, spawn_point(0)) != nav_region.get_rid():
		return
	NavigationServer3D.map_changed.disconnect(_on_map_changed)
	is_navmesh_ready = true
	navmesh_ready.emit()
