extends RefCounted
class_name NakamaSession

## Encapsulates an authenticated Nakama user session and JWT bearer tokens.

var token: String = ""
var refresh_token: String = ""
var created: bool = false
var user_id: String = ""
var username: String = ""
var vars: Dictionary = {}
var expire_time: int = 0
var refresh_expire_time: int = 0
var _exception: NakamaException = null

func is_expired() -> bool:
	if expire_time <= 0:
		return false
	return Time.get_unix_time_from_system() >= expire_time

func is_refresh_expired() -> bool:
	if refresh_expire_time <= 0:
		return false
	return Time.get_unix_time_from_system() >= refresh_expire_time

func is_exception() -> bool:
	return _exception != null

func get_exception() -> NakamaException:
	return _exception

static func create(p_token: String, p_refresh_token: String = "", p_created: bool = false) -> NakamaSession:
	var s = NakamaSession.new()
	s.token = p_token
	s.refresh_token = p_refresh_token
	s.created = p_created

	if not p_token.is_empty():
		var payload = NakamaSerializer.parse_jwt_payload(p_token)
		s.user_id = payload.get("sub", "")
		s.username = payload.get("usn", "")
		s.expire_time = int(payload.get("exp", 0))
		s.vars = payload.get("vrs", {})

	if not p_refresh_token.is_empty():
		var r_payload = NakamaSerializer.parse_jwt_payload(p_refresh_token)
		s.refresh_expire_time = int(r_payload.get("exp", 0))

	return s

func serialize() -> Dictionary:
	return {
		"token": token,
		"refresh_token": refresh_token,
		"created": created,
		"user_id": user_id,
		"username": username,
		"vars": vars,
		"expire_time": expire_time,
		"refresh_expire_time": refresh_expire_time
	}

static func deserialize(p_dict: Dictionary) -> NakamaSession:
	var s = NakamaSession.new()
	s.token = p_dict.get("token", "")
	s.refresh_token = p_dict.get("refresh_token", "")
	s.created = bool(p_dict.get("created", false))
	s.user_id = p_dict.get("user_id", "")
	s.username = p_dict.get("username", "")
	s.vars = p_dict.get("vars", {})
	s.expire_time = int(p_dict.get("expire_time", 0))
	s.refresh_expire_time = int(p_dict.get("refresh_expire_time", 0))
	return s

func _to_string() -> String:
	if is_exception():
		return "NakamaSession(Exception: %s)" % str(_exception)
	return "NakamaSession(user_id='%s', username='%s', expired=%s)" % [user_id, username, str(is_expired())]
