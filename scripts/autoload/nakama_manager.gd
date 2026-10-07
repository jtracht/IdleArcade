extends Node

## NakamaManager Autoload Singleton (res://scripts/autoload/nakama_manager.gd)
## Coordinates Heroic Labs Nakama client initialization, invisible Device-ID
## authentication, email login/registration, session persistence in user://nakama_session.json,
## Google OAuth stubbing, and offline resilience for IdleArcade.

# --- Signals (Interface Contracts) ---
signal authenticated(session: NakamaSession)
signal auth_failed(error_message: String)
signal connection_status_changed(is_online: bool, status_text: String)
signal logged_out()

# Future Milestone (P2-M3) Signals
signal score_submitted(leaderboard_id: String, score: int)
signal leaderboard_received(leaderboard_id: String, records: Array)
signal guild_updated(guild_data: Dictionary)
signal guild_members_received(group_id: String, members: Array)
signal quests_updated(quests_dict: Dictionary)
signal quest_reward_claimed(quest_id: String, bonus_users: int)

# --- Configuration Constants ---
const DEFAULT_SERVER_KEY: String = "defaultkey"
const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 7350
const DEFAULT_SCHEME: String = "http"
const DEFAULT_TIMEOUT: float = 5.0

const DEVICE_ID_FILE: String = "user://device_id.txt"
const SESSION_FILE: String = "user://nakama_session.json"

# --- State Properties ---
var client: NakamaClient = null
var session: NakamaSession = null

# Alias for compatibility across explorer specifications
var current_session: NakamaSession:
	get:
		return session
	set(value):
		session = value

var device_id: String = ""
var is_online: bool = false
var is_authenticating: bool = false
var last_error: String = ""
var auto_login_on_ready: bool = true

# --- P2-M3 Leaderboard Configuration & State ---
const SCORE_SYNC_INTERVAL: float = 30.0
const MIN_SCORE_SYNC_COOLDOWN: float = 5.0

var _score_sync_timer: float = 0.0
var _last_sync_timestamp: float = 0.0
var _last_submitted_score: int = -1
var _is_submitting_score: bool = false
var _has_pending_score_sync: bool = false

# --- P2-M3 Guild State ---
var current_guild_id: String = ""
var current_guild_name: String = ""
var current_guild_desc: String = ""

# --- P2-M3 Daily Quests & Storage State ---
const QUEST_STORAGE_COLLECTION: String = "quests"
const QUEST_STORAGE_KEY: String = "daily"
const LOCAL_QUESTS_FILE: String = "user://daily_quests.json"

var daily_quests: Dictionary = {}
var quests_dirty: bool = false
var quest_storage_version: String = ""
var quest_sync_timer: float = 0.0

# Dynamic connection parameters (configurable via env vars or code)
var server_key: String = DEFAULT_SERVER_KEY
var host: String = DEFAULT_HOST
var port: int = DEFAULT_PORT
var scheme: String = DEFAULT_SCHEME
var timeout: float = DEFAULT_TIMEOUT

func _ready() -> void:
	_load_config_overrides()
	initialize_client()
	_connect_game_state_signals()
	if auto_login_on_ready:
		call_deferred("_boot_auth_flow")

func _process(delta: float) -> void:
	if not is_authenticated():
		return

	# Periodic score sync (30s)
	_score_sync_timer += delta
	if _score_sync_timer >= SCORE_SYNC_INTERVAL:
		_score_sync_timer = 0.0
		sync_current_score_async()

	# Debounced quest storage write (5s)
	if quests_dirty:
		quest_sync_timer += delta
		if quest_sync_timer >= 5.0:
			quest_sync_timer = 0.0
			_save_remote_quests_async()

func _load_config_overrides() -> void:
	if OS.has_environment("NAKAMA_HOST"):
		host = OS.get_environment("NAKAMA_HOST")
	if OS.has_environment("NAKAMA_PORT"):
		port = int(OS.get_environment("NAKAMA_PORT"))
	if OS.has_environment("NAKAMA_KEY"):
		server_key = OS.get_environment("NAKAMA_KEY")
	if OS.has_environment("NAKAMA_SCHEME"):
		scheme = OS.get_environment("NAKAMA_SCHEME")
	if OS.has_environment("NAKAMA_TIMEOUT"):
		timeout = float(OS.get_environment("NAKAMA_TIMEOUT"))

