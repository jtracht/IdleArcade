extends RefCounted
class_name NakamaSerializer

## Serialization and encoding utilities for Nakama JSON payloads and JWT tokens.

static func json_stringify(p_data: Variant) -> String:
	return JSON.stringify(p_data)

static func json_parse(p_text: String) -> Variant:
	var json = JSON.new()
	var error = json.parse(p_text)
	if error != OK:
		return null
	return json.data

static func decode_base64_url(p_base64_url: String) -> String:
	var base64 = p_base64_url.replace("-", "+").replace("_", "/")
	while base64.length() % 4 != 0:
		base64 += "="
	return Marshalls.base64_to_utf8(base64)

static func parse_jwt_payload(p_jwt: String) -> Dictionary:
	var parts = p_jwt.split(".")
	if parts.size() < 2:
		return {}
	var payload_raw = decode_base64_url(parts[1])
	if payload_raw.is_empty():
		return {}
	var parsed = json_parse(payload_raw)
	if parsed is Dictionary:
		return parsed
	return {}
