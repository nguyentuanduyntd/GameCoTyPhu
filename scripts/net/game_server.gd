class_name GameServer
extends Node
## Server online: chạy chính project Godot ở chế độ không màn hình.
##   godot --headless --path . -- --server [--port=8910]
## Nghe WebSocket (ws://), mỗi tin nhắn là một JSON {"t": loại, ...}. Ra Internet qua tunnel miễn phí:
##   cloudflared tunnel --url http://localhost:8910   → gửi bạn bè địa chỉ wss://xxxx.trycloudflare.com
##
## Client → server: hello, create_room, join_room, leave_room, set_character, add_bot, remove_bot,
##                  set_options, start_game, action, ready, ping
## Server → client: welcome, room, start, move, timer, presence, notice, reject, error, left, pong

signal log_line(text: String)

const MAX_PACKET := 1 << 20

var port := NetUtil.DEFAULT_PORT
var _tcp := TCPServer.new()
var _peers := {}        # peer_id -> {ws, name, character, token, room, hello}
var _rooms := {}        # code -> ServerRoom
var _next_peer := 1
var _rng := RandomNumberGenerator.new()
var _running := false


func _ready() -> void:
	_rng.randomize()


func start(p_port: int = NetUtil.DEFAULT_PORT) -> bool:
	port = p_port
	var err := _tcp.listen(port, "*")
	if err != OK:
		_log("Không mở được cổng %d (lỗi %d)." % [port, err])
		return false
	_running = true
	_log("Server Tỷ Phú Đất Việt đang chạy ở cổng %d (giao thức v%d)." % [port, NetUtil.PROTOCOL])
	return true


func stop() -> void:
	for id in _peers.keys():
		(_peers[id]["ws"] as WebSocketPeer).close()
	_peers.clear()
	_tcp.stop()
	_running = false


func room_count() -> int:
	return _rooms.size()


func _log(text: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), text]
	print(line)
	log_line.emit(line)


func _process(delta: float) -> void:
	if not _running:
		return
	while _tcp.is_connection_available():
		var conn := _tcp.take_connection()
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = MAX_PACKET
		ws.outbound_buffer_size = MAX_PACKET
		ws.max_queued_packets = 4096
		if ws.accept_stream(conn) == OK:
			var id := _next_peer
			_next_peer += 1
			_peers[id] = {"ws": ws, "name": "", "character": "", "token": "", "room": "", "hello": false}
	for id in _peers.keys():
		var ws: WebSocketPeer = _peers[id]["ws"]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var text := ws.get_packet().get_string_from_utf8()
				var msg := NetUtil.decode(text)
				if not msg.is_empty():
					_handle(id, msg)
		elif st == WebSocketPeer.STATE_CLOSED:
			_drop(id)
	for c in _rooms.keys():
		var r: ServerRoom = _rooms[c]
		r.tick(delta)
		if r.is_dead():
			_log("Xoá phòng %s." % c)
			_rooms.erase(c)