## Initializes the underlying NakamaClient node via Nakama autoload singleton
## or fallback node instantiation in isolated test environments.
func initialize_client() -> void:
	if client != null:
		return

	var nakama_autoload = get_node_or_null("/root/Nakama")
	if nakama_autoload != null and nakama_autoload.has_method("create_client"):
		client = nakama_autoload.create_client(server_key, host, port, scheme, timeout)
	else:
		# Fallback for standalone/headless test harnesses where autoloads aren't mounted
		var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
		if nakama_script != null:
			var nakama_instance = nakama_script.new()
			if is_inside_tree():
				get_tree().root.add_child(nakama_instance)
			else:
				add_child(nakama_instance)
			client = nakama_instance.create_client(server_key, host, port, scheme, timeout)
		else:
			push_error("[NakamaManager] Unable to load Nakama.gd factory script!")

func _connect_game_state_signals() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null:
		if game_state.has_signal("core_tapped") and not game_state.core_tapped.is_connected(_on_core_tapped):
			game_state.core_tapped.connect(_on_core_tapped)
		if game_state.has_signal("upgrade_purchased") and not game_state.upgrade_purchased.is_connected(_on_upgrade_purchased):
			game_state.upgrade_purchased.connect(_on_upgrade_purchased)
		if game_state.has_signal("spark_collected") and not game_state.spark_collected.is_connected(_on_spark_collected):
			game_state.spark_collected.connect(_on_spark_collected)

func _on_core_tapped(_total_clicks: int) -> void:
	record_quest_progress("tap", 1)

func _on_upgrade_purchased(_upgrade_id: String, _level: int, _cost: float) -> void:
	record_quest_progress("upgrade", 1)

func _on_spark_collected(_total_sparks: int) -> void:
	record_quest_progress("spark", 1)

func _boot_auth_flow() -> void:
	await auto_login_async()

# ==============================================================================
# Device-ID Generation & Persistence
# ==============================================================================

## Retrieves cached device ID or creates and stores a new one.
## Guarantees non-empty ID across desktop, Android, web, and CI runners.
func get_or_create_device_id() -> String:
	if not device_id.is_empty():
		return device_id

	# 1. Check persistent device ID file
	if FileAccess.file_exists(DEVICE_ID_FILE):
		var file := FileAccess.open(DEVICE_ID_FILE, FileAccess.READ)
		if file != null:
			var saved_id := file.get_as_text().strip_edges()
			file.close()
			if saved_id.length() >= 6 and saved_id.length() <= 128:
				device_id = saved_id
				return device_id

	# 2. Try OS unique ID
	var raw_os_id := OS.get_unique_id().strip_edges()
	if not raw_os_id.is_empty() and raw_os_id.to_lower() != "unknown" and raw_os_id != "0000000000000000" and raw_os_id.length() >= 6:
		device_id = raw_os_id
	else:
		# 3. Fallback to random RFC 4122 UUID v4
		device_id = generate_uuid_v4()

	# 4. Persist resolved device ID to disk
	var write_file := FileAccess.open(DEVICE_ID_FILE, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(device_id)
		write_file.flush()
		write_file.close()

	return device_id

## Alias helpers for get_or_create_device_id
func _get_or_create_device_id() -> String:
	return get_or_create_device_id()

func _load_or_create_device_id() -> String:
	return get_or_create_device_id()

## Generates RFC 4122 compliant UUID v4 string using cryptographically strong bytes.
static func generate_uuid_v4() -> String:
	var bytes: PackedByteArray
	var crypto := Crypto.new()
	bytes = crypto.generate_random_bytes(16)
	if bytes.size() < 16:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		bytes = PackedByteArray()
		for i in range(16):
			bytes.append(rng.randi_range(0, 255))

	# Set version to 0100 (v4)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	# Set variant to 10xx (RFC 4122)
	bytes[8] = (bytes[8] & 0x3F) | 0x80

	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]

