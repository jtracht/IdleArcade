extends Node
class_name NakamaClient

## REST/HTTP API client for Nakama server operations.

var server_key: String = "defaultkey"
var host: String = "127.0.0.1"
var port: int = 7350
var scheme: String = "http"
var timeout: float = 10.0
var log_level: int = NakamaLogger.LogLevel.INFO

var logger: NakamaLogger
var adapter: NakamaHTTPAdapter

func _init(
	p_server_key: String = "defaultkey",
	p_host: String = "127.0.0.1",
	p_port: int = 7350,
	p_scheme: String = "http",
	p_timeout: float = 10.0,
	p_log_level: int = NakamaLogger.LogLevel.INFO
) -> void:
	server_key = p_server_key
	host = p_host
	port = p_port
	scheme = p_scheme
	timeout = p_timeout
	log_level = p_log_level
	logger = NakamaLogger.new(log_level, "[NakamaClient]")

func _ready() -> void:
	if adapter == null:
		adapter = NakamaHTTPAdapter.new()
		add_child(adapter)

func _get_adapter() -> NakamaHTTPAdapter:
	if adapter == null:
		adapter = NakamaHTTPAdapter.new()
		add_child(adapter)
	return adapter

func _build_url(p_path: String, p_query: Dictionary = {}) -> String:
	var base_url = "%s://%s:%d%s" % [scheme, host, port, p_path]
	if p_query.is_empty():
		return base_url

	var query_parts: Array[String] = []
	for k in p_query:
		var v = p_query[k]
		if v is Array:
			for item in v:
				query_parts.append("%s=%s" % [str(k).uri_encode(), str(item).uri_encode()])
		elif v != null and not str(v).is_empty():
			query_parts.append("%s=%s" % [str(k).uri_encode(), str(v).uri_encode()])

	if query_parts.is_empty():
		return base_url
	return "%s?%s" % [base_url, "&".join(query_parts)]

func _get_basic_auth_header() -> String:
	return "Authorization: Basic %s" % Marshalls.utf8_to_base64("%s:" % server_key)

func _get_bearer_auth_header(p_token: String) -> String:
	return "Authorization: Bearer %s" % p_token

func _send_request(
	p_method: HTTPClient.Method,
	p_path: String,
	p_query: Dictionary,
	p_headers: Array[String],
	p_body: String = ""
) -> Dictionary:
	var url = _build_url(p_path, p_query)
	var packed_headers = PackedStringArray(p_headers)
	var adp = _get_adapter()
	return await adp.send_async(url, packed_headers, p_method, p_body, timeout)

func _parse_response_json(p_res: Dictionary) -> Variant:
	if not p_res.has("body") or (p_res["body"] as PackedByteArray).is_empty():
		return {}
	var text = (p_res["body"] as PackedByteArray).get_string_from_utf8()
	return NakamaSerializer.json_parse(text)

func _extract_exception(p_res: Dictionary) -> NakamaException:
	var code = int(p_res.get("response_code", 0))
	var error_msg = p_res.get("error", "")
	var parsed = _parse_response_json(p_res)
	if parsed is Dictionary:
		if parsed.has("message"):
			error_msg = str(parsed["message"])
		elif parsed.has("error"):
			error_msg = str(parsed["error"])
	if error_msg.is_empty():
		error_msg = "HTTP error code %d" % code
	return NakamaException.new(error_msg, code)

# ==============================================================================
# Authentication & Session
# ==============================================================================

static func restore_session(p_token: String, p_refresh_token: String = "") -> NakamaSession:
	if p_token.is_empty():
		var empty_s = NakamaSession.new()
		empty_s._exception = NakamaException.new("Empty token provided", 400)
		return empty_s
	var s = NakamaSession.create(p_token, p_refresh_token, false)
	return s

