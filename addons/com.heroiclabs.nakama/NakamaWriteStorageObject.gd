extends RefCounted
class_name NakamaWriteStorageObject

## Write descriptor for storing objects in Nakama storage engine.

var collection: String = ""
var key: String = ""
var value: String = "{}"
var version: String = ""
var permission_read: int = 1
var permission_write: int = 1

func _init(
	p_collection: String = "",
	p_key: String = "",
	p_value: String = "{}",
	p_version: String = "",
	p_permission_read: int = 1,
	p_permission_write: int = 1
) -> void:
	collection = p_collection
	key = p_key
	value = p_value
	version = p_version
	permission_read = p_permission_read
	permission_write = p_permission_write

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"collection": collection,
		"key": key,
		"value": value,
		"permission_read": permission_read,
		"permission_write": permission_write
	}
	if not version.is_empty():
		d["version"] = version
	return d