static func _generate_uuid() -> String:
	return generate_uuid_v4()

# ==============================================================================
# Session Persistence & Disk Operations
# ==============================================================================

## Saves valid NakamaSession to disk as formatted JSON.
func _save_session(p_session: NakamaSession, p_auth_type: String = "device") -> bool:
	if p_session == null or p_session.is_exception() or p_session.token.is_empty():
		return false

	var data := p_session.serialize()
	data["auth_type"] = p_auth_type
	data["saved_at"] = Time.get_unix_time_from_system()

	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
	return true

func _save_session_to_disk(p_session: NakamaSession = null) -> bool:
	return _save_session(p_session if p_session != null else session)

## Loads and deserializes cached session from disk. Cleans corrupt files.
func _load_cached_session() -> NakamaSession:
	if not FileAccess.file_exists(SESSION_FILE):
		return null

	var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		_clear_saved_session()
		return null

	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		_clear_saved_session()
		return null

	var dict := json.data as Dictionary
	if not dict.has("token") or str(dict.get("token", "")).is_empty():
		_clear_saved_session()
		return null

	return NakamaSession.deserialize(dict)

func _load_session_from_disk() -> NakamaSession:
	return _load_cached_session()

## Deletes the persisted session file from user:// storage.
func _clear_saved_session() -> void:
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(SESSION_FILE)

func _clear_session_file() -> void:
	_clear_saved_session()

# ==============================================================================
# Authentication Lifecycle & Methods
# ==============================================================================

## Automatic entry point: Restores cached session (refreshing if needed)
## or falls back to silent Device-ID login.
func auto_login_async() -> NakamaSession:
	if is_authenticating:
		return session
	is_authenticating = true

	if device_id.is_empty():
		device_id = get_or_create_device_id()

	# 1. Attempt cached session restoration
	var cached_session := _load_cached_session()
	if cached_session != null and not cached_session.is_exception():
		var now := Time.get_unix_time_from_system()

		# Case 1: Valid access token (buffer >= 120s or non-expiring)
		if not cached_session.is_expired() and (cached_session.expire_time <= 0 or cached_session.expire_time - now > 120):
			session = cached_session
			is_online = true
			is_authenticating = false
			last_error = ""
			authenticated.emit(session)
			connection_status_changed.emit(true, "Session restored")
			return session

		# Case 2: Refresh token is still valid
		if not cached_session.is_refresh_expired() and not cached_session.refresh_token.is_empty():
			if client == null:
				initialize_client()
			var refreshed := await client.session_refresh_async(cached_session)
			if refreshed != null and not refreshed.is_exception():
				session = refreshed
				_save_session(session)
				is_online = true
				is_authenticating = false
				last_error = ""
				authenticated.emit(session)
				connection_status_changed.emit(true, "Session refreshed")
				return session
			elif refreshed != null and refreshed.is_exception() and refreshed.get_exception().status_code == 0:
				# Server unreachable/offline: retain cached session offline
				session = cached_session
				is_online = false
				is_authenticating = false
				last_error = refreshed.get_exception().message
				connection_status_changed.emit(false, "Offline: Server unreachable")
				return session
			else:
				# Expired or rejected on server
				_clear_saved_session()
		else:
			_clear_saved_session()

	# 2. Fallback to Device-ID authentication
	is_authenticating = false
	return await login_device_async()

## Alias for auto_login_async
func restore_or_login_async() -> NakamaSession:
	return await auto_login_async()

## Authenticates using a persistent device identifier.
func login_device_async(p_custom_id: String = "") -> NakamaSession:
	if is_authenticating:
		return session
	is_authenticating = true

	if not p_custom_id.is_empty():
		device_id = p_custom_id
	elif device_id.is_empty():
		device_id = get_or_create_device_id()

	if client == null:
		initialize_client()

	var new_session := await client.authenticate_device_async(device_id, "", true)
	if new_session == null or new_session.is_exception():
		var exc = new_session.get_exception() if new_session != null else null
		last_error = exc.message if exc != null else "Authentication failed"
		is_online = false
		is_authenticating = false
		auth_failed.emit(last_error)
		connection_status_changed.emit(false, "Offline")
		return new_session

	session = new_session
	is_online = true
	is_authenticating = false
	last_error = ""
	_save_session(session, "device")
	authenticated.emit(session)
	connection_status_changed.emit(true, "Connected via Device-ID")
	return session

