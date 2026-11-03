extends GutTest
## F-003: DebugCommandRegistry parsing and dispatch (pure logic).

var reg: DebugCommandRegistry
var captured: PackedStringArray


func before_each() -> void:
	reg = DebugCommandRegistry.new()
	captured = PackedStringArray()


func _capture(args: PackedStringArray) -> String:
	captured = args
	return "ok"


func test_tokenize_plain_and_extra_spaces() -> void:
	var r := DebugCommandRegistry.tokenize("  give_item   sword  3 ")
	assert_true(r.ok)
	assert_eq(r.tokens, PackedStringArray(["give_item", "sword", "3"]))


func test_tokenize_quotes_and_escapes() -> void:
	var r := DebugCommandRegistry.tokenize('say "hello world" "a \\"quoted\\" word" ""')
	assert_true(r.ok)
	assert_eq(r.tokens, PackedStringArray(["say", "hello world", 'a "quoted" word', ""]))


func test_tokenize_unterminated_quote_errors() -> void:
	var r := DebugCommandRegistry.tokenize('say "oops')
	assert_false(r.ok)
	assert_string_contains(r.error, "Unterminated")


func test_unknown_command_errors() -> void:
	var r := reg.execute("nope 1 2")
	assert_false(r.ok)
	assert_string_contains(r.text, "nope")


func test_empty_line_ok() -> void:
	var r := reg.execute("   ")
	assert_true(r.ok)
	assert_eq(r.text, "")


func test_args_passed_and_name_case_insensitive() -> void:
	reg.register("Spawn", _capture, "Spawn a monster.")
	var r := reg.execute("SPAWN rat 3")
	assert_true(r.ok)
	assert_eq(r.text, "ok")
	assert_eq(captured, PackedStringArray(["rat", "3"]))


func test_non_string_return_is_stringified() -> void:
	reg.register("num", func(_a: PackedStringArray) -> int: return 42, "n")
	assert_eq(reg.execute("num").text, "42")


func test_reregister_replaces_and_unregister_removes() -> void:
	reg.register("x", func(_a: PackedStringArray) -> String: return "first", "")
	reg.register("x", func(_a: PackedStringArray) -> String: return "second", "")
	assert_eq(reg.execute("x").text, "second")
	reg.unregister("x")
	assert_false(reg.has_command("x"))
	assert_false(reg.execute("x").ok)


func test_invalid_name_rejected() -> void:
	reg.register("two words", _capture, "")
	assert_false(reg.has_command("two words"))
	assert_push_error("invalid command name")


func test_help_lists_and_shows_usage() -> void:
	reg.register("gold", _capture, "Add gold.", "gold <n>")
	var all: String = reg.execute("help").text
	assert_string_contains(all, "gold")
	assert_string_contains(all, "help")
	var one: String = reg.execute("help gold").text
	assert_string_contains(one, "gold <n>")
	assert_string_contains(one, "Add gold.")
