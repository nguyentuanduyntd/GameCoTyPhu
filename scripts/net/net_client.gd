class_name NetClient
extends Node
## Kết nối tới server online (WebSocket). Dùng làm autoload "Net" trong game,
## và dùng trực tiếp trong kiểm thử (nhiều client trong một tiến trình).
## Gửi/nhận JSON; tự gửi ping giữ kết nối (tunnel thường cắt kết nối im lặng quá lâu).

signal connected
signal disconnected
signal message(msg: Dictionary)
signal room_updated(room: Dictionary)
signal game_started(info: Dictionary)
signal move_received(entry: Dictionary)
signal timer_started(pid: int, secs: float)
signal notice(text: String)
signal error_received(text: String)

const PING_EVERY := 20.0

var url := ""
var player_name := "Bạn"
var character := ""
var token := ""
var room: Dictionary = {}
var start_info: Dictionary = {}
var _ws: WebSocketPeer
var _state := WebSocketPeer.STATE_CLOSED
var _welcomed := false
var _ping_t := 0.0
var _pending_out: Array = []


func is_online() -> bool:
	return _ws != null and _state == WebSocketPeer.STATE_OPEN and _welcomed


func connect_to(p_url: String) -> Error:
	close()
	url = p_url.strip_edges()
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "ws://" + url
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = GameServer.MAX_PACKET
	_ws.outbound_buffer_size = 1 << 16
	_ws.max_queued_packets = 4096
	_welcomed = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
	_state = WebSocketPeer.STATE_CONNECTING
	return err


func close() -> void:
	if _ws:
		_ws.close()
	_ws = null
	_state = WebSocketPeer.STATE_CLOSED
	_welcomed = false
	room = {}


func send(msg: Dictionary) -> void:
	if _ws and _state == WebSocketPeer.STATE_OPEN and (_welcomed or msg.get("t") == "hello"):
		_ws.send_text(NetUtil.encode(msg))
	else:
		_pending_out.append(msg)


func create_room(options: Dictionary) -> void:
	send({"t": "create_room", "options": options})


func join_room(code: String) -> void:
	send({"t": "join_room", "code": code})


func leave_room() -> void:
	send({"t": "leave_room"})
	room = {}


func send_action(a: Dictionary) -> void:
	send({"t": "action", "a": a})


func send_ready(n: int) -> void:
	send({"t": "ready", "n": n})


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st != _state:
		_state = st
		if st == WebSocketPeer.STATE_OPEN:
			_ws.send_text(NetUtil.encode({"t": "hello", "v": NetUtil.PROTOCOL, "name": player_name, "character": character, "token": token}))
		elif st == WebSocketPeer.STATE_CLOSED:
			_ws = null
			_welcomed = false
			disconnected.emit()
			return
	if st != WebSocketPeer.STATE_OPEN:
		return
	while _ws and _ws.get_available_packet_count() > 0:
		var msg := NetUtil.decode(_ws.get_packet().get_string_from_utf8())
		if not msg.is_empty():
			_dispatch(msg)
	_ping_t += delta
	if _ping_t >= PING_EVERY and _welcomed:
		_ping_t = 0.0
		send({"t": "ping"})


func _dispatch(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"welcome":
			_welcomed = true
			var out := _pending_out
			_pending_out = []
			for m in out:
				send(m)
			connected.emit()
		"room":
			room = msg
			room_updated.emit(msg)
		"start":
			start_info = msg
			game_started.emit(msg)
		"move":
			move_received.emit(msg)
		"timer":
			timer_started.emit(int(msg["p"]), float(msg["secs"]))
		"notice":
			notice.emit(String(msg["text"]))
		"error", "reject":
			error_received.emit(String(msg.get("text", "")))
		"left":
			room = {}
			room_updated.emit({})
	message.emit(msg)
