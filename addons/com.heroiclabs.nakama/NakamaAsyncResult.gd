extends RefCounted
class_name NakamaAsyncResult

## Base class for asynchronous operations returning a result or exception.

var _exception: NakamaException = null

func _init(p_exception: NakamaException = null) -> void:
	_exception = p_exception

func is_exception() -> bool:
	return _exception != null

func get_exception() -> NakamaException:
	return _exception
