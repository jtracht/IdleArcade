extends RefCounted
class_name NakamaException

## An exception occurred during a network operation or SDK call.

var message: String = ""
var status_code: int = -1
var error_code: int = -1

func _init(p_message: String = "", p_status_code: int = -1, p_error_code: int = -1) -> void:
	message = p_message
	status_code = p_status_code
	error_code = p_error_code

func _to_string() -> String:
	return "NakamaException(status=%d, error=%d, message='%s')" % [status_code, error_code, message]
