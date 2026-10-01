extends SceneTree

## Headless Verification Suite for Phase 2 Milestone 1:
## Nakama Godot Addon Installation, Project Configuration & Server Runtime Module Setup.
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m1_nakama_setup.gd

func _init() -> void:
	print("===========================================================")
	print("[TEST] IdleArcade Phase 2 Milestone 1 Verification Suite")
	print("===========================================================")

	var pass_count: int = 0
	var fail_count: int = 0

	# -------------------------------------------------------------------------
	# 1. Addon File Completeness Checks
	# -------------------------------------------------------------------------
	var required_files: Array[String] = [
		"res://addons/com.heroiclabs.nakama/plugin.cfg",
		"res://addons/com.heroiclabs.nakama/Nakama.gd",
		"res://addons/com.heroiclabs.nakama/NakamaClient.gd",
		"res://addons/com.heroiclabs.nakama/NakamaSession.gd",
		"res://addons/com.heroiclabs.nakama/NakamaSocket.gd",
		"res://addons/com.heroiclabs.nakama/NakamaAPI.gd",
		"res://addons/com.heroiclabs.nakama/NakamaAsyncResult.gd",
		"res://addons/com.heroiclabs.nakama/NakamaException.gd",
		"res://addons/com.heroiclabs.nakama/NakamaLogger.gd",
		"res://addons/com.heroiclabs.nakama/NakamaSerializer.gd",
		"res://addons/com.heroiclabs.nakama/NakamaHTTPAdapter.gd",
		"res://addons/com.heroiclabs.nakama/NakamaWebSocketAdapter.gd",
		"res://addons/com.heroiclabs.nakama/NakamaStorageObjectId.gd",
		"res://addons/com.heroiclabs.nakama/NakamaWriteStorageObject.gd",
		"res://addons/com.heroiclabs.nakama/NakamaRTMessage.gd"
	]

	for file_path in required_files:
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null and file.get_length() > 0:
				print("[PASS] Addon file verified: %s (%d bytes)" % [file_path, file.get_length()])
				pass_count += 1
			else:
				printerr("[FAIL] Addon file is empty: %s" % file_path)
				fail_count += 1
		else:
			printerr("[FAIL] Missing addon file: %s" % file_path)
			fail_count += 1

	# -------------------------------------------------------------------------
	# 2. Addon Script Loading & Syntax Verification
	# -------------------------------------------------------------------------
	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	if nakama_script != null:
		print("[PASS] Successfully parsed and loaded Nakama.gd")
		pass_count += 1
	else:
		printerr("[FAIL] Could not load Nakama.gd")
		fail_count += 1

	var client_script = load("res://addons/com.heroiclabs.nakama/NakamaClient.gd")
	if client_script != null:
		print("[PASS] Successfully parsed and loaded NakamaClient.gd")
		pass_count += 1
	else:
		printerr("[FAIL] Could not load NakamaClient.gd")
		fail_count += 1

	var session_script = load("res://addons/com.heroiclabs.nakama/NakamaSession.gd")
	if session_script != null:
		print("[PASS] Successfully parsed and loaded NakamaSession.gd")
		pass_count += 1
	else:
		printerr("[FAIL] Could not load NakamaSession.gd")
		fail_count += 1

	var api_script = load("res://addons/com.heroiclabs.nakama/NakamaAPI.gd")
	if api_script != null:
		print("[PASS] Successfully parsed and loaded NakamaAPI.gd")
		pass_count += 1
	else:
		printerr("[FAIL] Could not load NakamaAPI.gd")
		fail_count += 1

	# -------------------------------------------------------------------------
	# 3. Nakama Factory & Session Behavior
	# -------------------------------------------------------------------------
	if nakama_script != null:
		var nakama_node = nakama_script.new()
		root.add_child(nakama_node)

		var client = nakama_node.create_client("defaultkey", "127.0.0.1", 7350, "http")
		if client != null and client is NakamaClient:
			print("[PASS] Nakama.create_client returned valid NakamaClient instance")
			pass_count += 1
		else:
			printerr("[FAIL] Nakama.create_client failed to create NakamaClient")
			fail_count += 1

		# Test JWT session restoration
		# Sample JWT with sub=user-uuid, usn=testplayer, exp=1999999999
		# eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMTExMTExMS0yMjIyLTMzMzMtNDQ0NC01NTU1NTU1NTU1NTUiLCJ1c24iOiJ0ZXN0cGxheWVyIiwiZXhwIjoxOTk5OTk5OTk5fQ.signature
		var sample_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMTExMTExMS0yMjIyLTMzMzMtNDQ0NC01NTU1NTU1NTU1NTUiLCJ1c24iOiJ0ZXN0cGxheWVyIiwiZXhwIjoxOTk5OTk5OTk5fQ.signature"
		var restored_session = NakamaClient.restore_session(sample_token)
		if restored_session != null and restored_session.user_id == "11111111-2222-3333-4444-555555555555" and restored_session.username == "testplayer":
			print("[PASS] NakamaClient.restore_session correctly unpacked JWT payload")
			pass_count += 1
		else:
			printerr("[FAIL] NakamaClient.restore_session failed to parse sample JWT")
			fail_count += 1

		nakama_node.queue_free()

	# -------------------------------------------------------------------------
	# 4. Project Configuration (project.godot)
	# -------------------------------------------------------------------------
	var autoload_nakama = ProjectSettings.get_setting("autoload/Nakama", "")
	var autoload_gamestate = ProjectSettings.get_setting("autoload/GameState", "")
	if "*res://addons/com.heroiclabs.nakama/Nakama.gd" in autoload_nakama:
		print("[PASS] Nakama autoload registered properly: %s" % autoload_nakama)
		pass_count += 1
	else:
		printerr("[FAIL] Nakama autoload missing or wrong: %s" % autoload_nakama)
		fail_count += 1

	if "*res://scripts/autoload/game_state.gd" in autoload_gamestate:
		print("[PASS] GameState autoload preserved: %s" % autoload_gamestate)
		pass_count += 1
	else:
		printerr("[FAIL] GameState autoload broken: %s" % autoload_gamestate)
		fail_count += 1

	var editor_plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	if "res://addons/com.heroiclabs.nakama/plugin.cfg" in editor_plugins:
		print("[PASS] Nakama plugin enabled in editor_plugins: %s" % str(editor_plugins))
		pass_count += 1
	else:
		printerr("[FAIL] Nakama plugin not found in editor_plugins: %s" % str(editor_plugins))
		fail_count += 1

	# -------------------------------------------------------------------------
	# 5. Lua Server Runtime Module Verification
	# -------------------------------------------------------------------------
	var lua_path = "res://nakama/data/modules/init_leaderboards.lua"
	if FileAccess.file_exists(lua_path):
		var lua_file = FileAccess.open(lua_path, FileAccess.READ)
		var lua_content = lua_file.get_as_text()
		var has_global = "global_lifetime_users" in lua_content
		var has_country = "country_lifetime_users_" in lua_content
		var has_pcall = "pcall" in lua_content
		var has_init = "InitModule" in lua_content

		if has_global and has_country and has_pcall and has_init:
			print("[PASS] init_leaderboards.lua verified with idempotent leaderboard setup")
			pass_count += 1
		else:
			printerr("[FAIL] init_leaderboards.lua missing required clauses")
			fail_count += 1
	else:
		printerr("[FAIL] Missing init_leaderboards.lua at %s" % lua_path)
		fail_count += 1

	print("===========================================================")
	print("[SUMMARY] Passed: %d | Failed: %d" % [pass_count, fail_count])
	print("===========================================================")

	if fail_count > 0:
		print("[RESULT] VERIFICATION FAILED")
	else:
		print("[RESULT] ALL CHECKS PASSED")

	quit()
