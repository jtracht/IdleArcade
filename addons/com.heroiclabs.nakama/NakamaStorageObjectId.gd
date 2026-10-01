extends RefCounted
class_name NakamaStorageObjectId

## Identifier for reading a storage object.

var collection: String = ""
var key: String = ""
var user_id: String = ""
var version: String = ""

func _init(p_collection: String = "", p_key: String = "", p_user_id: String = "", p_version: String = "") -> void:
	collection = p_collection
	key = p_key
	user_id = p_user_id
	version = p_version

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"collection": collection,
		"key": key
	}
	if not user_id.is_empty():
		d["user_id"] = user_id
	if not version.is_empty():
		d["version"] = version
	return d