## Authenticates or registers using Email and Password.
func login_email_async(p_email: String, p_password: String, p_is_create: bool = false) -> NakamaSession:
	if is_authenticating:
		return session
	is_authenticating = true

	if client == null:
		initialize_client()

	var new_session := await client.authenticate_email_async(p_email, p_password, "", p_is_create)
	if new_session == null or new_session.is_exception():
		var exc = new_session.get_exception() if new_session != null else null
		last_error = exc.message if exc != null else "Email authentication failed"
		is_online = false
		is_authenticating = false
		auth_failed.emit(last_error)
		connection_status_changed.emit(false, "Authentication failed: %s" % last_error)
		return new_session

	session = new_session
	is_online = true
	is_authenticating = false
	last_error = ""
	_save_session(session, "email")
	authenticated.emit(session)
	connection_status_changed.emit(true, "Connected via Email")
	return session

## Registers a new account using Email, Password, and optional display name.
func register_email_async(p_email: String, p_password: String, p_username: String = "") -> NakamaSession:
	if is_authenticating:
		return session
	is_authenticating = true

	if client == null:
		initialize_client()

	var new_session := await client.authenticate_email_async(p_email, p_password, p_username, true)
	if new_session == null or new_session.is_exception():
		var exc = new_session.get_exception() if new_session != null else null
		last_error = exc.message if exc != null else "Registration failed"
		is_online = false
		is_authenticating = false
		auth_failed.emit(last_error)
		connection_status_changed.emit(false, "Registration failed: %s" % last_error)
		return new_session

	session = new_session
	is_online = true
	is_authenticating = false
	last_error = ""
	_save_session(session, "email")
	authenticated.emit(session)
	connection_status_changed.emit(true, "Account registered via Email")
	return session

## Links email credentials to the currently active session.
func link_email_async(p_email: String, p_password: String) -> bool:
	if not is_authenticated():
		last_error = "Cannot link email: Not authenticated."
		return false

	var result := await client.link_email_async(session, p_email, p_password)
	if result == null or result.is_exception():
		last_error = result.get_exception().message if result != null else "Email link failed"
		return false
	return true

## Google OAuth Stub / Placeholder per Requirement R1.
## Returns structured response conforming to future provider interface.
func login_google_stub_async() -> Dictionary:
	push_warning("[NakamaManager] Google OAuth is currently an unconfigured stub.")
	return {
		"success": false,
		"status": "unsupported",
		"is_stub": true,
		"provider": "google",
		"message": "Google Account OAuth is currently a placeholder stub.",
		"error_code": 501,
		"token": "",
		"session": null
	}

func authenticate_google_stub_async() -> Dictionary:
	return login_google_stub_async()

## Clears current session, removes stored credentials, and updates state.
func logout() -> void:
	session = null
	is_online = false
	_clear_saved_session()
	logged_out.emit()
	connection_status_changed.emit(false, "Logged Out")

## Re-triggers automatic authentication flow.
func reconnect_async() -> NakamaSession:
	return await auto_login_async()

# ==============================================================================
# Helper & Accessor Methods
# ==============================================================================

func is_authenticated() -> bool:
	return session != null and not session.is_exception() and not session.is_expired() and not session.token.is_empty()

func get_user_id() -> String:
	return session.user_id if is_authenticated() else ""

func get_username() -> String:
	return session.username if is_authenticated() else ""

func get_session() -> NakamaSession:
	return session

func get_client() -> NakamaClient:
	return client

func get_device_id() -> String:
	return get_or_create_device_id()

# ==============================================================================
# Phase 2 Milestone 3: Scoreboards, Leaderboards & Guilds
# ==============================================================================

