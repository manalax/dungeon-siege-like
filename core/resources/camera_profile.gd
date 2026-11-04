class_name CameraProfile extends Resource
## Per-context limits and feel for RtsCamera (dungeon, town, shop). Speeds come from GameSettings.

@export_group("Zoom")
@export var min_distance: float = 8.0  ## metres from pivot, fully zoomed in
@export var max_distance: float = 32.0  ## fully zoomed out
@export var default_distance: float = 18.0  ## starting zoom; pan speed is defined at this distance
@export var zoom_step: float = 0.12  ## fraction of distance per wheel notch (× settings zoom speed)
@export_group("Pitch")
@export var pitch_at_min: float = 40.0  ## degrees below horizontal when fully zoomed in
@export var pitch_at_max: float = 60.0  ## when fully zoomed out
@export_group("Smoothing")
@export var follow_sharpness: float = 10.0  ## higher = snappier pivot
@export var rotate_sharpness: float = 14.0
@export var zoom_sharpness: float = 12.0
@export_group("Pivot")
@export var pivot_height: float = 1.0  ## above the follow target's feet
@export var use_bounds: bool = false
@export var bounds: Rect2 = Rect2(-20, -20, 40, 40)  ## XZ rectangle (x = world X, y = world Z)
