class_name ServerRoom
extends RefCounted
## Một phòng chơi trên server.
##  - Phòng chờ: chỗ ngồi (người thật / máy), chủ phòng, tuỳ chọn ván.
##  - Trong ván (lockstep): server giữ engine "chuẩn", kiểm tra từng nước đi, đánh số và phát cho mọi máy.
##    Server cũng là đồng hồ: chờ các máy diễn xong mới tính giờ, cho bot suy nghĩ, xử lý hết giờ / vắng mặt.

const MAX_SEATS := 6
const MIN_SEATS := 2
## Giờ suy nghĩ mặc định (giây); đấu giá ngắn hơn.
const THINK_TIME := 30.0
const AUCTION_TIME := 12.0
## Người đang rớt mạng: chờ ngắn để ván không bị treo.
const OFFLINE_TIME := 5.0
## Số lần hết giờ liên tiếp thì bị xử thua.
const MAX_STRIKES := 3
## Chờ các máy diễn hoạt cảnh tối đa bao lâu trước khi tính giờ / cho bot đi.
const PRESENT_CAP := 20.0
## Bot "suy nghĩ" bao lâu sau khi mọi máy đã sẵn sàng.
const BOT_DELAY := 0.35
## Phòng không còn ai kết nối quá lâu thì xoá.
const EMPTY_TTL := 300.0
const BOT_NAMES := ["Máy · An", "Máy · Bình", "Máy · Chi", "Máy · Dũng", "Máy · Em"]

var code: String
var server  # GameServer (tránh vòng phụ thuộc kiểu)
var seats: Array = []          # [{name, character, is_bot, difficulty, token, peer, connected, strikes, ready_n}]
var host_seat := 0
var options := {"rounds": 25, "difficulty": 1, "think": THINK_TIME}
var started := false
var engine: GameEngine
var seed := 0
var log: Array = []            # nước đi đã áp dụng (bản ghi gửi cho máy vào lại)
var _phase := "idle"           # idle | present | think | bot
var _phase_t := 0.0
var _think_limit := 0.0
var _empty_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_code: String, p_server) -> void:
	code = p_code
	server = p_server
	_rng.randomize()


# ---------------------------------------------------------------- chỗ ngồi

func seat_of_peer(peer_id: int) -> int:
	for i in seats.size():
		if seats[i]["peer"] == peer_id:
			return i
	return -1


func seat_of_token(token: String) -> int:
	for i in seats.size():
		if not seats[i]["is_bot"] and seats[i]["token"] == token:
			return i
	return -1


func humans_connected() -> int:
	var n := 0
	for s in seats:
		if not s["is_bot"] and s["connected"]:
			n += 1
	return n


func _free_character(want: String) -> String:
	var used := {}
	for s in seats:
		used[s["character"]] = true
	if want != "" and not used.has(want):
		return want
	for c in CardsData.CHARACTERS:
		if not used.has(c["id"]):
			return c["id"]
	return want


## Thêm người thật vào phòng chờ. Trả về số ghế, hoặc -1 nếu đầy.
func add_human(peer_id: int, token: String, name: String, character: String) -> int:
	if seats.size() >= MAX_SEATS:
		return -1
	seats.append({"name": _unique_name(name), "character": _free_character(character), "is_bot": false, "difficulty": 1,
		"token": token, "peer": peer_id, "connected": true, "strikes": 0, "ready_n": -1})
	return seats.size() - 1


func add_bot() -> bool:
	if seats.size() >= MAX_SEATS:
		return false
	var used := {}
	for s in seats:
		used[s["name"]] = true
	var name := "Máy"
	for n in BOT_NAMES:
		if not used.has(n):
			name = n
			break
	seats.append({"name": name, "character": _free_character(""), "is_bot": true, "difficulty": int(options["difficulty"]),
		"token": "", "peer": 0, "connected": true, "strikes": 0, "ready_n": -1})
	return true


func remove_seat(i: int) -> void:
	if i < 0 or i >= seats.size():
		return
	seats.remove_at(i)
	if host_seat == i or host_seat >= seats.size():
		host_seat = 0
		for k in seats.size():
			if not seats[k]["is_bot"]:
				host_seat = k
				break
	elif host_seat > i:
		host_seat -= 1


