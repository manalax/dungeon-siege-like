class_name DebugCommandRegistry
extends RefCounted
## Pure command registry for the debug console (F-003). No UI or scene dependencies.
##
## Command contract: func(args: PackedStringArray) -> String
## Args always arrive as strings; each command parses its own. The return value is shown as output.


class Command:
	var callable: Callable
	var help: String
	var usage: String


var _commands: Dictionary = {}  # name -> Command


func _init() -> void:
	register("help", _cmd_help, "List commands, or show usage for one.", "help [command]")


func register(command_name: String, callable: Callable, help: String, usage: String = "") -> void:
	var key := command_name.strip_edges().to_lower()
	if key.is_empty() or key.contains(" "):
		push_error("DebugCommandRegistry: invalid command name '%s'" % command_name)
		return
	if not callable.is_valid():
		push_error("DebugCommandRegistry: invalid callable for '%s'" % key)
		return
	if _commands.has(key):
		push_warning("DebugCommandRegistry: replacing command '%s'" % key)
	var cmd := Command.new()
	cmd.callable = callable
	cmd.help = help
	cmd.usage = usage if not usage.is_empty() else key
	_commands[key] = cmd


func unregister(command_name: String) -> void:
	_commands.erase(command_name.to_lower())


func has_command(command_name: String) -> bool:
	return _commands.has(command_name.to_lower())


func command_names() -> PackedStringArray:
	var names := PackedStringArray(_commands.keys())
	names.sort()
	return names


## Returns {ok: bool, text: String}.
func execute(line: String) -> Dictionary:
	var parsed := tokenize(line)
	if not parsed.ok:
		return {"ok": false, "text": parsed.error}
	var tokens: PackedStringArray = parsed.tokens
	if tokens.is_empty():
		return {"ok": true, "text": ""}
	var key := tokens[0].to_lower()
	if not _commands.has(key):
		return {"ok": false, "text": "Unknown command '%s'. Type 'help'." % tokens[0]}
	var cmd: Command = _commands[key]
	if not cmd.callable.is_valid():
		return {"ok": false, "text": "Command '%s' is no longer valid (owner freed)." % key}
	var result: Variant = cmd.callable.call(tokens.slice(1))
	return {"ok": true, "text": "" if result == null else str(result)}


## Splits on whitespace; "double quotes" group words; \" escapes a quote inside quotes.
## Returns {ok: bool, tokens: PackedStringArray, error: String}.
static func tokenize(line: String) -> Dictionary:
	var tokens := PackedStringArray()
	var current := ""
	var in_quotes := false
	var has_token := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_quotes:
			if c == "\\" and i + 1 < line.length() and line[i + 1] == "\"":
				current += "\""
				i += 1
			elif c == "\"":
				in_quotes = false
			else:
				current += c
		elif c == "\"":
			in_quotes = true
			has_token = true
		elif c == " " or c == "\t":
			if has_token:
				tokens.append(current)
				current = ""
				has_token = false
		else:
			current += c
			has_token = true
		i += 1
	if in_quotes:
		return {"ok": false, "tokens": PackedStringArray(), "error": "Unterminated quote."}
	if has_token:
		tokens.append(current)
	return {"ok": true, "tokens": tokens, "error": ""}


func _cmd_help(args: PackedStringArray) -> String:
	if not args.is_empty():
		var key := args[0].to_lower()
		if not _commands.has(key):
			return "Unknown command '%s'." % args[0]
		var cmd: Command = _commands[key]
		return "%s\n  %s" % [cmd.usage, cmd.help]
	var lines := PackedStringArray()
	for command_name: String in command_names():
		lines.append("%-14s %s" % [command_name, (_commands[command_name] as Command).help])
	return "\n".join(lines)
