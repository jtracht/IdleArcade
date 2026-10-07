extends Control

## AuthModal Controller (res://scenes/ui/auth_modal.gd)
## Manages user identity, Device-ID login, Email/Password login & registration,
## Google OAuth stub, and logout via NakamaManager singleton.

signal closed()

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var status_value_label: Label = %StatusValueLabel
@onready var user_id_label: Label = %UserIdLabel
@onready var username_label: Label = %UsernameLabel
@onready var device_id_label: Label = %DeviceIdLabel

@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var username_input: LineEdit = %UsernameInput

@onready var login_button: Button = %LoginButton
@onready var register_button: Button = %RegisterButton
@onready var device_login_button: Button = %DeviceLoginButton
@onready var google_button: Button = %GoogleButton
@onready var logout_button: Button = %LogoutButton

@onready var loading_indicator: Label = %LoadingIndicator
@onready var status_label: Label = %StatusLabel

var _is_busy: bool = false

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	if login_button != null:
		login_button.pressed.connect(_on_login_pressed)
	if register_button != null:
		register_button.pressed.connect(_on_register_pressed)
	if device_login_button != null:
		device_login_button.pressed.connect(_on_device_login_pressed)
	if google_button != null:
		google_button.pressed.connect(_on_google_pressed)
	if logout_button != null:
		logout_button.pressed.connect(_on_logout_pressed)

	_connect_nakama_signals()
	_refresh_session_info()

func _connect_nakama_signals() -> void:
	var nm = _get_nakama_manager()
	if nm == null:
		return

	if nm.has_signal("authenticated") and not nm.authenticated.is_connected(_on_authenticated):
		nm.authenticated.connect(_on_authenticated)
	if nm.has_signal("auth_failed") and not nm.auth_failed.is_connected(_on_auth_failed):
		nm.auth_failed.connect(_on_auth_failed)
	if nm.has_signal("connection_status_changed") and not nm.connection_status_changed.is_connected(_on_connection_status_changed):
		nm.connection_status_changed.connect(_on_connection_status_changed)
	if nm.has_signal("logged_out") and not nm.logged_out.is_connected(_on_logged_out):
		nm.logged_out.connect(_on_logged_out)

func open(_args: Dictionary = {}) -> void:
	visible = true
	_refresh_session_info()

func close() -> void:
	closed.emit()
	visible = false
	queue_free()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _get_nakama_manager() -> Node:
	if has_node("/root/NakamaManager"):
		return get_node("/root/NakamaManager")
	return null

func _refresh_session_info() -> void:
	var nm = _get_nakama_manager()
	if nm != null:
		if nm.has_method("get_device_id") and device_id_label != null:
			device_id_label.text = str(nm.get_device_id())

		var is_auth: bool = nm.has_method("is_authenticated") and nm.is_authenticated()
		if is_auth:
			if status_value_label != null:
				status_value_label.text = "● Connected (Online)"
				status_value_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))
			if user_id_label != null:
				user_id_label.text = nm.get_user_id() if nm.has_method("get_user_id") else "Unknown"
			if username_label != null:
				var uname = nm.get_username() if nm.has_method("get_username") else "Founder"
				username_label.text = uname if not uname.is_empty() else "Anonymous Founder"
		else:
			if status_value_label != null:
				status_value_label.text = "○ Offline / Not Logged In"
				status_value_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
			if user_id_label != null:
				user_id_label.text = "None"
			if username_label != null:
				username_label.text = "Guest"
	else:
		if status_value_label != null:
			status_value_label.text = "○ Offline (Local Solo Mode)"
			status_value_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
		if user_id_label != null:
			user_id_label.text = "Local"
		if username_label != null:
			username_label.text = "Offline Player"
		if device_id_label != null:
			device_id_label.text = OS.get_unique_id()

func _set_busy(busy: bool, message: String = "") -> void:
	_is_busy = busy
	if loading_indicator != null:
		loading_indicator.visible = busy
		loading_indicator.text = message
	if login_button != null:
		login_button.disabled = busy
	if register_button != null:
		register_button.disabled = busy
	if device_login_button != null:
		device_login_button.disabled = busy
	if google_button != null:
		google_button.disabled = busy
	if logout_button != null:
		logout_button.disabled = busy

func _show_feedback(message: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = message
		status_label.visible = not message.is_empty()
		if is_error:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))

func _on_login_pressed() -> void:
	if _is_busy:
		return
	var email: String = email_input.text.strip_edges() if email_input != null else ""
	var password: String = password_input.text.strip_edges() if password_input != null else ""

	if email.is_empty() or password.is_empty():
		_show_feedback("Email and password cannot be empty.", true)
		return

	var nm = _get_nakama_manager()
	if nm == null:
		_show_feedback("Offline: Nakama server unavailable.", true)
		return

	_set_busy(true, "Authenticating with Email...")
	_show_feedback("")
	var session = await nm.login_email_async(email, password, false)
	_set_busy(false)
	if session != null and not session.is_exception():
		_show_feedback("Logged in successfully as %s!" % session.username, false)
		_refresh_session_info()
	else:
		_show_feedback("Login failed: %s" % (nm.last_error if nm.last_error != "" else "Invalid credentials"), true)

func _on_register_pressed() -> void:
	if _is_busy:
		return
	var email: String = email_input.text.strip_edges() if email_input != null else ""
	var password: String = password_input.text.strip_edges() if password_input != null else ""
	var uname: String = username_input.text.strip_edges() if username_input != null else ""

	if email.is_empty() or password.is_empty():
		_show_feedback("Email and password cannot be empty.", true)
		return

	if password.length() < 8:
		_show_feedback("Password must be at least 8 characters.", true)
		return

	var nm = _get_nakama_manager()
	if nm == null:
		_show_feedback("Offline: Nakama server unavailable.", true)
		return

	_set_busy(true, "Creating Nakama Account...")
	_show_feedback("")
	var session = await nm.register_email_async(email, password, uname)
	_set_busy(false)
	if session != null and not session.is_exception():
		_show_feedback("Account created and signed in!", false)
		_refresh_session_info()
	else:
		_show_feedback("Registration failed: %s" % (nm.last_error if nm.last_error != "" else "Could not register"), true)

func _on_device_login_pressed() -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm == null:
		_show_feedback("Offline: Nakama server unavailable.", true)
		return

	_set_busy(true, "Authenticating with Device-ID...")
	_show_feedback("")
	var session = await nm.login_device_async()
	_set_busy(false)
	if session != null and not session.is_exception():
		_show_feedback("Device session authenticated!", false)
		_refresh_session_info()
	else:
		_show_feedback("Device login failed: %s" % nm.last_error, true)

func _on_google_pressed() -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm != null and nm.has_method("login_google_stub_async"):
		var res: Dictionary = await nm.login_google_stub_async()
		_show_feedback(res.get("message", "Google OAuth is a placeholder stub."), false)
	else:
		_show_feedback("Google Account OAuth is currently a placeholder stub.", false)

func _on_logout_pressed() -> void:
	var nm = _get_nakama_manager()
	if nm != null and nm.has_method("logout"):
		nm.logout()
	_refresh_session_info()
	_show_feedback("Session logged out.", false)

func _on_authenticated(_session) -> void:
	_refresh_session_info()

func _on_auth_failed(err_msg: String) -> void:
	_show_feedback("Auth error: %s" % err_msg, true)
	_refresh_session_info()

func _on_connection_status_changed(_is_online: bool, _status_text: String) -> void:
	_refresh_session_info()

func _on_logged_out() -> void:
	_refresh_session_info()
