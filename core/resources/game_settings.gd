class_name GameSettings
extends Resource
## Player-facing settings persisted to user://settings.cfg via ConfigFile.

const DEFAULT_PATH: String = "user://settings.cfg"
const VERSION: int = 1
const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 2.0

## field name -> config section. Save and load both iterate this, so they can't drift apart.
const FIELDS: Dictionary = {
	"camera_rotate_speed": "camera",
	"camera_drag_rotate_sensitivity": "camera",
	"camera_zoom_speed": "camera",
	"camera_pan_speed": "camera",
	"edge_scroll_enabled": "ui",
	"edge_scroll_margin_px": "ui",
	"ui_scale": "ui",
}

@export var camera_rotate_speed: float = 90.0  ## degrees per second (Q/E)
@export var camera_drag_rotate_sensitivity: float = 0.3  ## degrees per pixel (MMB drag)
@export var camera_zoom_speed: float = 1.0
@export var camera_pan_speed: float = 20.0  ## metres per second
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin_px: int = 12
@export_range(UI_SCALE_MIN, UI_SCALE_MAX) var ui_scale: float = 1.0


func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for field: String in FIELDS:
		cfg.set_value(FIELDS[field], field, get(field))
	return cfg.save(path)


## Missing/unreadable file -> defaults. Missing keys keep defaults; unknown keys are ignored.
static func load_from(path: String = DEFAULT_PATH) -> GameSettings:
	var settings := GameSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return settings
	for field: String in FIELDS:
		var default_value: Variant = settings.get(field)
		var value: Variant = cfg.get_value(FIELDS[field], field, default_value)
		if typeof(value) == typeof(default_value) or (value is int and default_value is float):
			settings.set(field, value)
	settings._clamp_values()
	return settings


func _clamp_values() -> void:
	ui_scale = clampf(ui_scale, UI_SCALE_MIN, UI_SCALE_MAX)
	camera_rotate_speed = maxf(camera_rotate_speed, 0.0)
	camera_drag_rotate_sensitivity = maxf(camera_drag_rotate_sensitivity, 0.0)
	camera_zoom_speed = maxf(camera_zoom_speed, 0.0)
	camera_pan_speed = maxf(camera_pan_speed, 0.0)
	edge_scroll_margin_px = maxi(edge_scroll_margin_px, 0)
