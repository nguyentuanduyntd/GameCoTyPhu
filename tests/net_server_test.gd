extends SceneTree
## Kiểm thử tích hợp online: 1 server + 3 client thật (WebSocket qua localhost) trong cùng tiến trình.
##  - A tạo phòng, B và C vào bằng mã, A thêm 1 máy, chỉnh giờ suy nghĩ ngắn, bắt đầu ván 3 vòng.
##  - Mỗi client tự chạy engine (lockstep) và so mã trạng thái với server sau từng nước.
##  - B bỏ mặc 3 lần đầu tới lượt → phải bị xử thua. C rớt mạng giữa ván rồi vào lại bằng mã phòng.
## Chạy: godot --headless --path . --script res://tests/net_server_test.gd

const PORT := 8931

var server: GameServer
var bots := {}        # tên client -> trạng thái
var fails: Array = []


class TestClient:
	var name: String
	var net: NetClient
	var e: GameEngine
	var seat := -1
	var applied := 0
	var idle_left := 0       # số lần tới lượt mà cố tình không bấm
	var moves_seen := 0
	var rejoined := false


func _initialize() -> void:
	server = GameServer.new()
	root.add_child(server)
	if not server.start(PORT):
		print("NET_SERVER_TEST FAIL không mở cổng")
		quit(1)
		return
	var a := _client("A", "tok-a", 0)
	var b := _client("B", "tok-b", 3)
	var c := _client("C", "tok-c", 0)
	await _wait(func(): return a.net.is_online() and b.net.is_online() and c.net.is_online(), 5.0)
	a.net.create_room({"rounds": 3, "difficulty": 1, "think": 1.0})
	await _wait(func(): return a.net.room.has("code"), 3.0)
	var code: String = a.net.room["code"]
	print("phòng: ", code)
	b.net.join_room(code)
	c.net.join_room(code)
	await _wait(func(): return (a.net.room.get("seats", []) as Array).size() == 3, 3.0)
	a.net.send({"t": "add_bot"})
	c.net.send({"t": "set_character", "character": "nghe_si"})
	await _wait(func(): return (a.net.room.get("seats", []) as Array).size() == 4, 3.0)
	a.net.send({"t": "start_game"})
	var t0 := Time.get_ticks_msec()
	var dropped := false
	while Time.get_ticks_msec() - t0 < 180000:
		await process_frame
		var r: ServerRoom = server._rooms.get(code)
		if r == null:
			fails.append("phòng biến mất")
			break
		# C rớt mạng ở khoảng nước 15, vào lại sau 1.5 giây
		if not dropped and c.applied >= 15:
			dropped = true
			c.net.close()
			c.e = null
			c.applied = 0
			_reconnect_later(c, code)
		if r.engine and r.engine.game_over and _synced(r, [a, b, c]):
			break
	var r2: ServerRoom = server._rooms.get(code)
	var ok := r2 != null and r2.engine != null and r2.engine.game_over
	if not ok:
		fails.append("ván chưa kết thúc")
	if r2 and r2.engine:
		if r2.engine.players[1]["alive"]:
			fails.append("B không bị xử thua dù vắng 3 lần")
		for tc in [a, b, c]:
			if tc.e and tc.e.state_hash() != r2.engine.state_hash():
				fails.append("%s lệch trạng thái cuối" % tc.name)
	if not c.rejoined:
		fails.append("C không vào lại được")
	print("NET_SERVER_TEST moves=%d game_over=%s winner=%s fails=%s" % [r2.log.size() if r2 else -1, ok, r2.engine.winner if (r2 and r2.engine) else -1, fails])
	server.stop()
	quit(1 if fails.size() > 0 else 0)


func _synced(r: ServerRoom, list: Array) -> bool:
	for tc in list:
		if tc.e == null or tc.applied < r.log.size():
			return false
	return true


func _client(n: String, tok: String, idle: int) -> TestClient:
	var tc := TestClient.new()
	tc.name = n
	tc.idle_left = idle
	tc.net = NetClient.new()
	tc.net.player_name = "Khách " + n
	tc.net.token = tok
	root.add_child(tc.net)
	tc.net.game_started.connect(func(info): _on_start(tc, info))
	tc.net.move_received.connect(func(m): _on_move(tc, m))
	tc.net.timer_started.connect(func(pid, secs): _on_timer(tc, pid))
	tc.net.error_received.connect(func(t): print("[%s] lỗi: %s" % [n, t]))
	tc.net.connect_to("ws://127.0.0.1:%d" % PORT)
	return tc


func _reconnect_later(tc: TestClient, code: String) -> void:
	await create_timer(1.5).timeout
	tc.net.connect_to("ws://127.0.0.1:%d" % PORT)
	tc.net.join_room(code)
	tc.rejoined = true


func _on_start(tc: TestClient, info: Dictionary) -> void:
	tc.seat = info["seat"]
	tc.e = GameEngine.new()
	tc.e.setup(info["configs"], info["seed"], info["rounds"])
	tc.applied = 0
	for entry in info["log"]:
		_apply(tc, entry)
	if info["hash"] != "" and tc.e.state_hash() != info["hash"]:
		fails.append("%s lệch sau khi tải lại ván" % tc.name)
	tc.net.send_ready(tc.applied)


func _on_move(tc: TestClient, m: Dictionary) -> void:
	if tc.e == null:
		return
	if int(m["n"]) != tc.applied + 1:
		fails.append("%s nhận sai thứ tự nước %d (đang ở %d)" % [tc.name, m["n"], tc.applied])
		return
	_apply(tc, m)
	if tc.e.state_hash() != m["h"]:
		fails.append("%s LỆCH ở nước %d" % [tc.name, m["n"]])
	tc.net.send_ready(tc.applied)


func _apply(tc: TestClient, entry: Dictionary) -> void:
	if entry["k"] == "forfeit":
		tc.e.forfeit(entry["p"])
	else:
		tc.e.act(entry["p"], entry["a"])
	tc.applied += 1


func _on_timer(tc: TestClient, pid: int) -> void:
	if pid != tc.seat or tc.e == null:
		return
	if tc.idle_left > 0:
		tc.idle_left -= 1
		return
	var pend := tc.e.pending
	await create_timer(0.05).timeout
	if tc.e == null or tc.e.pending != pend:
		return
	var a: Dictionary = AuctionRules.ai_decide(tc.e, pend) if String(pend["type"]) == "auction_bid" else BotAI.decide(tc.e, pend)
	tc.net.send_action(a)


func _wait(cond: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame
