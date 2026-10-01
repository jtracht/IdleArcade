extends RefCounted
class_name NakamaRTMessage

## Encapsulates real-time WebSocket messages and notifications.

var cid: String = ""
var payload: Dictionary = {}

func _init(p_cid: String = "", p_payload: Dictionary = {}) -> void:
	cid = p_cid
	payload = p_payload

func to_dict() -> Dictionary:
	var d: Dictionary = {}
	if not cid.is_empty():
		d["cid"] = cid
	for k in payload:
		d[k] = payload[k]
	return d

static func from_dict(p_dict: Dictionary) -> NakamaRTMessage:
	var msg = NakamaRTMessage.new()
	msg.cid = p_dict.get("cid", "")
	msg.payload = p_dict
	return msg
