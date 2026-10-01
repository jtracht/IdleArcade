extends Node
class_name NakamaWebSocketAdapter

## WebSocket transport adapter using Godot 4 WebSocketPeer.

signal connected()
signal closed(clean: bool, code: int, reason: String)
signal message_received(text: String)
signal connection_error(message: String)

var peer: WebSocketPeer = null
var was_connected: bool = false

func _init() -> void:
	peer = WebSocketPeer.new()

func connect_to_url(p_url: String) -> Error:
	peer = WebSocketPeer.new()
	was_connected = false
	var err = peer.connect_to_url(p_url)
	if err != OK:
		connection_error.emit("Failed to connect to %s (code %d)" % [p_url, err])
	return err

func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	var state = peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not was_connected:
			was_connected = true
			connected.emit()
		while peer.get_available_packet_count() > 0:
			var packet = peer.get_packet()
			var text = packet.get_string_from_utf8()
			message_received.emit(text)
	elif state == WebSocketPeer.STATE_CLOSED:
		if was_connected:
			was_connected = false
			closed.emit(true, peer.get_close_code(), peer.get_close_reason())

func send_text(p_text: String) -> Error:
	if peer == null or peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	return peer.send_text(p_text)

func close(p_code: int = 1000, p_reason: String = "") -> void:
	if peer != null:
		peer.close(p_code, p_reason)
	was_connected = false