## Returns ISO country code from system locale (e.g. "de", "us", "global").
func get_player_country_code() -> String:
	var loc := OS.get_locale().to_lower()
	var parts := loc.split("_")
	var lang := parts[0] if parts.size() > 0 else "en"
	var region := parts[1] if parts.size() > 1 else ""
	var supported: Array[String] = ["de", "at", "ch", "us", "gb", "fr", "es", "it", "jp"]
	if region in supported:
		return region
	if lang in supported:
		return lang
	return "global"

## Returns target regional leaderboard ID for the player.
func get_country_leaderboard_id() -> String:
	return "country_lifetime_users_" + get_player_country_code()

## Submits score to specified leaderboard with contextual metadata.
func submit_score_async(score: int, leaderboard_id: String = "global_lifetime_users") -> bool:
	if not is_authenticated() or client == null:
		return false
	if _is_submitting_score:
		return false
	_is_submitting_score = true

	var meta: Dictionary = {
		"country": get_player_country_code(),
		"synced_at": int(Time.get_unix_time_from_system())
	}
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null:
		meta["clicks"] = int(game_state.total_clicks)
		meta["sparks"] = int(game_state.sparks_collected)
		meta["rps"] = float(game_state.base_passive_rps)
	if not current_guild_id.is_empty():
		meta["guild_id"] = current_guild_id
		meta["guild_name"] = current_guild_name

	var record: NakamaAPI.ApiLeaderboardRecord = await client.write_leaderboard_record_async(session, leaderboard_id, score, 0, meta)
	_is_submitting_score = false

	if record == null or record.is_exception():
		var exc = record.get_exception() if record != null else null
		last_error = exc.message if exc != null else "Failed to submit score"
		if exc != null and exc.status_code == 0:
			connection_status_changed.emit(false, "Offline")
			_has_pending_score_sync = true
		return false

	_last_submitted_score = maxi(_last_submitted_score, score)
	_has_pending_score_sync = false
	score_submitted.emit(leaderboard_id, score)
	return true

## Synchronizes the current lifetime users from GameState to global & regional leaderboards.
func sync_current_score_async() -> void:
	if not is_authenticated() or _is_submitting_score:
		return
	var now := Time.get_unix_time_from_system()
	if now - _last_sync_timestamp < MIN_SCORE_SYNC_COOLDOWN:
		return

	var game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		return

	var score_int: int = mini(maxi(int(round(game_state.total_energy_earned)), 0), 9223372036854775807)
	if score_int <= _last_submitted_score and not _has_pending_score_sync:
		return

	_last_sync_timestamp = now
	var ok_global := await submit_score_async(score_int, "global_lifetime_users")
	if ok_global:
		var country_lid := get_country_leaderboard_id()
		if country_lid != "global_lifetime_users":
			await submit_score_async(score_int, country_lid)

## Fetches top records from specified leaderboard.
func fetch_leaderboard_async(leaderboard_id: String = "global_lifetime_users", limit: int = 20) -> Array:
	if not is_authenticated() or client == null:
		return []

	var safe_limit: int = clampi(limit, 1, 100)
	var res: NakamaAPI.ApiLeaderboardRecordList = await client.list_leaderboard_records_async(session, leaderboard_id, [], 0, safe_limit, "")
	if res == null or res.is_exception():
		var exc = res.get_exception() if res != null else null
		last_error = exc.message if exc != null else "Failed to fetch leaderboard"
		return []

	var records: Array = res.records
	leaderboard_received.emit(leaderboard_id, records)
	return records

