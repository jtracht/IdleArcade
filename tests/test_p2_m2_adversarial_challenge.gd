extends SceneTree

## Adversarial Empirical Challenge Test Suite for Phase 2 Milestone 2.
## Focus:
## 1. Corrupted session JSON in user://nakama_session.json (0 bytes, whitespace, malformed, non-dict, missing fields)
## 2. Corrupted / empty user://device_id.txt (0 bytes, whitespace, <6 chars, >128 chars, boundaries)
## 3. RFC 4122 UUID v4 formatting (version nibble '4', variant nibble 8/9/a/b, hyphens, 1000-sample collision test)
## 4. Google OAuth stub return structure & alias consistency
## 5. Server unreachable resilience (status code 0, offline handling, non-blocking flow)
## 6. Session serialization, persistence, and logout lifecycle
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m2_adversarial_challenge.gd

func _init() -> void:
	print("=====================================================================")
	print("[ADVERSARIAL CHALLENGE] Phase 2 Milestone 2 Empirical Stress Tests")
	print("=====================================================================")
	process_frame.connect(_run_adversarial_tests, CONNECT_ONE_SHOT)

func _run_adversarial_tests() -> void:
	var pass_count: int = 0
	var fail_count: int = 0

	# -------------------------------------------------------------------------
	# Setup Nakama and NakamaManager nodes
	# -------------------------------------------------------------------------
	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	if nakama_script == null:
		printerr("[FATAL] Could not load Nakama.gd")
		quit(1)
		return

	var nakama_singleton = nakama_script.new()
	nakama_singleton.name = "Nakama"
	root.add_child(nakama_singleton)

	var mgr_script = load("res://scripts/autoload/nakama_manager.gd")
	if mgr_script == null:
		printerr("[FATAL] Could not load nakama_manager.gd")
		quit(1)
		return

	var mgr = mgr_script.new()
	mgr.name = "NakamaManager"
	mgr.auto_login_on_ready = false  # Disable automatic boot flow during test
	root.add_child(mgr)

	const SESS_PATH = "user://nakama_session.json"
	const DEV_PATH = "user://device_id.txt"

	# Helper closure for assertions
	var assert_true = func(cond: bool, test_name: String) -> void:
		if cond:
			print("  [PASS] %s" % test_name)
			pass_count += 1
		else:
			printerr("  [FAIL] %s" % test_name)
			fail_count += 1

	# =========================================================================
	# 1. Corrupted session JSON in user://nakama_session.json
	# =========================================================================
	print("\n--- 1. Testing Corrupted Session JSON in user://nakama_session.json ---")

	# Test 1.1: File does not exist
	if FileAccess.file_exists(SESS_PATH):
		DirAccess.remove_absolute(SESS_PATH)
	var res_missing = mgr._load_cached_session()
	assert_true.call(res_missing == null, "Non-existent session file returns null safely")

	# Test 1.2: Zero bytes (empty file)
	var f_zero = FileAccess.open(SESS_PATH, FileAccess.WRITE)
	f_zero.store_string("")
	f_zero.close()
	var res_zero = mgr._load_cached_session()
	var file_cleaned_zero = not FileAccess.file_exists(SESS_PATH)
	assert_true.call(res_zero == null and file_cleaned_zero, "Zero-byte session file returns null and deletes corrupt file")

	# Test 1.3: Whitespace only
	var f_ws = FileAccess.open(SESS_PATH, FileAccess.WRITE)
	f_ws.store_string("   \r\n\t  \n  ")
	f_ws.close()
	var res_ws = mgr._load_cached_session()
	var file_cleaned_ws = not FileAccess.file_exists(SESS_PATH)
	assert_true.call(res_ws == null and file_cleaned_ws, "Whitespace-only session file returns null and deletes corrupt file")

	# Test 1.4: Malformed syntax (syntax error)
	var malformed_payloads: Array[String] = [
		"{ 'invalid_quotes': true }",
		"{\"token\": \"unterminated_string",
		"{\"token\": true, ,,, }",
		"not_even_json_content",
		"<!-- XML content -->"
	]
	var malformed_all_pass: bool = true
	for p in malformed_payloads:
		var f_mal = FileAccess.open(SESS_PATH, FileAccess.WRITE)
		f_mal.store_string(p)
		f_mal.close()
		var res_mal = mgr._load_cached_session()
		if res_mal != null or FileAccess.file_exists(SESS_PATH):
			malformed_all_pass = false
			printerr("    Failed on payload: %s" % p)
	assert_true.call(malformed_all_pass, "5 malformed JSON syntax variations cleanly return null and delete corrupt file")

	# Test 1.5: Valid JSON but non-dictionary data types
	var non_dict_payloads: Array[String] = [
		"[1, 2, 3, \"array\"]",
		"\"just_a_string_token\"",
		"4294967295",
		"true",
		"null"
	]
	var non_dict_all_pass: bool = true
	for nd in non_dict_payloads:
		var f_nd = FileAccess.open(SESS_PATH, FileAccess.WRITE)
		f_nd.store_string(nd)
		f_nd.close()
		var res_nd = mgr._load_cached_session()
		if res_nd != null or FileAccess.file_exists(SESS_PATH):
			non_dict_all_pass = false
			printerr("    Failed on non-dict payload: %s" % nd)
	assert_true.call(non_dict_all_pass, "Non-dictionary JSON types (array, string, int, bool, null) return null and delete file")

	# Test 1.6: Missing fields (missing 'token')
	var missing_fields_payloads: Array[String] = [
		"{}",
		"{\"user_id\": \"usr-123\", \"username\": \"arcade_king\"}",
		"{\"created\": true, \"expire_time\": 2000000000}",
		"{\"token\": \"\"}"  # Empty token string
	]
	var missing_all_pass: bool = true
	for mf in missing_fields_payloads:
		var f_mf = FileAccess.open(SESS_PATH, FileAccess.WRITE)
		f_mf.store_string(mf)
		f_mf.close()
		var res_mf = mgr._load_cached_session()
		if res_mf != null or FileAccess.file_exists(SESS_PATH):
			missing_all_pass = false
			printerr("    Failed on missing token payload: %s" % mf)
	assert_true.call(missing_all_pass, "Missing or empty 'token' payloads cleanly return null and delete file")

	# =========================================================================
	# 2. Corrupted / empty user://device_id.txt
	# =========================================================================
	print("\n--- 2. Testing Corrupted & Edge-Case user://device_id.txt ---")

	# Test 2.1: Missing device ID file -> creates fresh ID and saves
	if FileAccess.file_exists(DEV_PATH):
		DirAccess.remove_absolute(DEV_PATH)
	mgr.device_id = ""
	var id_from_missing = mgr.get_or_create_device_id()
	var dev_file_created = FileAccess.file_exists(DEV_PATH)
	assert_true.call(not id_from_missing.is_empty() and id_from_missing.length() >= 6 and dev_file_created,
		"Missing device_id.txt generates valid ID and creates file on disk: '%s'" % id_from_missing)

	# Test 2.2: Zero-byte file -> cleans and regenerates
	var f_dev_zero = FileAccess.open(DEV_PATH, FileAccess.WRITE)
	f_dev_zero.store_string("")
	f_dev_zero.close()
	mgr.device_id = ""
	var id_from_zero = mgr.get_or_create_device_id()
	assert_true.call(not id_from_zero.is_empty() and id_from_zero.length() >= 6,
		"Zero-byte device_id.txt cleanly regenerated: '%s'" % id_from_zero)

	# Test 2.3: Whitespace only file
	var f_dev_ws = FileAccess.open(DEV_PATH, FileAccess.WRITE)
	f_dev_ws.store_string("   \t\n  \r  ")
	f_dev_ws.close()
	mgr.device_id = ""
	var id_from_ws = mgr.get_or_create_device_id()
	assert_true.call(not id_from_ws.is_empty() and id_from_ws.length() >= 6 and id_from_ws != "   \t\n  \r  ",
		"Whitespace-only device_id.txt cleanly regenerated: '%s'" % id_from_ws)

	# Test 2.4: Too short ID (< 6 characters)
	var f_dev_short = FileAccess.open(DEV_PATH, FileAccess.WRITE)
	f_dev_short.store_string("12345")
	f_dev_short.close()
	mgr.device_id = ""
	var id_from_short = mgr.get_or_create_device_id()
	assert_true.call(id_from_short != "12345" and id_from_short.length() >= 6,
		"Under-length (< 6 chars) device_id.txt regenerated: '%s'" % id_from_short)

	# Test 2.5: Overly long ID (> 128 characters)
	var long_id = "a".repeat(129)
	var f_dev_long = FileAccess.open(DEV_PATH, FileAccess.WRITE)
	f_dev_long.store_string(long_id)
	f_dev_long.close()
	mgr.device_id = ""
	var id_from_long = mgr.get_or_create_device_id()
	assert_true.call(id_from_long != long_id and id_from_long.length() >= 6 and id_from_long.length() <= 128,
		"Over-length (> 128 chars) device_id.txt regenerated: '%s'" % id_from_long)

	# Test 2.6: Boundary testing (exactly 6 and 128 chars)
	var valid_min_id = "123456"
	var f_dev_min = FileAccess.open(DEV_PATH, FileAccess.WRITE)
	f_dev_min.store_string(valid_min_id)
	f_dev_min.close()
	mgr.device_id = ""
	var id_from_min = mgr.get_or_create_device_id()
	assert_true.call(id_from_min == valid_min_id, "Exact 6-character boundary ID correctly accepted")

	var valid_max_id = "b".repeat(128)
	var f_dev_max = FileAccess.open(DEV_PATH, FileAccess.WRITE)
	f_dev_max.store_string(valid_max_id)
	f_dev_max.close()
	mgr.device_id = ""
	var id_from_max = mgr.get_or_create_device_id()
	assert_true.call(id_from_max == valid_max_id, "Exact 128-character boundary ID correctly accepted")

	# Test 2.7: In-memory caching idempotency
	var cached_id = mgr.get_or_create_device_id()
	assert_true.call(cached_id == valid_max_id, "Idempotent retrieval preserves cached ID in memory")

	# =========================================================================
	# 3. RFC 4122 UUID v4 Empirical Generator & Oracle (1,000 Samples)
	# =========================================================================
	print("\n--- 3. Testing RFC 4122 UUID v4 Formatting (1,000 Empirical Samples) ---")

	var uuid_format_ok: bool = true
	var generated_uuids: Dictionary = {}
	var hex_chars = "0123456789abcdef"

	for i in range(1000):
		var u = mgr.generate_uuid_v4()
		# Check length
		if u.length() != 36:
			uuid_format_ok = false
			printerr("    Invalid UUID length: %d for %s" % [u.length(), u])
			break

		# Check hyphen positions: 8, 13, 18, 23
		if u[8] != "-" or u[13] != "-" or u[18] != "-" or u[23] != "-":
			uuid_format_ok = false
			printerr("    Invalid hyphen positions in: %s" % u)
			break

		# Check RFC 4122 version nibble: index 14 must be '4'
		if u[14] != "4":
			uuid_format_ok = false
			printerr("    Invalid version nibble (expected '4', got '%s') in: %s" % [u[14], u])
			break

		# Check RFC 4122 variant nibble: index 19 must be '8', '9', 'a', or 'b'
		var variant_char = u[19].to_lower()
		if not ["8", "9", "a", "b"].has(variant_char):
			uuid_format_ok = false
			printerr("    Invalid variant nibble (expected 8/9/a/b, got '%s') in: %s" % [variant_char, u])
			break

		# Check that all other positions are hex digits
		for idx in range(36):
			if [8, 13, 18, 23].has(idx):
				continue
			if not hex_chars.contains(u[idx].to_lower()):
				uuid_format_ok = false
				printerr("    Non-hex character at idx %d: '%s' in %s" % [idx, u[idx], u])
				break

		# Check for collision
		if generated_uuids.has(u):
			uuid_format_ok = false
			printerr("    UUID collision detected on iteration %d: %s" % [i, u])
			break
		generated_uuids[u] = true

	assert_true.call(uuid_format_ok and generated_uuids.size() == 1000,
		"1,000 / 1,000 UUID v4 samples conform strictly to RFC 4122 (version=4, variant=8..b, 0 collisions)")

	# Test 3.2: Static method and alias consistency
	var static_uuid = NakamaManager.generate_uuid_v4()
	var alias_uuid = NakamaManager._generate_uuid()
	assert_true.call(static_uuid.length() == 36 and alias_uuid.length() == 36 and static_uuid[14] == "4" and alias_uuid[14] == "4",
		"Static NakamaManager.generate_uuid_v4 and _generate_uuid aliases functional")

	# =========================================================================
	# 4. Google OAuth Stub Return Structure & Interface
	# =========================================================================
	print("\n--- 4. Testing Google OAuth Stub Structure ---")

	var g_stub: Dictionary = mgr.login_google_stub_async()
	var g_alias: Dictionary = mgr.authenticate_google_stub_async()

	var stub_keys_ok: bool = true
	var required_keys = ["success", "status", "is_stub", "provider", "message", "error_code", "token", "session"]
	for k in required_keys:
		if not g_stub.has(k):
			stub_keys_ok = false
			printerr("    Missing stub key: %s" % k)

	var stub_values_ok: bool = (
		g_stub.get("success") == false
		and g_stub.get("status") == "unsupported"
		and g_stub.get("is_stub") == true
		and g_stub.get("provider") == "google"
		and g_stub.get("error_code") == 501
		and g_stub.get("token") == ""
		and g_stub.get("session") == null
		and str(g_stub.get("message", "")).length() > 0
	)
	var alias_identical: bool = (g_stub == g_alias)

	assert_true.call(stub_keys_ok and stub_values_ok and alias_identical,
		"Google OAuth stub returns compliant dictionary schema with HTTP 501 status and matching alias")

	# =========================================================================
	# 5. Server Unreachable / Offline Handling (Status Code 0)
	# =========================================================================
	print("\n--- 5. Testing Server Unreachable / Offline Handling ---")

	# Create a client pointing to an unmapped port (7359) with low timeout (0.5s)
	var unreachable_client = nakama_singleton.create_client("defaultkey", "127.0.0.1", 7359, "http", 0.5)

	# Direct client call
	var offline_direct_session: NakamaSession = await unreachable_client.authenticate_device_async("offline_test_id")
	var is_offline_exception = (offline_direct_session != null and offline_direct_session.is_exception())
	var exc_status = offline_direct_session.get_exception().status_code if is_offline_exception else -1

	assert_true.call(is_offline_exception and exc_status == 0,
		"Unreachable server produces NakamaException with status code 0 (connection refused)")

	# NakamaManager integration with unreachable settings
	mgr.client = unreachable_client
	mgr.session = null
	mgr.is_online = true  # Set to true to verify it is set to false on failure

	var signal_auth_failed_fired: bool = false
	var signal_status_changed_fired: bool = false
	var status_text_received: String = ""

	var c1 = mgr.auth_failed.connect(func(err): signal_auth_failed_fired = true)
	var c2 = mgr.connection_status_changed.connect(func(online, txt):
		signal_status_changed_fired = true
		status_text_received = txt
	)

	var mgr_offline_result = await mgr.login_device_async("test_offline_dev")

	mgr.auth_failed.disconnect(c1)
	mgr.connection_status_changed.disconnect(c2)

	assert_true.call(
		mgr_offline_result != null
		and mgr_offline_result.is_exception()
		and not mgr.is_online
		and not mgr.is_authenticating
		and signal_auth_failed_fired
		and signal_status_changed_fired
		and not mgr.is_authenticated(),
		"login_device_async safely handles offline server: sets is_online=false, emits signals, doesn't hang"
	)

	# Test 5.3: Offline cached session retention on refresh failure
	var mock_cached = NakamaSession.new()
	mock_cached.token = "offline_jwt_token"
	mock_cached.refresh_token = "offline_refresh_token"
	mock_cached.user_id = "offline-user-uuid"
	mock_cached.expire_time = int(Time.get_unix_time_from_system() - 100) # Access token expired
	mock_cached.refresh_expire_time = int(Time.get_unix_time_from_system() + 86400) # Refresh token valid
	mgr._save_session(mock_cached)

	var restored_offline = await mgr.auto_login_async()
	assert_true.call(
		restored_offline != null
		and restored_offline.user_id == mock_cached.user_id
		and not mgr.is_online
		and FileAccess.file_exists(SESS_PATH),
		"Offline auto-login retains cached session in offline mode without wiping session file when status_code=0"
	)

	# =========================================================================
	# 6. Session Persistence & Logout Lifecycle
	# =========================================================================
	print("\n--- 6. Testing Session Persistence & Logout Lifecycle ---")

	var valid_mock = NakamaSession.new()
	valid_mock.token = "valid_bearer_token"
	valid_mock.refresh_token = "valid_refresh_bearer"
	valid_mock.user_id = "user-abc-123"
	valid_mock.username = "HeroPlayer"
	valid_mock.expire_time = int(Time.get_unix_time_from_system() + 3600)
	valid_mock.refresh_expire_time = int(Time.get_unix_time_from_system() + 7200)

	var save_res = mgr._save_session(valid_mock)
	var load_res = mgr._load_cached_session()
	assert_true.call(save_res and load_res != null and load_res.user_id == "user-abc-123",
		"Valid mock session successfully saved and restored from user://nakama_session.json")

	mgr.session = valid_mock
	mgr.is_online = true
	var logout_signal_fired: bool = false
	var c_logout = mgr.logged_out.connect(func(): logout_signal_fired = true)

	mgr.logout()
	mgr.logged_out.disconnect(c_logout)

	assert_true.call(
		mgr.session == null
		and not mgr.is_online
		and not FileAccess.file_exists(SESS_PATH)
		and logout_signal_fired
		and not mgr.is_authenticated(),
		"logout() resets session, is_online=false, purges disk file, and emits logged_out"
	)

	# =========================================================================
	# Summary & Verdict
	# =========================================================================
	print("\n=====================================================================")
	print("[ADVERSARIAL SUMMARY] Total Checks: %d | Passed: %d | Failed: %d" % [pass_count + fail_count, pass_count, fail_count])
	print("=====================================================================")

	nakama_singleton.queue_free()
	mgr.queue_free()

	if fail_count > 0:
		print(">>> ADVERSARIAL VERDICT: REQUEST_CHANGES <<<")
		quit(1)
	else:
		print(">>> ADVERSARIAL VERDICT: APPROVE <<<")
		quit(0)
