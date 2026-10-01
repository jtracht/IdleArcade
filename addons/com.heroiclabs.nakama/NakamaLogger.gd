extends RefCounted
class_name NakamaLogger

## Diagnostic logging facility for Nakama client operations.

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
}

var level: int = LogLevel.INFO
var prefix: String = "[Nakama]"

func _init(p_level: int = LogLevel.INFO, p_prefix: String = "[Nakama]") -> void:
	level = p_level
	prefix = p_prefix

func debug(p_message: String) -> void:
	if level <= LogLevel.DEBUG:
		print("%s [DEBUG] %s" % [prefix, p_message])

func info(p_message: String) -> void:
	if level <= LogLevel.INFO:
		print("%s [INFO] %s" % [prefix, p_message])

func warning(p_message: String) -> void:
	if level <= LogLevel.WARNING:
		push_warning("%s [WARN] %s" % [prefix, p_message])

func error(p_message: String) -> void:
	if level <= LogLevel.ERROR:
		push_error("%s [ERROR] %s" % [prefix, p_message])