func _unique_name(name: String) -> String:
	name = name.strip_edges().left(18)
	if name == "":
		name = "Người chơi"
	var base := name
	var k := 2
	var taken := true
	while taken:
		taken = false
		for s in seats:
			if s["name"] == name:
				taken = true
				name = "%s %d" % [base, k]
				k += 1
				break
	return name


func set_character(seat: int, ch: String) -> bool:
	for i in seats.size():
		if i != seat and seats[i]["character"] == ch:
			return false
	var ok := false
	for c in CardsData.CHARACTERS:
		if c["id"] == ch:
			ok = true
	if ok:
		seats[seat]["character"] = ch
	return ok


func set_options(o: Dictionary) -> void:
	if o.has("rounds"):
		options["rounds"] = clampi(int(o["rounds"]), 5, 60)
	if o.has("difficulty"):
		options["difficulty"] = clampi(int(o["difficulty"]), 0, 2)
		for s in seats:
			if s["is_bot"]:
				s["difficulty"] = options["difficulty"]
	if o.has("think"):
		options["think"] = clampf(float(o["think"]), 3.0, 120.0)


func room_state() -> Dictionary:
	var list: Array = []
	for s in seats:
		list.append({"name": s["name"], "character": s["character"], "is_bot": s["is_bot"], "connected": s["connected"]})
	return {"t": "room", "code": code, "host": host_seat, "seats": list, "options": options, "started": started}


# ---------------------------------------------------------------- ván chơi

func start_game() -> String:
	if started:
		return "Ván đã bắt đầu."
	if seats.size() < MIN_SEATS:
		return "Cần ít nhất %d người chơi (có thể thêm máy)." % MIN_SEATS
	started = true
	seed = _rng.randi_range(1, 2147483646)
	engine = GameEngine.new()
	engine.setup(configs(), seed, int(options["rounds"]))
	log.clear()
	for s in seats:
		s["ready_n"] = -1
		s["strikes"] = 0
	_enter_present()
	for i in seats.size():
		if not seats[i]["is_bot"] and seats[i]["connected"]:
			server.send(seats[i]["peer"], start_message(i))
	return ""


func configs() -> Array:
	var cfg: Array = []
	for s in seats:
		cfg.append({"name": s["name"], "character": s["character"], "is_bot": s["is_bot"], "difficulty": s["difficulty"]})
	return cfg


## Gói tin bắt đầu ván (kèm toàn bộ nước đã đi, dùng được cho cả lúc vào lại giữa ván).
func start_message(seat: int) -> Dictionary:
	return {"t": "start", "seed": seed, "configs": configs(), "rounds": options["rounds"], "seat": seat,
		"think": options["think"], "log": log, "hash": engine.state_hash() if engine else ""}


## Người chơi gửi nước đi. Trả về "" nếu hợp lệ, ngược lại là lý do từ chối.
func submit(seat: int, action: Dictionary) -> String:
	if not started or engine == null or engine.game_over:
		return "Ván chưa bắt đầu hoặc đã kết thúc."
	if engine.pending.is_empty() or int(engine.pending["p"]) != seat:
		return "Chưa tới lượt bạn."
	if NetUtil.is_server_only(action):
		return "Hành động không hợp lệ."
	if not _apply_act(seat, action):
		return "Nước đi không hợp lệ."
	seats[seat]["strikes"] = 0
	return ""


func _apply_act(seat: int, action: Dictionary) -> bool:
	var before := engine.state_hash()
	engine.act(seat, action)
	var after := engine.state_hash()
	if after == before:
		return false
	_record({"k": "act", "p": seat, "a": action}, after)
	return true


func _record(entry: Dictionary, h: String) -> void:
	log.append(entry)
	var msg := entry.duplicate()
	msg["t"] = "move"
	msg["n"] = log.size()
	msg["h"] = h
	broadcast(msg)
	_enter_present()


func mark_ready(seat: int, n: int) -> void:
	if seat >= 0 and seat < seats.size():
		seats[seat]["ready_n"] = maxi(int(seats[seat]["ready_n"]), n)


