extends SceneTree
## Writes every action in InputActions.ACTIONS into project.godot's [input] section.
## Usage: $GODOT --headless --path . -s res://tools/generate_input_map.gd


func _init() -> void:
	for action: String in InputActions.ACTIONS:
		ProjectSettings.set_setting("input/" + action, {
			"deadzone": InputActions.DEADZONE,
			"events": InputActions.build_events(action),
		})
	var err := ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %s" % error_string(err))
		quit(1)
		return
	print("Wrote %d input actions to project.godot" % InputActions.ACTIONS.size())
	quit()
