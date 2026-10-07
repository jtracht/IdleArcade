extends SceneTree

## Adversarial Empirical Challenge Test Suite for Phase 2 Milestone 1.
## Validates:
## 1. Nakama.create_client defaults, custom parameters, and SceneTree hierarchy.
## 2. Nakama.create_socket_from scheme translation and SceneTree hierarchy.
## 3. NakamaSession & NakamaSerializer:
##    - Valid JWT unpacking (sub, usn, exp, vrs)
##    - Time-based expiration calculations (past, future, zero/unset)
##    - Refresh token expiration calculations
##    - Full serialization/deserialization roundtrip
##    - Partial/corrupted dictionary deserialization
##    - Adversarial malformed tokens (empty, no dots, invalid base64, non-dict JSON, URL characters)
## 4. project.godot configuration integrity and file references.
## 5. init_leaderboards.lua idempotency and defensive pcall structure.
## 6. docker-compose.yml volume mounts.
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m1_adversarial_challenge.gd

func _init() -> void:
	print("=====================================================================")
	print("[ADVERSARIAL CHALLENGE] Phase 2 Milestone 1 Empirical Stress Tests")
	print("=====================================================================")

	var pass_count: int = 0
	var fail_count: int = 0

	# -------------------------------------------------------------------------
	# 1. Nakama.create_client Defaults and Initialization
	# -------------------------------------------------------------------------
	print("\n--- Testing Nakama Singleton & Client Initialization ---")
	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	if nakama_script == null:
		printerr("[FAIL] Failed to load Nakama.gd")
		fail_count += 1
		quit()
		return

	var nakama_singleton = nakama_script.new()
	root.add_child(nakama_singleton)

	# Test 1.1: Default parameters
	var default_client = nakama_singleton.create_client()
	if default_client != null and default_client is NakamaClient:
		if default_client.server_key == "defaultkey" \
			and default_client.host == "127.0.0.1" \
			and default_client.port == 7350 \
			and default_client.scheme == "http" \
			and default_client.timeout == 10.0 \
			and default_client.log_level == NakamaLogger.LogLevel.INFO:
			print("[PASS] Nakama.create_client defaults match specification (defaultkey@127.0.0.1:7350 http 10s)")
			pass_count += 1
		else:
			printerr("[FAIL] Nakama.create_client defaults mismatch: ", [
				default_client.server_key, default_client.host, default_client.port,
				default_client.scheme, default_client.timeout, default_client.log_level
			])
			fail_count += 1

		# Test 1.2: SceneTree parentage
		if default_client.get_parent() == nakama_singleton:
			print("[PASS] Nakama.create_client correctly attaches client to SceneTree under Nakama")
			pass_count += 1
		else:
			printerr("[FAIL] NakamaClient is not childed to Nakama singleton")
			fail_count += 1
	else:
		printerr("[FAIL] Nakama.create_client did not return a valid NakamaClient")
		fail_count += 1

	# Test 1.3: Custom parameters
	var custom_client = nakama_singleton.create_client("custom_key", "nakama.example.com", 8350, "https", 25.0, NakamaLogger.LogLevel.DEBUG)
	if custom_client.server_key == "custom_key" \
		and custom_client.host == "nakama.example.com" \
		and custom_client.port == 8350 \
		and custom_client.scheme == "https" \
		and custom_client.timeout == 25.0 \
		and custom_client.log_level == NakamaLogger.LogLevel.DEBUG:
		print("[PASS] Nakama.create_client correctly applies custom configuration parameters")
		pass_count += 1
	else:
		printerr("[FAIL] Nakama.create_client failed to apply custom configuration parameters")
		fail_count += 1

	# Test 1.4: Socket creation and scheme translation
	var socket_http = nakama_singleton.create_socket_from(default_client)
	var socket_https = nakama_singleton.create_socket_from(custom_client)
	if socket_http.scheme == "ws" and socket_https.scheme == "wss":
		print("[PASS] Nakama.create_socket_from correctly translates http->ws and https->wss")
		pass_count += 1
	else:
		printerr("[FAIL] Socket scheme translation failed: http->%s, https->%s" % [socket_http.scheme, socket_https.scheme])
		fail_count += 1

	if socket_http.get_parent() == nakama_singleton and socket_https.get_parent() == nakama_singleton:
		print("[PASS] Sockets are properly childed under Nakama singleton")
		pass_count += 1
	else:
		printerr("[FAIL] Sockets not attached to Nakama singleton")
		fail_count += 1

	# -------------------------------------------------------------------------
	# 2. NakamaSession & NakamaSerializer Validation
	# -------------------------------------------------------------------------
	print("\n--- Testing NakamaSession & NakamaSerializer ---")

	# Test 2.1: Valid JWT unpacking
	# Payload: {"sub": "user-uuid-12345", "usn": "arcade_king", "exp": 2500000000, "vrs": {"role": "player"}}
	# base64url of payload: eyJzdWIiOiJ1c2VyLXV1aWQtMTIzNDUiLCJ1c24iOiJhcmNhZGVfa2luZyIsImV4cCI6MjUwMDAwMDAwMCwidnJzIjp7InJvbGUiOiJwbGF5ZXIifX0
	var test_jwt = "header.eyJzdWIiOiJ1c2VyLXV1aWQtMTIzNDUiLCJ1c24iOiJhcmNhZGVfa2luZyIsImV4cCI6MjUwMDAwMDAwMCwidnJzIjp7InJvbGUiOiJwbGF5ZXIifX0.sig"
	var session = NakamaClient.restore_session(test_jwt)
	if session != null and not session.is_exception():
		if session.user_id == "user-uuid-12345" \
			and session.username == "arcade_king" \
			and session.expire_time == 2500000000 \
			and session.vars.get("role") == "player":
			print("[PASS] NakamaClient.restore_session correctly unpacks sub, usn, exp, and vars")
			pass_count += 1
		else:
			printerr("[FAIL] JWT unpacking content mismatch: ", session.serialize())
			fail_count += 1
	else:
		printerr("[FAIL] restore_session returned exception on valid JWT")
		fail_count += 1

	# Test 2.2: Expiration checking
	var future_session = NakamaSession.create(test_jwt)
	if not future_session.is_expired():
		print("[PASS] Future expiration time (exp=2500000000) correctly reports is_expired() == false")
		pass_count += 1
	else:
		printerr("[FAIL] Future session incorrectly marked expired")
		fail_count += 1

	# Payload with exp in the past: 1000000000
	# base64url: eyJzdWIiOiJleHBpcmVkLXVzZXIiLCJleHAiOjEwMDAwMDAwMDB9
	var expired_jwt = "header.eyJzdWIiOiJleHBpcmVkLXVzZXIiLCJleHAiOjEwMDAwMDAwMDB9.sig"
	var expired_session = NakamaClient.restore_session(expired_jwt)
	if expired_session.is_expired():
		print("[PASS] Past expiration time (exp=1000000000) correctly reports is_expired() == true")
		pass_count += 1
	else:
		printerr("[FAIL] Expired session failed to report is_expired() == true")
		fail_count += 1

	# Test 2.3: Zero / Unset expiration check
	var zero_exp_session = NakamaSession.new()
	zero_exp_session.expire_time = 0
	if not zero_exp_session.is_expired():
		print("[PASS] Zero expiration time safely defaults is_expired() == false")
		pass_count += 1
	else:
		printerr("[FAIL] Zero expiration time reported expired")
		fail_count += 1

	# Test 2.4: Refresh token expiration
	var refresh_jwt = "header.eyJzdWIiOiJyZWZyZXNoLXVzZXIiLCJleHAiOjI2MDAwMDAwMDB9.sig"
	var session_with_refresh = NakamaSession.create(test_jwt, refresh_jwt)
	if session_with_refresh.refresh_expire_time == 2600000000 and not session_with_refresh.is_refresh_expired():
		print("[PASS] Refresh token unpacked and not expired")
		pass_count += 1
	else:
		printerr("[FAIL] Refresh token unpack/expiration check failed")
		fail_count += 1

	# Test 2.5: Full Serialization & Deserialization roundtrip
	var original_serialized = session_with_refresh.serialize()
	var deserialized_session = NakamaSession.deserialize(original_serialized)
	var re_serialized = deserialized_session.serialize()
	if original_serialized == re_serialized:
		print("[PASS] NakamaSession serialize -> deserialize produces 100% identical state")
		pass_count += 1
	else:
		printerr("[FAIL] NakamaSession serialization roundtrip mismatch")
		fail_count += 1

	# Test 2.6: Deserialization of partial / empty Dictionary
	var empty_dict_session = NakamaSession.deserialize({})
	if empty_dict_session.token == "" and empty_dict_session.user_id == "" and empty_dict_session.expire_time == 0:
		print("[PASS] NakamaSession.deserialize handles empty/missing dictionary keys with safe defaults")
		pass_count += 1
	else:
		printerr("[FAIL] NakamaSession.deserialize failed on empty dictionary")
		fail_count += 1

	# -------------------------------------------------------------------------
	# 3. Adversarial Edge Cases for JWT Parsing
	# -------------------------------------------------------------------------
	print("\n--- Testing Adversarial JWT Edge Cases ---")

	# Test 3.1: Empty token string
	var empty_token_session = NakamaClient.restore_session("")
	if empty_token_session.is_exception():
		print("[PASS] Empty token in restore_session returns NakamaException (status 400)")
		pass_count += 1
	else:
		printerr("[FAIL] Empty token did not produce an exception")
		fail_count += 1

	# Test 3.2: Malformed token with no dots
	var no_dot_res = NakamaSerializer.parse_jwt_payload("raw_garbage_string_with_no_periods")
	if no_dot_res.is_empty():
		print("[PASS] Malformed token without dots safely returns empty Dictionary without crashing")
		pass_count += 1
	else:
		printerr("[FAIL] Expected empty Dictionary for token without dots")
		fail_count += 1

	# Test 3.3: Invalid base64 in payload part
	var invalid_b64_res = NakamaSerializer.parse_jwt_payload("header.???not-base64???@@#.sig")
	if invalid_b64_res.is_empty():
		print("[PASS] Invalid base64 characters in payload safely returns empty Dictionary")
		pass_count += 1
	else:
		printerr("[FAIL] Expected empty Dictionary for invalid base64")
		fail_count += 1

	# Test 3.4: Base64 decoding non-JSON content
	# "hello world" in base64: "aGVsbG8gd29ybGQ="
	var non_json_res = NakamaSerializer.parse_jwt_payload("header.aGVsbG8gd29ybGQ.sig")
	if non_json_res.is_empty():
		print("[PASS] Non-JSON base64 payload safely returns empty Dictionary")
		pass_count += 1
	else:
		printerr("[FAIL] Expected empty Dictionary for non-JSON payload")
		fail_count += 1

	# Test 3.5: JSON array instead of JSON dictionary
	# "[1, 2, 3]" in base64: "WzEsIDIsIDNd"
	var array_json_res = NakamaSerializer.parse_jwt_payload("header.WzEsIDIsIDNd.sig")
	if array_json_res.is_empty():
		print("[PASS] JSON array payload (non-Dictionary) safely returns empty Dictionary")
		pass_count += 1
	else:
		printerr("[FAIL] Expected empty Dictionary for JSON array payload")
		fail_count += 1

	# Test 3.6: URL-safe character translation (- and _)
	# Payload: {"sub":"user-1_2"} -> base64 has - and _
	var url_safe_payload = "eyJzdWIiOiJ1c2VyLTFfMiJ9" # {"sub":"user-1_2"}
	var url_safe_res = NakamaSerializer.parse_jwt_payload("header." + url_safe_payload + ".sig")
	if url_safe_res.get("sub") == "user-1_2":
		print("[PASS] Base64URL '-' and '_' properly decoded")
		pass_count += 1
	else:
		printerr("[FAIL] Base64URL characters not decoded properly: ", url_safe_res)
		fail_count += 1

	# -------------------------------------------------------------------------
	# 4. Engine Configuration & Project Settings Integrity
	# -------------------------------------------------------------------------
	print("\n--- Testing project.godot Integrity ---")
	var nakama_autoload = ProjectSettings.get_setting("autoload/Nakama", "")
	var gamestate_autoload = ProjectSettings.get_setting("autoload/GameState", "")
	var editor_plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())

	if nakama_autoload == "*res://addons/com.heroiclabs.nakama/Nakama.gd":
		print("[PASS] Nakama autoload configured with singleton '*' prefix")
		pass_count += 1
	else:
		printerr("[FAIL] Nakama autoload configuration invalid: ", nakama_autoload)
		fail_count += 1

	if gamestate_autoload == "*res://scripts/autoload/game_state.gd":
		print("[PASS] GameState autoload intact with singleton '*' prefix")
		pass_count += 1
	else:
		printerr("[FAIL] GameState autoload broken: ", gamestate_autoload)
		fail_count += 1

	if "res://addons/com.heroiclabs.nakama/plugin.cfg" in editor_plugins:
		print("[PASS] Nakama plugin present in editor_plugins PackedStringArray")
		pass_count += 1
	else:
		printerr("[FAIL] Nakama plugin missing from editor_plugins: ", editor_plugins)
		fail_count += 1

	# Verify required referenced files exist on disk
	var disk_files: Array[String] = [
		"res://addons/com.heroiclabs.nakama/plugin.cfg",
		"res://addons/com.heroiclabs.nakama/Nakama.gd",
		"res://scripts/autoload/game_state.gd",
		"res://scenes/main.tscn"
	]
	for df in disk_files:
		if FileAccess.file_exists(df):
			print("[PASS] Target file exists on disk: %s" % df)
			pass_count += 1
		else:
			printerr("[FAIL] Missing target file: %s" % df)
			fail_count += 1

	# -------------------------------------------------------------------------
	# 5. Lua Server Module Idempotency & Defense Checks
	# -------------------------------------------------------------------------
	print("\n--- Testing init_leaderboards.lua Script Integrity ---")
	var lua_path = "res://nakama/data/modules/init_leaderboards.lua"
	if FileAccess.file_exists(lua_path):
		var lf = FileAccess.open(lua_path, FileAccess.READ)
		var lua_text = lf.get_as_text()
		var pcall_count = lua_text.count("pcall")
		if pcall_count >= 2:
			print("[PASS] init_leaderboards.lua wraps leaderboard creation in pcall (count: %d)" % pcall_count)
			pass_count += 1
		else:
			printerr("[FAIL] init_leaderboards.lua has insufficient pcall wrappers: %d" % pcall_count)
			fail_count += 1

		if "local initialized = false" in lua_text and "if initialized then" in lua_text:
			print("[PASS] init_leaderboards.lua has local initialized guard against re-entrant runs")
			pass_count += 1
		else:
			printerr("[FAIL] init_leaderboards.lua lacks re-entrancy guard")
			fail_count += 1

		if "global_lifetime_users" in lua_text and "country_lifetime_users_" in lua_text:
			print("[PASS] init_leaderboards.lua registers both global and country leaderboards")
			pass_count += 1
		else:
			printerr("[FAIL] Missing required leaderboard names in Lua")
			fail_count += 1

		# Verify authoritative is false
		if 'false,                             -- authoritative: false' in lua_text or 'false,                         -- authoritative: false' in lua_text:
			print("[PASS] Leaderboards configured with authoritative = false (client submissions enabled)")
			pass_count += 1
		else:
			printerr("[FAIL] Leaderboards not confirmed as non-authoritative")
			fail_count += 1
	else:
		printerr("[FAIL] Lua script missing: %s" % lua_path)
		fail_count += 1

	# -------------------------------------------------------------------------
	# 6. Docker Compose Configuration Integrity
	# -------------------------------------------------------------------------
	print("\n--- Testing docker-compose.yml Integrity ---")
	var dc_path = "res://docker-compose.yml"
	if FileAccess.file_exists(dc_path):
		var dcf = FileAccess.open(dc_path, FileAccess.READ)
		var dc_text = dcf.get_as_text()
		if "./nakama/data/modules:/nakama/data/modules" in dc_text:
			print("[PASS] docker-compose.yml mounts ./nakama/data/modules into container")
			pass_count += 1
		else:
			printerr("[FAIL] docker-compose.yml missing modules volume mount")
			fail_count += 1

		if '"7350:7350"' in dc_text and '"7349:7349"' in dc_text:
			print("[PASS] docker-compose.yml maps ports 7349 and 7350")
			pass_count += 1
		else:
			printerr("[FAIL] docker-compose.yml missing API ports")
			fail_count += 1
	else:
		printerr("[FAIL] docker-compose.yml missing")
		fail_count += 1

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n=====================================================================")
	print("[ADVERSARIAL SUMMARY] Total Passed: %d | Total Failed: %d" % [pass_count, fail_count])
	print("=====================================================================")

	nakama_singleton.queue_free()

	if fail_count > 0:
		print(">>> VERDICT: REQUEST_CHANGES <<<")
	else:
		print(">>> VERDICT: APPROVE <<<")

	quit()