## Gửi trạng thái phòng cho từng người, kèm "you" = ghế của chính họ.
func broadcast_room() -> void:
	for i in seats.size():
		var st: Dictionary = seats[i]
		if not st["is_bot"] and st["connected"]:
			server.send(st["peer"], room_state_for(i))


func room_state_for(seat: int) -> Dictionary:
	var rs := room_state()
	rs["you"] = seat
	return rs


func broadcast(msg: Dictionary) -> void:
	for s in seats:
		if not s["is_bot"] and s["connected"]:
			server.send(s["peer"], msg)


func _enter_present() -> void:
	_phase = "present"
	_phase_t = 0.0


## Gọi mỗi khung hình từ server.
func tick(delta: float) -> void:
	if humans_connected() == 0:
		_empty_t += delta
	else:
		_empty_t = 0.0
	if not started or engine == null or engine.game_over or engine.pending.is_empty():
		return
	_phase_t += delta
	var pend := engine.pending
	var pid: int = pend["p"]
	match _phase:
		"present":
			if _all_ready() or _phase_t >= PRESENT_CAP:
				if seats[pid]["is_bot"]:
					_phase = "bot"
					_phase_t = 0.0
				else:
					_start_think(pid, pend)
		"bot":
			if _phase_t >= BOT_DELAY:
				var a: Dictionary
				if String(pend["type"]) == "auction_bid":
					a = AuctionRules.ai_decide(engine, pend)
				else:
					a = BotAI.decide(engine, pend)
				if not _apply_act(pid, a):
					_apply_act(pid, GameEngine.timeout_action(pend))
		"think":
			if _phase_t >= _think_limit:
				_on_timeout(pid, pend)


func _all_ready() -> bool:
	for s in seats:
		if not s["is_bot"] and s["connected"] and int(s["ready_n"]) < log.size():
			return false
	return true


func _start_think(pid: int, pend: Dictionary) -> void:
	_phase = "think"
	_phase_t = 0.0
	if not seats[pid]["connected"]:
		_think_limit = OFFLINE_TIME
	elif String(pend["type"]) == "auction_bid":
		_think_limit = AUCTION_TIME
	else:
		_think_limit = float(options["think"])
	broadcast({"t": "timer", "p": pid, "secs": _think_limit, "n": log.size()})


func _on_timeout(pid: int, pend: Dictionary) -> void:
	var s: Dictionary = seats[pid]
	s["strikes"] = int(s["strikes"]) + 1
	if int(s["strikes"]) >= MAX_STRIKES and engine.alive_players().size() > 1:
		engine.forfeit(pid)
		broadcast({"t": "notice", "text": "%s vắng mặt %d lượt liên tiếp — bị loại." % [s["name"], MAX_STRIKES]})
		_record({"k": "forfeit", "p": pid}, engine.state_hash())
		return
	broadcast({"t": "notice", "text": "%s hết giờ (%d/%d)." % [s["name"], s["strikes"], MAX_STRIKES]})
	_apply_act(pid, GameEngine.timeout_action(pend))


# ---------------------------------------------------------------- kết nối

func on_disconnect(seat: int) -> void:
	if seat < 0:
		return
	if not started:
		remove_seat(seat)
		return
	seats[seat]["connected"] = false
	seats[seat]["peer"] = 0
	broadcast({"t": "presence", "seat": seat, "connected": false})


func on_rejoin(seat: int, peer_id: int) -> void:
	seats[seat]["connected"] = true
	seats[seat]["peer"] = peer_id
	seats[seat]["ready_n"] = -1
	seats[seat]["strikes"] = 0
	broadcast({"t": "presence", "seat": seat, "connected": true})


## Đồng hồ đang chạy (gửi cho máy vừa vào lại), rỗng nếu không có.
func current_timer() -> Dictionary:
	if _phase != "think" or engine == null or engine.pending.is_empty():
		return {}
	return {"t": "timer", "p": int(engine.pending["p"]), "secs": maxf(_think_limit - _phase_t, 0.0), "n": log.size()}


func is_dead() -> bool:
	if seats.is_empty():
		return true
	var has_human := false
	for s in seats:
		if not s["is_bot"]:
			has_human = true
	return not has_human or _empty_t >= EMPTY_TTL