## Fetches leaderboard records filtered to members of the specified guild.
func fetch_guild_leaderboard_async(group_id: String, limit: int = 20) -> Array:
	if not is_authenticated() or client == null or group_id.is_empty():
		return []

	var group_users_res: NakamaAPI.ApiGroupUserList = await client.list_group_users_async(session, group_id, null, 100, "")
	if group_users_res == null or group_users_res.is_exception():
		var exc = group_users_res.get_exception() if group_users_res != null else null
		last_error = exc.message if exc != null else "Failed to list guild members"
		return []

	var member_ids: Array = []
	for gu in group_users_res.group_users:
		if gu.user != null and not str(gu.user.id).is_empty() and int(gu.state) <= 2:
			member_ids.append(gu.user.id)

	if member_ids.is_empty():
		return []

	var safe_limit: int = clampi(limit, 1, 100)
	var lb_res: NakamaAPI.ApiLeaderboardRecordList = await client.list_leaderboard_records_async(
		session,
		"global_lifetime_users",
		member_ids,
		0,
		safe_limit,
		""
	)
	if lb_res == null or lb_res.is_exception():
		var exc = lb_res.get_exception() if lb_res != null else null
		last_error = exc.message if exc != null else "Failed to fetch guild leaderboard"
		return []

	var records: Array = lb_res.records
	leaderboard_received.emit("guild_" + group_id, records)
	return records

## Creates a new Nakama group / guild. Creator becomes Superadmin (state 0).
func create_guild_async(name: String, desc: String, is_open: bool = true) -> Dictionary:
	if not is_authenticated() or client == null:
		last_error = "Cannot create guild: Not authenticated."
		return {}

	var group: NakamaAPI.ApiGroup = await client.create_group_async(session, name, desc, "", "en", is_open, 50)
	if group == null or group.is_exception():
		var exc = group.get_exception() if group != null else null
		last_error = exc.message if exc != null else "Failed to create guild"
		return {}

	current_guild_id = group.id
	current_guild_name = group.name
	current_guild_desc = group.description
	var guild_dict: Dictionary = {
		"id": group.id,
		"name": group.name,
		"description": group.description,
		"edge_count": group.edge_count,
		"max_count": group.max_count,
		"open": group.open
	}
	guild_updated.emit(guild_dict)
	return guild_dict

## Joins an existing guild by group ID, optionally tracking guild name and description.
func join_guild_async(group_id: String, group_name: String = "", group_desc: String = "") -> bool:
	if not is_authenticated() or client == null or group_id.is_empty():
		last_error = "Cannot join guild: Not authenticated or invalid ID."
		return false

	var res: NakamaAsyncResult = await client.join_group_async(session, group_id)
	if res == null or res.is_exception():
		var exc = res.get_exception() if res != null else null
		last_error = exc.message if exc != null else "Failed to join guild"
		return false

	current_guild_id = group_id
	if not group_name.is_empty():
		current_guild_name = group_name
	if not group_desc.is_empty():
		current_guild_desc = group_desc
	guild_updated.emit({
		"group_id": group_id,
		"action": "joined",
		"name": current_guild_name,
		"description": current_guild_desc
	})
	return true

## Leaves a guild by group ID.
func leave_guild_async(group_id: String) -> bool:
	if not is_authenticated() or client == null or group_id.is_empty():
		last_error = "Cannot leave guild: Not authenticated or invalid ID."
		return false

	var res: NakamaAsyncResult = await client.leave_group_async(session, group_id)
	if res == null or res.is_exception():
		var exc = res.get_exception() if res != null else null
		last_error = exc.message if exc != null else "Failed to leave guild"
		return false

	if current_guild_id == group_id:
		current_guild_id = ""
		current_guild_name = ""
		current_guild_desc = ""
	guild_updated.emit({})
	return true

## Lists public groups with optional name filter.
func list_guilds_async(filter: String = "") -> Array:
	if not is_authenticated() or client == null:
		return []

	var res: NakamaAPI.ApiGroupList = await client.list_groups_async(session, filter, 20)
	if res == null or res.is_exception():
		var exc = res.get_exception() if res != null else null
		last_error = exc.message if exc != null else "Failed to list guilds"
		return []

	var out: Array = []
	for g in res.groups:
		out.append({
			"id": g.id,
			"name": g.name,
			"description": g.description,
			"edge_count": g.edge_count,
			"max_count": g.max_count,
			"open": g.open
		})
	return out