func authenticate_device_async(
	p_id: String,
	p_username: String = "",
	p_create: bool = true,
	p_vars: Dictionary = {}
) -> NakamaSession:
	var query = {"create": str(p_create).to_lower()}
	if not p_username.is_empty():
		query["username"] = p_username

	var headers: Array[String] = [
		_get_basic_auth_header(),
		"Content-Type: application/json"
	]

	var body_dict: Dictionary = {"id": p_id}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/authenticate/device", query, headers, body_str)
	var session = NakamaSession.new()
	if int(res.get("response_code", 0)) != 200:
		session._exception = _extract_exception(res)
		return session

	var json = _parse_response_json(res)
	if json is Dictionary and json.has("token"):
		session = NakamaSession.create(
			json.get("token", ""),
			json.get("refresh_token", ""),
			bool(json.get("created", false))
		)
	else:
		session._exception = NakamaException.new("Malformed authentication response", 500)
	return session

func authenticate_email_async(
	p_email: String,
	p_password: String,
	p_username: String = "",
	p_create: bool = true,
	p_vars: Dictionary = {}
) -> NakamaSession:
	var query = {"create": str(p_create).to_lower()}
	if not p_username.is_empty():
		query["username"] = p_username

	var headers: Array[String] = [
		_get_basic_auth_header(),
		"Content-Type: application/json"
	]

	var body_dict: Dictionary = {
		"email": p_email,
		"password": p_password
	}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/authenticate/email", query, headers, body_str)
	var session = NakamaSession.new()
	if int(res.get("response_code", 0)) != 200:
		session._exception = _extract_exception(res)
		return session

	var json = _parse_response_json(res)
	if json is Dictionary and json.has("token"):
		session = NakamaSession.create(
			json.get("token", ""),
			json.get("refresh_token", ""),
			bool(json.get("created", false))
		)
	else:
		session._exception = NakamaException.new("Malformed email authentication response", 500)
	return session

func authenticate_google_async(
	p_token: String,
	p_username: String = "",
	p_create: bool = true,
	p_vars: Dictionary = {}
) -> NakamaSession:
	var query = {"create": str(p_create).to_lower()}
	if not p_username.is_empty():
		query["username"] = p_username

	var headers: Array[String] = [
		_get_basic_auth_header(),
		"Content-Type: application/json"
	]

	var body_dict: Dictionary = {"token": p_token}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/authenticate/google", query, headers, body_str)
	var session = NakamaSession.new()
	if int(res.get("response_code", 0)) != 200:
		session._exception = _extract_exception(res)
		return session

	var json = _parse_response_json(res)
	if json is Dictionary and json.has("token"):
		session = NakamaSession.create(
			json.get("token", ""),
			json.get("refresh_token", ""),
			bool(json.get("created", false))
		)
	else:
		session._exception = NakamaException.new("Malformed Google authentication response", 500)
	return session

func session_refresh_async(p_session: NakamaSession, p_vars: Dictionary = {}) -> NakamaSession:
	if p_session == null or p_session.refresh_token.is_empty():
		var s = NakamaSession.new()
		s._exception = NakamaException.new("Cannot refresh session: missing refresh token", 400)
		return s

	var headers: Array[String] = [
		_get_basic_auth_header(),
		"Content-Type: application/json"
	]

	var body_dict: Dictionary = {"token": p_session.refresh_token}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/session/refresh", {}, headers, body_str)
	var session = NakamaSession.new()
	if int(res.get("response_code", 0)) != 200:
		session._exception = _extract_exception(res)
		return session

	var json = _parse_response_json(res)
	if json is Dictionary and json.has("token"):
		session = NakamaSession.create(
			json.get("token", ""),
			json.get("refresh_token", ""),
			false
		)
	else:
		session._exception = NakamaException.new("Malformed session refresh response", 500)
	return session

func link_device_async(p_session: NakamaSession, p_id: String, p_vars: Dictionary = {}) -> NakamaAsyncResult:
	if p_session == null or p_session.token.is_empty():
		return NakamaAsyncResult.new(NakamaException.new("Unauthorized", 401))

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]
	var body_dict: Dictionary = {"id": p_id}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/link/device", {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		return NakamaAsyncResult.new(_extract_exception(res))
	return NakamaAsyncResult.new()

