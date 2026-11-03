extends Node
## InputMapSetup: registers any input action missing from the InputMap at startup (GDD §3.2).
## Bindings come from InputActions.ACTIONS. project.godot should already contain them all
## (written by tools/generate_input_map.gd); a warning here means the two have drifted.


func _ready() -> void:
	var added := InputActions.register_missing()
	if not added.is_empty():
		push_warning("InputMapSetup registered actions missing from project.godot: %s. Re-run tools/generate_input_map.gd." % ", ".join(added))
