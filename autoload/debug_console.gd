extends CanvasLayer
## DebugConsole: developer console and stats overlay (F-003). Debug builds only.
##
## Features register their own commands:
##   DebugConsole.register("gold", func(args: PackedStringArray) -> String: ..., "Add gold.", "gold <n>")
## and their own overlay rows:
##   DebugConsole.set_overlay_row("Chunks", func() -> String: return str(loaded_chunks.size()))
## Row owners: F-062 "Chunks", F-082 "Day". Actors join ACTORS_GROUP to be counted.

const ACTORS_GROUP: StringName = &"actors"
const HISTORY_MAX: int = 50
const OVERLAY_REFRESH_S: float = 0.25
const PLACEHOLDER: String = "—"

var _registry := DebugCommandRegistry.new()
var _history: PackedStringArray = []
var _history_index: int = -1
var _overlay_rows: Dictionary = {}  # key -> Callable, insertion-ordered

var _panel: PanelContainer
var _output: RichTextLabel
var _input_line: LineEdit
var _overlay: Label
var _overlay_timer: Timer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_register_builtins()
	_register_default_overlay_rows()
	if not OS.is_debug_build():
		set_process_input(false)
		_overlay.visible = false
		_overlay_timer.stop()


# --- Public API -------------------------------------------------------------

func register(command_name: String, callable: Callable, help: String, usage: String = "") -> void:
	_registry.register(command_name, callable, help, usage)


func unregister(command_name: String) -> void:
	_registry.unregister(command_name)


func has_command(command_name: String) -> bool:
	return _registry.has_command(command_name)


## Runs a command line, echoing it and its result to the output. Returns {ok, text}.
func execute(line: String) -> Dictionary:
	print_line("[color=gray]> %s[/color]" % _escape(line))
	var result := _registry.execute(line)
	if not result.text.is_empty():
		if result.ok:
			print_line(_escape(result.text))
		else:
			print_line("[color=#ff6b6b]%s[/color]" % _escape(result.text))
	return result


func print_line(bbcode_text: String) -> void:
	_output.append_text(bbcode_text + "\n")


func output_text() -> String:
	return _output.get_parsed_text()


func open() -> void:
	if not OS.is_debug_build():
		return
	_panel.visible = true
	_input_line.clear()
	_input_line.grab_focus.call_deferred()


func close() -> void:
	_panel.visible = false
	_input_line.release_focus()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func is_open() -> bool:
	return _panel.visible


## Adds or replaces an overlay row. provider: func() -> String
func set_overlay_row(key: String, provider: Callable) -> void:
	_overlay_rows[key] = provider
	refresh_overlay()


func remove_overlay_row(key: String) -> void:
	_overlay_rows.erase(key)
	refresh_overlay()


func set_overlay_visible(on: bool) -> void:
	_overlay.visible = on


func overlay_text() -> String:
	return _overlay.text


func refresh_overlay() -> void:
	var lines := PackedStringArray()
	for key: String in _overlay_rows:
		var provider: Callable = _overlay_rows[key]
		var value: String = str(provider.call()) if provider.is_valid() else PLACEHOLDER
		lines.append("%s: %s" % [key, value])
	_overlay.text = "\n".join(lines)


# --- Input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console_toggle") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _on_input_submitted(text: String) -> void:
	_input_line.clear()
	if text.strip_edges().is_empty():
		return
	if _history.is_empty() or _history[_history.size() - 1] != text:
		_history.append(text)
		if _history.size() > HISTORY_MAX:
			_history.remove_at(0)
	_history_index = -1
	execute(text)


func _on_input_gui_input(event: InputEvent) -> void:
	if _history.is_empty():
		return
	if event.is_action_pressed("ui_up"):
		_history_index = _history.size() - 1 if _history_index == -1 else maxi(_history_index - 1, 0)
	elif event.is_action_pressed("ui_down"):
		if _history_index == -1:
			return
		_history_index += 1
		if _history_index >= _history.size():
			_history_index = -1
			_input_line.clear()
			_input_line.accept_event()
			return
	else:
		return
	_input_line.text = _history[_history_index]
	_input_line.caret_column = _input_line.text.length()
	_input_line.accept_event()


# --- Built-ins --------------------------------------------------------------

func _register_builtins() -> void:
	register("clear", _cmd_clear, "Clear console output.")
	register("overlay", _cmd_overlay, "Show/hide the stats overlay.", "overlay [on|off]")
	register("timescale", _cmd_timescale, "Set Engine.time_scale (clamped).", "timescale <x>")
	register("state", _cmd_state, "Print or set Game state.", "state [%s]" % "|".join(_state_names()).to_lower())


func _cmd_clear(_args: PackedStringArray) -> String:
	_output.clear()
	return ""


func _cmd_overlay(args: PackedStringArray) -> String:
	var on := not _overlay.visible
	if not args.is_empty():
		on = args[0].to_lower() in ["on", "1", "true"]
	set_overlay_visible(on)
	return "Overlay %s." % ("on" if on else "off")


func _cmd_timescale(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Time scale: %s" % Game.get_time_scale()
	if not args[0].is_valid_float():
		return "Usage: timescale <x>"
	Game.set_time_scale(args[0].to_float())
	return "Time scale: %s" % Game.get_time_scale()


func _cmd_state(args: PackedStringArray) -> String:
	if args.is_empty():
		return "State: %s" % Game.State.find_key(Game.state)
	var key := args[0].to_upper()
	if not Game.State.has(key):
		return "Unknown state '%s'. Options: %s" % [args[0], ", ".join(_state_names())]
	Game.set_state(Game.State[key])
	return "State: %s" % key


func _state_names() -> PackedStringArray:
	return PackedStringArray(Game.State.keys())


func _register_default_overlay_rows() -> void:
	set_overlay_row("FPS", func() -> String: return str(Engine.get_frames_per_second()))
	set_overlay_row("State", func() -> String: return str(Game.State.find_key(Game.state)))
	set_overlay_row("Actors", func() -> String: return str(get_tree().get_node_count_in_group(ACTORS_GROUP)))
	set_overlay_row("Chunks", func() -> String: return PLACEHOLDER)
	set_overlay_row("Day", func() -> String: return PLACEHOLDER)


# --- UI construction --------------------------------------------------------

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ConsolePanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.anchor_bottom = 0.4
	_panel.visible = false
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_output)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Type a command ('help' for a list)"
	_input_line.keep_editing_on_text_submit = true
	_input_line.text_submitted.connect(_on_input_submitted)
	_input_line.gui_input.connect(_on_input_gui_input)
	vbox.add_child(_input_line)

	_overlay = Label.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["monospace"])
	_overlay.add_theme_font_override("font", mono)
	_overlay.add_theme_constant_override("outline_size", 4)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_overlay)

	_overlay_timer = Timer.new()
	_overlay_timer.wait_time = OVERLAY_REFRESH_S
	_overlay_timer.ignore_time_scale = true
	_overlay_timer.autostart = true
	_overlay_timer.timeout.connect(refresh_overlay)
	add_child(_overlay_timer)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