func link_email_async(p_session: NakamaSession, p_email: String, p_password: String, p_vars: Dictionary = {}) -> NakamaAsyncResult:
	if p_session == null or p_session.token.is_empty():
		return NakamaAsyncResult.new(NakamaException.new("Unauthorized", 401))

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]
	var body_dict: Dictionary = {"email": p_email, "password": p_password}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/link/email", {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		return NakamaAsyncResult.new(_extract_exception(res))
	return NakamaAsyncResult.new()

func link_google_async(p_session: NakamaSession, p_token: String, p_vars: Dictionary = {}) -> NakamaAsyncResult:
	if p_session == null or p_session.token.is_empty():
		return NakamaAsyncResult.new(NakamaException.new("Unauthorized", 401))

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]
	var body_dict: Dictionary = {"token": p_token}
	if not p_vars.is_empty():
		body_dict["vars"] = p_vars
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/account/link/google", {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		return NakamaAsyncResult.new(_extract_exception(res))
	return NakamaAsyncResult.new()

func get_account_async(p_session: NakamaSession) -> NakamaAPI.ApiAccount:
	var acc = NakamaAPI.ApiAccount.new()
	if p_session == null or p_session.token.is_empty():
		acc._exception = NakamaException.new("Unauthorized", 401)
		return acc

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var res = await _send_request(HTTPClient.METHOD_GET, "/v2/account", {}, headers)
	if int(res.get("response_code", 0)) != 200:
		acc._exception = _extract_exception(res)
		return acc

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiAccount.from_dict(json)
	acc._exception = NakamaException.new("Malformed account response", 500)
	return acc

# ==============================================================================
# Leaderboards & Scoreboards
# ==============================================================================

