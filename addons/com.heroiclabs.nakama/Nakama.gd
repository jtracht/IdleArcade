@tool
extends Node

## Nakama Godot Client Singleton and Factory.
## Exposes methods to create REST clients and real-time sockets.

const DEFAULT_SERVER_KEY: String = "defaultkey"
const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 7350
const DEFAULT_SCHEME: String = "http"
const DEFAULT_TIMEOUT: float = 10.0

var logger: NakamaLogger

func _init() -> void:
	logger = NakamaLogger.new(NakamaLogger.LogLevel.INFO, "[Nakama]")

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass

## Factory method to create and configure a NakamaClient instance.
func create_client(
	p_server_key: String = DEFAULT_SERVER_KEY,
	p_host: String = DEFAULT_HOST,
	p_port: int = DEFAULT_PORT,
	p_scheme: String = DEFAULT_SCHEME,
	p_timeout: float = DEFAULT_TIMEOUT,
	p_log_level: int = NakamaLogger.LogLevel.INFO
) -> NakamaClient:
	var client = NakamaClient.new(p_server_key, p_host, p_port, p_scheme, p_timeout, p_log_level)
	add_child(client)
	return client

## Factory method to create and configure a NakamaSocket instance from a client.
func create_socket_from(p_client: NakamaClient) -> NakamaSocket:
	var ws_scheme = "wss" if p_client.scheme == "https" else "ws"
	var socket = NakamaSocket.new(p_client.host, p_client.port, ws_scheme)
	add_child(socket)
	return socket