func send(peer_id: int, msg: Dictionary) -> void:
	if not _peers.has(peer_id):
		return
	var ws: WebSocketPeer = _peers[peer_id]["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(NetUtil.encode(msg))


func _error(peer_id: int, text: String) -> void:
	send(peer_id, {"t": "error", "text": text})


func _drop(id: int) -> void:
	var info: Dictionary = _peers[id]
	_peers.erase(id)
	var code: String = info["room"]
	if code != "" and _rooms.has(code):
		var r: ServerRoom = _rooms[code]
		var seat := r.seat_of_peer(id)
		r.on_disconnect(seat)
		if not r.started:
			r.broadcast_room()
		_log("%s rời kết nối (phòng %s)." % [info["name"], code])


func _room_of(id: int) -> ServerRoom:
	var code: String = _peers[id]["room"]
	return _rooms.get(code)


func _handle(id: int, msg: Dictionary) -> void:
	var t := String(msg.get("t", ""))
	var info: Dictionary = _peers[id]
	if t == "ping":
		send(id, {"t": "pong"})
		return
	if t == "hello":
		if int(msg.get("v", 0)) != NetUtil.PROTOCOL:
			_error(id, "Phiên bản game khác server (server v%d). Hãy cập nhật game." % NetUtil.PROTOCOL)
			return
		info["name"] = String(msg.get("name", "Người chơi")).left(18)
		info["character"] = String(msg.get("character", ""))
		info["token"] = String(msg.get("token", "")).left(64)
		info["hello"] = true
		send(id, {"t": "welcome", "v": NetUtil.PROTOCOL})
		return
	if not info["hello"]:
		_error(id, "Chưa chào server.")
		return
	var room := _room_of(id)
	match t:
		"create_room":
			if room:
				_leave(id)
			var code := NetUtil.make_code(_rng)
			while _rooms.has(code):
				code = NetUtil.make_code(_rng)
			var r := ServerRoom.new(code, self)
			r.set_options(msg.get("options", {}))
			_rooms[code] = r
			r.add_human(id, info["token"], info["name"], info["character"])
			r.host_seat = 0
			info["room"] = code
			_log("%s tạo phòng %s." % [info["name"], code])
			r.broadcast_room()
		"join_room":
			var code := String(msg.get("code", "")).strip_edges().to_upper()
			if not _rooms.has(code):
				_error(id, "Không tìm thấy phòng %s." % code)
				return
			if room and room.code != code:
				_leave(id)
			var r: ServerRoom = _rooms[code]
			var seat := r.seat_of_token(info["token"]) if info["token"] != "" else -1
			if r.started:
				if seat < 0:
					_error(id, "Phòng %s đã vào ván." % code)
					return
				# vào lại giữa ván: nhận lại chỗ cũ, gửi toàn bộ nước đã đi
				var old_peer: int = r.seats[seat]["peer"]
				if old_peer != 0 and old_peer != id and _peers.has(old_peer):
					_peers[old_peer]["room"] = ""
					(_peers[old_peer]["ws"] as WebSocketPeer).close()
				info["room"] = code
				r.on_rejoin(seat, id)
				send(id, r.room_state_for(seat))
				send(id, r.start_message(seat))
				var tm := r.current_timer()
				if not tm.is_empty():
					send(id, tm)
				_log("%s vào lại phòng %s." % [info["name"], code])
				return
			if seat >= 0:
				r.seats[seat]["peer"] = id
				r.seats[seat]["connected"] = true
			elif r.add_human(id, info["token"], info["name"], info["character"]) < 0:
				_error(id, "Phòng %s đã đủ %d người." % [code, ServerRoom.MAX_SEATS])
				return
			info["room"] = code
			_log("%s vào phòng %s." % [info["name"], code])
			r.broadcast_room()
		"leave_room":
			_leave(id)
		"set_character":
			if room and not room.started:
				if not room.set_character(room.seat_of_peer(id), String(msg.get("character", ""))):
					_error(id, "Nhân vật này đã có người chọn.")
				room.broadcast_room()
		"add_bot", "remove_bot", "set_options", "start_game":
			if room == null or room.started:
				return
			if room.seat_of_peer(id) != room.host_seat:
				_error(id, "Chỉ chủ phòng làm được việc này.")
				return
			match t:
				"add_bot":
					if not room.add_bot():
						_error(id, "Phòng đã đủ người.")
				"remove_bot":
					var s := int(msg.get("seat", -1))
					if s >= 0 and s < room.seats.size() and room.seats[s]["is_bot"]:
						room.remove_seat(s)
				"set_options":
					room.set_options(msg.get("options", {}))
				"start_game":
					var err := room.start_game()
					if err != "":
						_error(id, err)
						return
					_log("Phòng %s bắt đầu ván (%d người)." % [room.code, room.seats.size()])
			room.broadcast_room()
		"action":
			if room == null:
				return
			var seat := room.seat_of_peer(id)
			var a: Dictionary = msg.get("a", {})
			var why := room.submit(seat, a)
			if why != "":
				send(id, {"t": "reject", "text": why, "n": room.log.size()})
		"ready":
			if room:
				room.mark_ready(room.seat_of_peer(id), int(msg.get("n", 0)))


func _leave(id: int) -> void:
	var room := _room_of(id)
	_peers[id]["room"] = ""
	send(id, {"t": "left"})
	if room == null:
		return
	var seat := room.seat_of_peer(id)
	if room.started:
		room.on_disconnect(seat)
	else:
		room.remove_seat(seat)
		room.broadcast_room()