func write_leaderboard_record_async(
	p_session: NakamaSession,
	p_leaderboard_id: String,
	p_score: int,
	p_subscore: int = 0,
	p_metadata: Dictionary = {}
) -> NakamaAPI.ApiLeaderboardRecord:
	var rec = NakamaAPI.ApiLeaderboardRecord.new()
	if p_session == null or p_session.token.is_empty():
		rec._exception = NakamaException.new("Unauthorized", 401)
		return rec

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]

	var meta_str = "{}"
	if not p_metadata.is_empty():
		meta_str = NakamaSerializer.json_stringify(p_metadata)

	var body_dict: Dictionary = {
		"record": {
			"score": p_score,
			"subscore": p_subscore,
			"metadata": meta_str
		}
	}
	var body_str = NakamaSerializer.json_stringify(body_dict)
	var path = "/v2/leaderboard/%s" % p_leaderboard_id.uri_encode()

	var res = await _send_request(HTTPClient.METHOD_POST, path, {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		rec._exception = _extract_exception(res)
		return rec

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiLeaderboardRecord.from_dict(json)
	rec._exception = NakamaException.new("Malformed leaderboard response", 500)
	return rec

func list_leaderboard_records_async(
	p_session: NakamaSession,
	p_leaderboard_id: String,
	p_owner_ids: Array = [],
	p_expiry: int = 0,
	p_limit: int = 20,
	p_cursor: String = ""
) -> NakamaAPI.ApiLeaderboardRecordList:
	var list = NakamaAPI.ApiLeaderboardRecordList.new()
	if p_session == null or p_session.token.is_empty():
		list._exception = NakamaException.new("Unauthorized", 401)
		return list

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var query: Dictionary = {
		"limit": p_limit
	}
	if not p_owner_ids.is_empty():
		query["owner_ids"] = p_owner_ids
	if p_expiry > 0:
		query["expiry"] = p_expiry
	if not p_cursor.is_empty():
		query["cursor"] = p_cursor

	var path = "/v2/leaderboard/%s" % p_leaderboard_id.uri_encode()
	var res = await _send_request(HTTPClient.METHOD_GET, path, query, headers)
	if int(res.get("response_code", 0)) != 200:
		list._exception = _extract_exception(res)
		return list

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiLeaderboardRecordList.from_dict(json)
	list._exception = NakamaException.new("Malformed leaderboard records response", 500)
	return list

func list_leaderboard_records_around_owner_async(
	p_session: NakamaSession,
	p_leaderboard_id: String,
	p_owner_id: String,
	p_expiry: int = 0,
	p_limit: int = 20
) -> NakamaAPI.ApiLeaderboardRecordList:
	var list = NakamaAPI.ApiLeaderboardRecordList.new()
	if p_session == null or p_session.token.is_empty():
		list._exception = NakamaException.new("Unauthorized", 401)
		return list

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var query: Dictionary = {"limit": p_limit}
	if p_expiry > 0:
		query["expiry"] = p_expiry

	var path = "/v2/leaderboard/%s/owner/%s" % [p_leaderboard_id.uri_encode(), p_owner_id.uri_encode()]
	var res = await _send_request(HTTPClient.METHOD_GET, path, query, headers)
	if int(res.get("response_code", 0)) != 200:
		list._exception = _extract_exception(res)
		return list

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiLeaderboardRecordList.from_dict(json)
	list._exception = NakamaException.new("Malformed leaderboard records response", 500)
	return list

# ==============================================================================
# Groups & Guilds (Unternehmens-Netzwerke)
# ==============================================================================

func create_group_async(
	p_session: NakamaSession,
	p_name: String,
	p_description: String = "",
	p_avatar_url: String = "",
	p_lang_tag: String = "en",
	p_open: bool = true,
	p_max_count: int = 50
) -> NakamaAPI.ApiGroup:
	var g = NakamaAPI.ApiGroup.new()
	if p_session == null or p_session.token.is_empty():
		g._exception = NakamaException.new("Unauthorized", 401)
		return g

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]
	var body_dict: Dictionary = {
		"name": p_name,
		"description": p_description,
		"avatar_url": p_avatar_url,
		"lang_tag": p_lang_tag,
		"open": p_open,
		"max_count": p_max_count
	}
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/group", {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		g._exception = _extract_exception(res)
		return g

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiGroup.from_dict(json)
	g._exception = NakamaException.new("Malformed group response", 500)
	return g

func join_group_async(p_session: NakamaSession, p_group_id: String) -> NakamaAsyncResult:
	if p_session == null or p_session.token.is_empty():
		return NakamaAsyncResult.new(NakamaException.new("Unauthorized", 401))

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var path = "/v2/group/%s/join" % p_group_id.uri_encode()

	var res = await _send_request(HTTPClient.METHOD_POST, path, {}, headers)
	if int(res.get("response_code", 0)) != 200:
		return NakamaAsyncResult.new(_extract_exception(res))
	return NakamaAsyncResult.new()

func leave_group_async(p_session: NakamaSession, p_group_id: String) -> NakamaAsyncResult:
	if p_session == null or p_session.token.is_empty():
		return NakamaAsyncResult.new(NakamaException.new("Unauthorized", 401))

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var path = "/v2/group/%s/leave" % p_group_id.uri_encode()

	var res = await _send_request(HTTPClient.METHOD_POST, path, {}, headers)
	if int(res.get("response_code", 0)) != 200:
		return NakamaAsyncResult.new(_extract_exception(res))
	return NakamaAsyncResult.new()

func list_groups_async(
	p_session: NakamaSession,
	p_name: String = "",
	p_limit: int = 20,
	p_cursor: String = ""
) -> NakamaAPI.ApiGroupList:
	var list = NakamaAPI.ApiGroupList.new()
	if p_session == null or p_session.token.is_empty():
		list._exception = NakamaException.new("Unauthorized", 401)
		return list

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var query: Dictionary = {"limit": p_limit}
	if not p_name.is_empty():
		query["name"] = p_name
	if not p_cursor.is_empty():
		query["cursor"] = p_cursor

	var res = await _send_request(HTTPClient.METHOD_GET, "/v2/group", query, headers)
	if int(res.get("response_code", 0)) != 200:
		list._exception = _extract_exception(res)
		return list

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiGroupList.from_dict(json)
	list._exception = NakamaException.new("Malformed groups response", 500)
	return list

func list_group_users_async(
	p_session: NakamaSession,
	p_group_id: String,
	p_state: Variant = null,
	p_limit: int = 20,
	p_cursor: String = ""
) -> NakamaAPI.ApiGroupUserList:
	var list = NakamaAPI.ApiGroupUserList.new()
	if p_session == null or p_session.token.is_empty():
		list._exception = NakamaException.new("Unauthorized", 401)
		return list

	var headers: Array[String] = [_get_bearer_auth_header(p_session.token)]
	var query: Dictionary = {"limit": p_limit}
	if p_state != null:
		query["state"] = p_state
	if not p_cursor.is_empty():
		query["cursor"] = p_cursor

	var path = "/v2/group/%s/user" % p_group_id.uri_encode()
	var res = await _send_request(HTTPClient.METHOD_GET, path, query, headers)
	if int(res.get("response_code", 0)) != 200:
		list._exception = _extract_exception(res)
		return list

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiGroupUserList.from_dict(json)
	list._exception = NakamaException.new("Malformed group users response", 500)
	return list

# ==============================================================================
# Storage Engine (Quests & User Data)
# ==============================================================================

func write_storage_objects_async(
	p_session: NakamaSession,
	p_objects: Array
) -> NakamaAPI.ApiStorageObjectAcks:
	var acks = NakamaAPI.ApiStorageObjectAcks.new()
	if p_session == null or p_session.token.is_empty():
		acks._exception = NakamaException.new("Unauthorized", 401)
		return acks

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]

	var objects_data: Array[Dictionary] = []
	for obj in p_objects:
		if obj is NakamaWriteStorageObject:
			objects_data.append(obj.to_dict())
		elif obj is Dictionary:
			objects_data.append(obj)

	var body_dict: Dictionary = {"objects": objects_data}
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_PUT, "/v2/storage", {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		acks._exception = _extract_exception(res)
		return acks

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiStorageObjectAcks.from_dict(json)
	acks._exception = NakamaException.new("Malformed storage write response", 500)
	return acks

func read_storage_objects_async(
	p_session: NakamaSession,
	p_object_ids: Array
) -> NakamaAPI.ApiStorageObjects:
	var objs = NakamaAPI.ApiStorageObjects.new()
	if p_session == null or p_session.token.is_empty():
		objs._exception = NakamaException.new("Unauthorized", 401)
		return objs

	var headers: Array[String] = [
		_get_bearer_auth_header(p_session.token),
		"Content-Type: application/json"
	]

	var ids_data: Array[Dictionary] = []
	for id_obj in p_object_ids:
		if id_obj is NakamaStorageObjectId:
			ids_data.append(id_obj.to_dict())
		elif id_obj is Dictionary:
			ids_data.append(id_obj)

	var body_dict: Dictionary = {"object_ids": ids_data}
	var body_str = NakamaSerializer.json_stringify(body_dict)

	var res = await _send_request(HTTPClient.METHOD_POST, "/v2/storage", {}, headers, body_str)
	if int(res.get("response_code", 0)) != 200:
		objs._exception = _extract_exception(res)
		return objs

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiStorageObjects.from_dict(json)
	objs._exception = NakamaException.new("Malformed storage read response", 500)
	return objs

# ==============================================================================
# Remote Procedure Calls (RPC)
# ==============================================================================

func rpc_async(
	p_session: NakamaSession,
	p_id: String,
	p_payload: String = ""
) -> NakamaAPI.ApiRpc:
	var rpc_res = NakamaAPI.ApiRpc.new()
	rpc_res.id = p_id

	var headers: Array[String] = ["Content-Type: application/json"]
	if p_session != null and not p_session.token.is_empty():
		headers.append(_get_bearer_auth_header(p_session.token))
	else:
		headers.append(_get_basic_auth_header())

	var path = "/v2/rpc/%s" % p_id.uri_encode()
	var res = await _send_request(HTTPClient.METHOD_POST, path, {}, headers, p_payload)
	if int(res.get("response_code", 0)) != 200:
		rpc_res._exception = _extract_exception(res)
		return rpc_res

	var json = _parse_response_json(res)
	if json is Dictionary:
		return NakamaAPI.ApiRpc.from_dict(json)
	rpc_res.payload = (res.get("body") as PackedByteArray).get_string_from_utf8()
	return rpc_res
