extends Node
class_name NakamaSocket

## Real-time WebSocket connection manager for matches, presence, chat, and RPCs.

signal connected()
signal closed()
signal error(message: String)
signal received_channel_message(message: Dictionary)
signal received_channel_presence(presence: Dictionary)
signal received_match_state(match_state: Dictionary)
signal received_match_presence(presence: Dictionary)
signal received_notification(notification: Dictionary)

var adapter: NakamaWebSocketAdapter = null
var logger: NakamaLogger = null
var host: String = "127.0.0.1"
var port: int = 7350
var scheme: String = "ws"
var session: NakamaSession = null

var _cids: Dictionary = {}
var _cid_counter: int = 1

func _init(p_host: String = "127.0.0.1", p_port: int = 7350, p_scheme: String = "ws") -> void:
	host = p_host
	port = p_port
	scheme = p_scheme
	logger = NakamaLogger.new(NakamaLogger.LogLevel.INFO, "[NakamaSocket]")

func _ready() -> void:
	adapter = NakamaWebSocketAdapter.new()
	add_child(adapter)
	adapter.connected.connect(_on_adapter_connected)
	adapter.closed.connect(_on_adapter_closed)
	adapter.message_received.connect(_on_adapter_message_received)
	adapter.connection_error.connect(_on_adapter_error)

func connect_socket_async(
	p_session: NakamaSession,
	p_appear_online: bool = false,
	_p_connect_timeout: int = 3
) -> NakamaAsyncResult:
	if p_session == null or p_session.is_exception():
		return NakamaAsyncResult.new(NakamaException.new("Invalid or expired session", 401))

	session = p_session
	var ws_scheme = "wss" if scheme == "https" or scheme == "wss" else "ws"
	var url = "%s://%s:%d/ws?token=%s&status=%s" % [
		ws_scheme,
		host,
		port,
		p_session.token,
		str(p_appear_online).to_lower()
	]

	if adapter == null:
		adapter = NakamaWebSocketAdapter.new()
		add_child(adapter)
		adapter.connected.connect(_on_adapter_connected)
		adapter.closed.connect(_on_adapter_closed)
		adapter.message_received.connect(_on_adapter_message_received)
		adapter.connection_error.connect(_on_adapter_error)

	var err = adapter.connect_to_url(url)
	if err != OK:
		return NakamaAsyncResult.new(NakamaException.new("Failed to connect WebSocket: %d" % err, -1))

	return NakamaAsyncResult.new()

func close() -> void:
	if adapter != null:
		adapter.close()

func send_async(p_msg: NakamaRTMessage) -> NakamaRTMessage:
	var cid = str(_cid_counter)
	_cid_counter += 1
	p_msg.cid = cid
	var json_str = NakamaSerializer.json_stringify(p_msg.to_dict())
	if adapter != null:
		var err = adapter.send_text(json_str)
		if err != OK:
			logger.error("Failed to send socket message: %d" % err)
	return p_msg

func _on_adapter_connected() -> void:
	logger.info("WebSocket connected successfully")
	connected.emit()

func _on_adapter_closed(_clean: bool, code: int, reason: String) -> void:
	logger.info("WebSocket closed (code: %d, reason: '%s')" % [code, reason])
	closed.emit()

func _on_adapter_error(p_msg: String) -> void:
	logger.error("WebSocket error: %s" % p_msg)
	error.emit(p_msg)

func _on_adapter_message_received(p_text: String) -> void:
	var parsed = NakamaSerializer.json_parse(p_text)
	if not (parsed is Dictionary):
		return

	if parsed.has("channel_message"):
		received_channel_message.emit(parsed["channel_message"])
	elif parsed.has("notifications"):
		received_notification.emit(parsed["notifications"])
	elif parsed.has("match_data"):
		received_match_state.emit(parsed["match_data"])
	elif parsed.has("match_presence_event"):
		received_match_presence.emit(parsed["match_presence_event"])