## Lists members belonging to a group, mapped with human-readable roles.
func list_guild_members_async(group_id: String) -> Array:
	if not is_authenticated() or client == null or group_id.is_empty():
		return []

	var res: NakamaAPI.ApiGroupUserList = await client.list_group_users_async(session, group_id, null, 50)
	if res == null or res.is_exception():
		var exc = res.get_exception() if res != null else null
		last_error = exc.message if exc != null else "Failed to list guild members"
		return []

	var role_names = {0: "Superadmin", 1: "Admin", 2: "Member", 3: "Join Request"}
	var members: Array = []
	for gu in res.group_users:
		var uid: String = gu.user.id if gu.user != null else ""
		var uname: String = gu.user.username if gu.user != null else ""
		var state_int: int = int(gu.state)
		members.append({
			"user_id": uid,
			"username": uname,
			"state": state_int,
			"role": role_names.get(state_int, "Unknown")
		})
	guild_members_received.emit(group_id, members)
	return members

# ==============================================================================
# Phase 2 Milestone 3: Daily Quests & Storage Engine
# ==============================================================================

## Returns current UTC date string YYYY-MM-DD.
func get_current_utc_date() -> String:
	var dt := Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

## Default template for the 3 daily quests.
func _get_default_daily_quests() -> Dictionary:
	return {
		"date": get_current_utc_date(),
		"last_updated": int(Time.get_unix_time_from_system()),
		"quests": {
			"daily_tap": {
				"id": "daily_tap",
				"type": "tap",
				"title": "Reactor Tapper",
				"description": "Tap the startup core 50 times",
				"target": 50,
				"current": 0,
				"reward_bonus_users": 25,
				"is_completed": false,
				"is_claimed": false
			},
			"daily_upgrade": {
				"id": "daily_upgrade",
				"type": "upgrade",
				"title": "Industrial Expansion",
				"description": "Purchase 3 generator upgrades",
				"target": 3,
				"current": 0,
				"reward_bonus_users": 50,
				"is_completed": false,
				"is_claimed": false
			},
			"daily_spark": {
				"id": "daily_spark",
				"type": "spark",
				"title": "Energy Surge",
				"description": "Catch 3 drifting bonus sparks",
				"target": 3,
				"current": 0,
				"reward_bonus_users": 100,
				"is_completed": false,
				"is_claimed": false
			}
		}
	}

## Saves active daily quests to local cache user://daily_quests.json.
func _save_local_quests_cache() -> bool:
	var file := FileAccess.open(LOCAL_QUESTS_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(daily_quests, "  "))
	file.flush()
	file.close()
	return true

## Loads daily quests from local cache user://daily_quests.json.
func _load_local_quests_cache() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_QUESTS_FILE):
		return {}
	var file := FileAccess.open(LOCAL_QUESTS_FILE, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return {}
	return json.data as Dictionary

## Saves active daily quests to Nakama Remote Storage (collection "quests", key "daily").
func _save_remote_quests_async() -> bool:
	if not is_authenticated() or client == null:
		return false
	var write_obj := NakamaWriteStorageObject.new(
		QUEST_STORAGE_COLLECTION,
		QUEST_STORAGE_KEY,
		JSON.stringify(daily_quests),
		quest_storage_version,
		1,
		1
	)
	var acks: NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [write_obj])
	if acks == null or acks.is_exception():
		if acks != null and acks.get_exception().status_code == 409:
			# Concurrency conflict: clear version and retry unconditional write
			write_obj.version = ""
			acks = await client.write_storage_objects_async(session, [write_obj])
		if acks == null or acks.is_exception():
			return false
	if acks.acks.size() > 0:
		quest_storage_version = acks.acks[0].version
	quests_dirty = false
	return true

## Fetches daily quests from Nakama Storage, local cache, or default template.
func fetch_daily_quests_async() -> Dictionary:
	var today := get_current_utc_date()

	# 1. Try remote fetch if online and authenticated
	if is_authenticated() and client != null:
		var obj_id := NakamaStorageObjectId.new(QUEST_STORAGE_COLLECTION, QUEST_STORAGE_KEY, session.user_id)
		var result: NakamaAPI.ApiStorageObjects = await client.read_storage_objects_async(session, [obj_id])
		if result != null and not result.is_exception() and result.objects.size() > 0:
			var obj: NakamaAPI.ApiStorageObject = result.objects[0]
			quest_storage_version = obj.version
			var parsed = JSON.parse_string(obj.value)
			if parsed is Dictionary and parsed.has("date"):
				if str(parsed.get("date", "")) == today:
					daily_quests = parsed
					_save_local_quests_cache()
					quests_updated.emit(daily_quests)
					return daily_quests
				else:
					# Stored date is outdated -> Daily rollover
					daily_quests = _get_default_daily_quests()
					await _save_remote_quests_async()
					_save_local_quests_cache()
					quests_updated.emit(daily_quests)
					return daily_quests
		# First time in storage -> initialize default quests
		daily_quests = _get_default_daily_quests()
		await _save_remote_quests_async()
		_save_local_quests_cache()
		quests_updated.emit(daily_quests)
		return daily_quests

	# 2. Offline / local fallback
	if FileAccess.file_exists(LOCAL_QUESTS_FILE):
		var local_data := _load_local_quests_cache()
		if not local_data.is_empty() and str(local_data.get("date", "")) == today:
			daily_quests = local_data
			quests_updated.emit(daily_quests)
			return daily_quests
		elif not local_data.is_empty():
			daily_quests = _get_default_daily_quests()
			_save_local_quests_cache()
			quests_updated.emit(daily_quests)
			return daily_quests

	if not daily_quests.is_empty() and str(daily_quests.get("date", "")) == today:
		quests_updated.emit(daily_quests)
		return daily_quests

	return {}

## Advances quest progress for matching event type (e.g. "tap", "upgrade", "spark").
func record_quest_progress(quest_type: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	if daily_quests.is_empty():
		var local_data := _load_local_quests_cache()
		var today := get_current_utc_date()
		if not local_data.is_empty() and str(local_data.get("date", "")) == today:
			daily_quests = local_data
		else:
			daily_quests = _get_default_daily_quests()
			_save_local_quests_cache()

	var today := get_current_utc_date()
	if str(daily_quests.get("date", "")) != today:
		daily_quests = _get_default_daily_quests()
		quests_dirty = true

	var quests_map: Dictionary = daily_quests.get("quests", {})
	var state_changed: bool = false

	for q_id in quests_map:
		var q: Dictionary = quests_map[q_id]
		if (q.get("type", "") == quest_type or q_id == quest_type) and not q.get("is_completed", false):
			var current_val: int = int(q.get("current", 0)) + amount
			var target_val: int = int(q.get("target", 1))
			q["current"] = mini(target_val, current_val)
			if q["current"] >= target_val:
				q["is_completed"] = true
			state_changed = true
			quests_dirty = true

	if state_changed:
		daily_quests["last_updated"] = int(Time.get_unix_time_from_system())
		_save_local_quests_cache()
		quests_updated.emit(daily_quests)

## Validates completion, awards bonus users to GameState, and persists claim status.
func claim_quest_reward_async(quest_id: String) -> int:
	if daily_quests.is_empty():
		var local_data := _load_local_quests_cache()
		if not local_data.is_empty():
			daily_quests = local_data
		else:
			return 0

	var quests_map: Dictionary = daily_quests.get("quests", {})
	if not quests_map.has(quest_id):
		return 0

	var q: Dictionary = quests_map[quest_id]
	if not q.get("is_completed", false) or q.get("is_claimed", false):
		return 0

	q["is_claimed"] = true
	var reward_bonus: int = int(q.get("reward_bonus_users", 0))
	daily_quests["last_updated"] = int(Time.get_unix_time_from_system())

	# Award bonus users directly to GameState singleton
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("award_bonus_users"):
		game_state.award_bonus_users(reward_bonus)

	_save_local_quests_cache()
	if is_authenticated() and client != null:
		await _save_remote_quests_async()

	quest_reward_claimed.emit(quest_id, reward_bonus)
	quests_updated.emit(daily_quests)
	return reward_bonus
