class_name GameEngine
extends RefCounted
## Bộ luật chơi thuần logic — không phụ thuộc đồ họa.
## Dùng chung cho: chơi với máy (offline), bot, và server online sau này.
##
## Cách dùng:
##   var events = engine.setup(configs)        # bắt đầu ván
##   engine.pending                             # quyết định đang chờ: {"type": ..., "p": id, ...}
##   var events = engine.act(player_id, action) # gửi hành động, nhận danh sách sự kiện để diễn hoạt

const START_CASH := 2000
const SALARY := 200
const JAIL_FEE := 100
const TRAIN_FEE := 100
const LOTTERY_BETS := [50, 100, 200]
const LOTTERY_PAYOUT := 5
const SPECIALTY_PRICE := 60
const MAX_SPECIALTIES := 9
const RENT_MULT := [0.2, 0.8, 1.8, 3.2, 5.0]
const BUILD_MULT := [0.0, 0.5, 0.6, 0.8, 1.2]
const INFRA_RENT := [0, 50, 100, 200, 400]
const TAKEOVER_MULT := 1.5
const MAX_LEVEL_ON_BUY := 1
const SEASON_ROUNDS := 2
const MAX_CARDS := 3
const FREE_RENT_THRESHOLD := 150

const SEASON_NAMES := ["Xuân – Tết", "Hạ – Mùa du lịch", "Thu – Mùa gặt", "Đông – Gió mùa"]
const SEASON_DESC := [
	"Qua Km 0 nhận lương ×1,5. Mọi người nhận lì xì 50.",
	"Tỉnh ven biển +50% tiền thuê.",
	"Tây Bắc, Đông Bắc, Miền Tây +50% tiền thuê.",
	"Các tỉnh Miền Bắc −30% tiền thuê.",
]
const LEVEL_NAMES := ["Đất trống", "Nhà cấp 4", "Nhà phố", "Khách sạn", "Danh Thắng"]

var players: Array = []
var owner: Array = []
var level: Array = []
var current: int = 0
var round_num: int = 1
var max_rounds: int = 25
var season: int = 0
var season_event: Dictionary = {}
var festival_tile: int = -1
var pending: Dictionary = {}
var game_over: bool = false
var winner: int = -1
var win_reason: String = ""
var ranking: Array = []
var eliminated: Array = []
var rng := RandomNumberGenerator.new()

var _events: Array = []
var _chance_deck: Array = []
var _bonus_roll: bool = false
var _group_tiles: Array = []


# ---------------------------------------------------------------- khởi tạo

func setup(configs: Array, p_seed: int = 0, p_max_rounds: int = 25) -> Array:
	_events = []
	if p_seed == 0:
		rng.randomize()
	else:
		rng.seed = p_seed
	max_rounds = p_max_rounds
	players.clear()
	for i in configs.size():
		var c: Dictionary = configs[i]
		var ch: String = c.get("character", "tieu_thuong")
		players.append({
			"id": i,
			"name": c.get("name", "Người chơi %d" % (i + 1)),
			"character": ch,
			"is_bot": c.get("is_bot", false),
			"difficulty": c.get("difficulty", 1),
			"cash": START_CASH,
			"pos": 0,
			"alive": true,
			"in_jail": false,
			"jail_tries": 0,
			"doubles": 0,
			"train_pending": false,
			"specialties": [],
			"cards": [],
			"storm_shield": ch == "ngu_dan",
		})
	owner.resize(BoardData.TILE_COUNT)
	owner.fill(-1)
	level.resize(BoardData.TILE_COUNT)
	level.fill(0)
	_group_tiles.clear()
	for g in BoardData.GROUPS.size():
		_group_tiles.append([])
	for t in BoardData.TILE_COUNT:
		if BoardData.is_province(t):
			_group_tiles[BoardData.tile(t)["group"]].append(t)
	_chance_deck.clear()
	current = 0
	round_num = 1
	season = 0
	season_event = {}
	festival_tile = -1
	game_over = false
	winner = -1
	eliminated.clear()
	ranking.clear()
	_log("Ván đấu bắt đầu! %d người chơi, tối đa %d vòng." % [players.size(), max_rounds])
	_push({"t": "round", "n": round_num})
	_push({"t": "season", "season": season, "event": season_event})
	_begin_turn()
	return _events


# ---------------------------------------------------------------- truy vấn

func alive_players() -> Array:
	var res: Array = []
	for p in players:
		if p["alive"]:
			res.append(p["id"])
	return res


func group_tiles(g: int) -> Array:
	return _group_tiles[g]


func group_count(pid: int, g: int) -> int:
	var n := 0
	for t in _group_tiles[g]:
		if owner[t] == pid:
			n += 1
	return n


func owns_group(pid: int, g: int) -> bool:
	return group_count(pid, g) == _group_tiles[g].size()


func infra_count(pid: int) -> int:
	var n := 0
	for t in BoardData.TILE_COUNT:
		if BoardData.tile(t)["type"] == BoardData.T.INFRA and owner[t] == pid:
			n += 1
	return n


func owned_tiles(pid: int) -> Array:
	var res: Array = []
	for t in BoardData.TILE_COUNT:
		if owner[t] == pid:
			res.append(t)
	return res


func base_build_cost(t: int, lvl: int) -> int:
	return _round5(BoardData.tile(t)["price"] * BUILD_MULT[lvl])


func build_cost(pid: int, t: int, lvl: int) -> int:
	var c := float(base_build_cost(t, lvl))
	if players[pid]["character"] == "tho_ho":
		c *= 0.85
	return _round5(c)


## Tổng giá trị đã đầu tư vào ô (đất + nhà), tính theo giá gốc.
func invested(t: int) -> int:
	var v: int = BoardData.tile(t)["price"]
	for l in range(1, level[t] + 1):
		v += base_build_cost(t, l)
	return v


func buy_price(pid: int, t: int) -> int:
	var c := float(BoardData.tile(t)["price"])
	if players[pid]["character"] == "tieu_thuong":
		c *= 0.9
	return _round5(c)


func takeover_price(pid: int, t: int) -> int:
	var c := invested(t) * TAKEOVER_MULT
	if players[pid]["character"] == "doanh_nhan":
		c *= 0.9
	return _round5(c)


func season_mult(t: int) -> float:
	var td := BoardData.tile(t)
	var g: int = td["group"]
	match season:
		1:
			if td.get("coastal", false):
				return 1.5
		2:
			if g == 0 or g == 1 or g == 8:
				return 1.5
		3:
			if BoardData.GROUPS[g]["region"] == 0:
				return 0.7
	return 1.0


func rent(t: int) -> int:
	var o: int = owner[t]
	if o < 0:
		return 0
	var td := BoardData.tile(t)
	if td["type"] == BoardData.T.INFRA:
		return INFRA_RENT[infra_count(o)]
	var r: float = td["price"] * RENT_MULT[level[t]]
	if owns_group(o, td["group"]):
		r *= 2.0
	if t == festival_tile:
		r *= 2.5 if players[o]["character"] == "nghe_si" else 2.0
	r *= season_mult(t)
	if players[o]["character"] == "ngu_dan" and td.get("coastal", false):
		r *= 1.1
	var ev_type: String = season_event.get("type", "")
	if ev_type == "flood" and td["group"] == 8:
		r *= 0.5
	elif ev_type == "tourism" and season_event.get("tile", -1) == t:
		r *= 2.0
	return _round5(r)


func net_worth(pid: int) -> int:
	var v: int = players[pid]["cash"]
	for t in BoardData.TILE_COUNT:
		if owner[t] == pid:
			v += invested(t)
	return v


func buy_options(pid: int, t: int) -> Array:
	var res: Array = []
	var cash: int = players[pid]["cash"]
	var price := buy_price(pid, t)
	if cash >= price:
		res.append({"level": 0, "cost": price})
	if BoardData.is_province(t):
		var total := price
		for l in range(1, MAX_LEVEL_ON_BUY + 1):
			total += build_cost(pid, t, l)
			if cash >= total:
				res.append({"level": l, "cost": total})
	return res


func build_options(pid: int, t: int) -> Array:
	var res: Array = []
	if not BoardData.is_province(t) or owner[t] != pid:
		return res
	var cur: int = level[t]
	var cash: int = players[pid]["cash"]
	if cur >= 4:
		return res
	if cur == 3:
		if group_count(pid, BoardData.tile(t)["group"]) >= 2:
			var c := build_cost(pid, t, 4)
			if cash >= c:
				res.append({"level": 4, "cost": c})
		return res
	var total := 0
	for l in range(cur + 1, 4):
		total += build_cost(pid, t, l)
		if cash >= total:
			res.append({"level": l, "cost": total})
	return res


func festival_options(pid: int) -> Array:
	var res: Array = []
	for t in BoardData.TILE_COUNT:
		if owner[t] == pid and BoardData.is_province(t):
			res.append(t)
	return res


func giai_toa_targets(pid: int) -> Array:
	var res: Array = []
	for t in BoardData.TILE_COUNT:
		var o: int = owner[t]
		if o >= 0 and o != pid and level[t] >= 1 and level[t] <= 3:
			res.append(t)
	return res


func train_targets() -> Array:
	var res: Array = []
	for t in BoardData.TILE_COUNT:
		if t != BoardData.TRAIN_TILE:
			res.append(t)
	return res


func jail_fee(pid: int) -> int:
	return JAIL_FEE / 2 if players[pid]["character"] == "xe_om" else JAIL_FEE


func train_fee(pid: int) -> int:
	return 0 if players[pid]["character"] == "xe_om" else TRAIN_FEE


func specialty_counts(pid: int) -> Array:
	var counts := [0, 0, 0]
	for t in players[pid]["specialties"]:
		counts[BoardData.region_of(t)] += 1
	return counts


func can_exchange(pid: int, kind: String) -> bool:
	var p: Dictionary = players[pid]
	if p["cards"].size() >= MAX_CARDS:
		return false
	var c := specialty_counts(pid)
	if kind == "rare":
		return c[0] >= 1 and c[1] >= 1 and c[2] >= 1
	if kind == "common":
		return c[0] >= 3 or c[1] >= 3 or c[2] >= 3
	return false


func market_options(pid: int) -> Array:
	var res: Array = []
	if can_exchange(pid, "rare"):
		res.append("exchange_rare")
	if can_exchange(pid, "common"):
		res.append("exchange_common")
	if players[pid]["cash"] >= SPECIALTY_PRICE:
		res.append("buy_specialty")
	return res


# ---------------------------------------------------------------- hành động

func act(pid: int, action: Dictionary) -> Array:
	_events = []
	if game_over or pending.is_empty() or pid != pending["p"]:
		return _events
	if not _apply(action):
		return []
	if not game_over and pending.is_empty():
		_end_turn()
	return _events


func _apply(a: Dictionary) -> bool:
	var p: Dictionary = players[current]
	var kind: String = a.get("action", "")
	var ptype: String = pending["type"]
	match ptype:
		"turn":
			return _act_turn(p, kind, a)
		"jail":
			return _act_jail(p, kind)
		"train":
			return _act_train(p, kind, a)
		"buy":
			return _act_buy(p, kind, a)
		"build":
			return _act_build(p, kind, a)
		"takeover":
			return _act_takeover(p, kind)
		"festival":
			return _act_festival(p, kind, a)
		"lottery":
			return _act_lottery(p, kind, a)
		"market":
			return _act_market(p, kind)
		"chance_pick":
			if kind != "pick":
				return false
			var idx: int = a.get("index", 0)
			var cards: Array = pending["cards"]
			if idx < 0 or idx >= cards.size():
				return false
			pending = {}
			_apply_chance(p, cards[idx])
			return true
	return false


func _act_turn(p: Dictionary, kind: String, a: Dictionary) -> bool:
	match kind:
		"roll":
			pending = {}
			_roll_and_move(p, -1)
			return true
		"golden":
			var total: int = a.get("total", 7)
			if not p["cards"].has("XUC_XAC_VANG") or total < 2 or total > 12:
				return false
			_use_card(p, "XUC_XAC_VANG")
			pending = {}
			_roll_and_move(p, total)
			return true
		"giai_toa":
			var t: int = a.get("tile", -1)
			if not p["cards"].has("GIAI_TOA") or not giai_toa_targets(p["id"]).has(t):
				return false
			_use_card(p, "GIAI_TOA")
			_set_tile(t, owner[t], level[t] - 1)
			_log("%s dùng Giải Tỏa: %s của %s bị hạ xuống %s." % [p["name"], BoardData.plain_name(t), players[owner[t]]["name"], LEVEL_NAMES[level[t]]])
			_set_turn_pending()
			return true
		"exchange":
			var k: String = a.get("kind", "")
			if not can_exchange(p["id"], k):
				return false
			_do_exchange(p, k)
			_set_turn_pending()
			return true
	return false


func _act_jail(p: Dictionary, kind: String) -> bool:
	var fee := jail_fee(p["id"])
	if kind == "pay":
		if p["cash"] < fee:
			return false
		_pay(p, fee, -1, "Phí thoát Kẹt Xe")
		p["in_jail"] = false
		p["jail_tries"] = 0
		_push({"t": "jail_free", "p": p["id"]})
		_log("%s trả %s gọi xe ôm thoát Kẹt Xe." % [p["name"], BoardData.money(fee)])
		_set_turn_pending()
		return true
	if kind == "roll":
		pending = {}
		var d := _roll_dice(-1)
		_push({"t": "dice", "p": p["id"], "d": d})
		if d[0] == d[1]:
			_log("%s tung được đôi %d-%d, thoát Kẹt Xe!" % [p["name"], d[0], d[1]])
			_free_and_move(p, d[0] + d[1])
			return true
		p["jail_tries"] += 1
		if p["jail_tries"] >= 3:
			_log("%s kẹt 3 lượt, buộc trả phí %s để đi tiếp." % [p["name"], BoardData.money(fee)])
			_pay(p, fee, -1, "Phí thoát Kẹt Xe")
			if not p["alive"]:
				return true
			_free_and_move(p, d[0] + d[1])
			return true
		_log("%s tung %d-%d, vẫn còn kẹt xe (%d/3)." % [p["name"], d[0], d[1], p["jail_tries"]])
		return true
	return false


func _free_and_move(p: Dictionary, steps: int) -> void:
	p["in_jail"] = false
	p["jail_tries"] = 0
	_push({"t": "jail_free", "p": p["id"]})
	_move(p, steps)
	_land(p)


func _act_train(p: Dictionary, kind: String, a: Dictionary) -> bool:
	if kind == "travel":
		var t: int = a.get("tile", -1)
		var fee := train_fee(p["id"])
		if t < 0 or t >= BoardData.TILE_COUNT or t == BoardData.TRAIN_TILE or p["cash"] < fee:
			return false
		pending = {}
		p["train_pending"] = false
		_pay(p, fee, -1, "Vé Tàu Thống Nhất")
		_log("%s đi Tàu Thống Nhất đến %s." % [p["name"], BoardData.plain_name(t)])
		_move(p, posmod(t - p["pos"], BoardData.TILE_COUNT), true)
		_land(p)
		return true
	if kind == "skip":
		p["train_pending"] = false
		_log("%s không đi tàu, tung xúc xắc như thường." % p["name"])
		_set_turn_pending()
		return true
	return false


func _act_buy(p: Dictionary, kind: String, a: Dictionary) -> bool:
	var t: int = pending["tile"]
	if kind == "pass":
		pending = {}
		_log("%s bỏ qua %s." % [p["name"], BoardData.plain_name(t)])
		return true
	if kind != "buy":
		return false
	var lvl: int = a.get("level", 0)
	var opt := _find_option(pending["options"], lvl)
	if opt.is_empty():
		return false
	pending = {}
	_pay(p, opt["cost"], -1, "Mua đất")
	_set_tile(t, p["id"], lvl)
	if lvl > 0:
		_log("%s mua %s và xây %s (%s)." % [p["name"], BoardData.plain_name(t), LEVEL_NAMES[lvl], BoardData.money(opt["cost"])])
	else:
		_log("%s mua %s (%s)." % [p["name"], BoardData.plain_name(t), BoardData.money(opt["cost"])])
	_check_domination(p["id"])
	return true


func _act_build(p: Dictionary, kind: String, a: Dictionary) -> bool:
	var t: int = pending["tile"]
	if kind == "pass":
		pending = {}
		return true
	if kind != "build":
		return false
	var lvl: int = a.get("level", 0)
	var opt := _find_option(pending["options"], lvl)
	if opt.is_empty():
		return false
	pending = {}
	_pay(p, opt["cost"], -1, "Xây dựng")
	_set_tile(t, p["id"], lvl)
	if lvl == 4:
		_log("%s xây Danh Thắng %s tại %s!" % [p["name"], BoardData.tile(t)["landmark"], BoardData.plain_name(t)])
		_push({"t": "landmark", "p": p["id"], "tile": t})
	else:
		_log("%s nâng %s lên %s (%s)." % [p["name"], BoardData.plain_name(t), LEVEL_NAMES[lvl], BoardData.money(opt["cost"])])
	return true


func _act_takeover(p: Dictionary, kind: String) -> bool:
	var t: int = pending["tile"]
	if kind == "pass":
		pending = {}
		return true
	if kind != "takeover":
		return false
	var price: int = pending["price"]
	var victim: Dictionary = players[owner[t]]
	pending = {}
	if victim["cards"].has("BAO_HIEM"):
		_use_card(victim, "BAO_HIEM")
		_log("%s có Bảo Hiểm — thâu tóm %s thất bại!" % [victim["name"], BoardData.plain_name(t)])
		return true
	_pay(p, price, victim["id"], "Thâu tóm")
	_set_tile(t, p["id"], level[t])
	_push({"t": "takeover", "p": p["id"], "from": victim["id"], "tile": t})
	_log("%s thâu tóm %s từ %s với giá %s!" % [p["name"], BoardData.plain_name(t), victim["name"], BoardData.money(price)])
	_check_domination(p["id"])
	if game_over:
		return true
	var bo := build_options(p["id"], t)
	if bo.size() > 0:
		pending = {"type": "build", "p": p["id"], "tile": t, "options": bo}
	return true


func _act_festival(p: Dictionary, kind: String, a: Dictionary) -> bool:
	if kind == "pass":
		pending = {}
		return true
	if kind != "festival":
		return false
	var t: int = a.get("tile", -1)
	if not pending["options"].has(t):
		return false
	pending = {}
	festival_tile = t
	_push({"t": "festival", "tile": t})
	_log("%s tổ chức Lễ Hội tại %s — tiền thuê tăng mạnh!" % [p["name"], BoardData.plain_name(t)])
	return true


func _act_lottery(p: Dictionary, kind: String, a: Dictionary) -> bool:
	if kind == "pass":
		pending = {}
		return true
	if kind != "bet":
		return false
	var bet: int = a.get("amount", 0)
	var num: int = a.get("number", 1)
	if not pending["bets"].has(bet) or num < 1 or num > 6:
		return false
	pending = {}
	_pay(p, bet, -1, "Mua vé số")
	var roll := rng.randi_range(1, 6)
	var win := roll == num
	_push({"t": "lottery", "p": p["id"], "number": num, "roll": roll, "win": win, "bet": bet})
	if win:
		_add_cash(p, bet * LOTTERY_PAYOUT, "Trúng số")
		_log("%s chọn số %d, xổ ra %d — TRÚNG %s!" % [p["name"], num, roll, BoardData.money(bet * LOTTERY_PAYOUT)])
	else:
		_log("%s chọn số %d, xổ ra %d — trượt rồi." % [p["name"], num, roll])
	return true


func _act_market(p: Dictionary, kind: String) -> bool:
	if kind == "pass":
		pending = {}
		return true
	if not pending["options"].has(kind):
		return false
	pending = {}
	match kind:
		"exchange_rare":
			_do_exchange(p, "rare")
		"exchange_common":
			_do_exchange(p, "common")
		"buy_specialty":
			_pay(p, SPECIALTY_PRICE, -1, "Mua đặc sản")
			var provinces: Array = []
			for t in BoardData.TILE_COUNT:
				if BoardData.is_province(t):
					provinces.append(t)
			_give_specialty(p, provinces[rng.randi_range(0, provinces.size() - 1)])
	return true


# ---------------------------------------------------------------- vòng lượt

func _begin_turn() -> void:
	var p: Dictionary = players[current]
	_push({"t": "turn", "p": current})
	if p["in_jail"]:
		if p["cards"].has("THOAT_KET"):
			_use_card(p, "THOAT_KET")
			p["in_jail"] = false
			p["jail_tries"] = 0
			_push({"t": "jail_free", "p": current})
			_log("%s dùng thẻ Thoát Kẹt." % p["name"])
		else:
			pending = {"type": "jail", "p": current, "fee": jail_fee(current), "tries": p["jail_tries"]}
			return
	if p["train_pending"]:
		pending = {"type": "train", "p": current, "fee": train_fee(current)}
		return
	_set_turn_pending()


func _set_turn_pending() -> void:
	pending = {"type": "turn", "p": current}


func _end_turn() -> void:
	if game_over:
		return
	var p: Dictionary = players[current]
	if _bonus_roll and p["alive"] and not p["in_jail"]:
		_bonus_roll = false
		_log("%s tung được đôi nên được đi tiếp!" % p["name"])
		_begin_turn()
		return
	_bonus_roll = false
	p["doubles"] = 0
	_next_player()


func _next_player() -> void:
	var n := players.size()
	var i := current
	var wrapped := false
	for k in n:
		i = (i + 1) % n
		if i == 0:
			wrapped = true
		if players[i]["alive"]:
			break
	current = i
	if wrapped:
		_new_round()
	if game_over:
		return
	_begin_turn()


func _new_round() -> void:
	round_num += 1
	if round_num > max_rounds:
		_log("Hết %d vòng! Tính tổng tài sản..." % max_rounds)
		var alive := _sorted_by_worth(alive_players())
		_finish(alive[0], "rounds")
		return
	_push({"t": "round", "n": round_num})
	if (round_num - 1) % SEASON_ROUNDS == 0:
		_change_season()


func _change_season() -> void:
	season = (season + 1) % 4
	season_event = {}
	_log("Chuyển mùa: %s. %s" % [SEASON_NAMES[season], SEASON_DESC[season]])
	if rng.randf() < 0.35:
		match rng.randi_range(0, 2):
			0:
				season_event = {"type": "storm", "name": "Bão miền Trung"}
			1:
				season_event = {"type": "flood", "name": "Lũ miền Tây"}
			2:
				var t := _random_province()
				season_event = {"type": "tourism", "name": "Năm du lịch %s" % BoardData.plain_name(t), "tile": t}
	_push({"t": "season", "season": season, "event": season_event})
	if season == 0:
		for pid in alive_players():
			_add_cash(players[pid], 50, "Lì xì Tết")
		_log("Tết đến! Mọi người nhận lì xì 50.")
	var et: String = season_event.get("type", "")
	if et == "storm":
		_apply_storm()
	elif et == "flood":
		_log("Lũ miền Tây! Tiền thuê nhóm Miền Tây giảm 50% trong mùa này.")
	elif et == "tourism":
		_log("%s! Tiền thuê tại đây ×2 trong mùa này." % season_event["name"])


func _apply_storm() -> void:
	_log("Bão đổ bộ miền Trung! Nhà ở Bắc Trung Bộ và Miền Trung di sản bị hư hại.")
	var by_owner := {}
	for g in [4, 5]:
		for t in _group_tiles[g]:
			if owner[t] >= 0 and level[t] >= 1 and level[t] <= 3:
				if not by_owner.has(owner[t]):
					by_owner[owner[t]] = []
				by_owner[owner[t]].append(t)
	for o in by_owner.keys():
		var op: Dictionary = players[o]
		if op["storm_shield"]:
			op["storm_shield"] = false
			_log("%s đã chuẩn bị kỹ — miễn nhiễm cơn bão này." % op["name"])
			continue
		if op["cards"].has("BAO_HIEM"):
			_use_card(op, "BAO_HIEM")
			_log("%s dùng Bảo Hiểm chống bão." % op["name"])
			continue
		for t in by_owner[o]:
			_set_tile(t, o, level[t] - 1)
		_push({"t": "storm", "tiles": by_owner[o]})


# ---------------------------------------------------------------- di chuyển & ô

func _roll_dice(forced_total: int) -> Array:
	if forced_total >= 2:
		var a := maxi(1, forced_total - 6)
		var b := forced_total - a
		if a == b and a > 1 and b < 6:
			a -= 1
			b += 1
		return [a, b]
	return [rng.randi_range(1, 6), rng.randi_range(1, 6)]


func _roll_and_move(p: Dictionary, forced: int) -> void:
	var d := _roll_dice(forced)
	_push({"t": "dice", "p": p["id"], "d": d})
	if forced < 0 and d[0] == d[1]:
		p["doubles"] += 1
		if p["doubles"] >= 3:
			p["doubles"] = 0
			_log("%s tung đôi 3 lần liên tiếp — bị Kẹt Xe!" % p["name"])
			_send_jail(p)
			return
		_bonus_roll = true
	else:
		p["doubles"] = 0
	_move(p, d[0] + d[1])
	_land(p)


func _move(p: Dictionary, steps: int, fast: bool = false) -> void:
	var path: Array = []
	var pos: int = p["pos"]
	var dir := 1 if steps >= 0 else -1
	var passed_start := false
	for i in absi(steps):
		pos = posmod(pos + dir, BoardData.TILE_COUNT)
		path.append(pos)
		if pos == BoardData.START_TILE and dir > 0:
			passed_start = true
	p["pos"] = pos
	_push({"t": "move", "p": p["id"], "path": path, "fast": fast})
	if passed_start:
		var amt: int = SALARY
		if season == 0:
			amt = int(amt * 1.5)
		if p["character"] == "nong_dan" and season == 2:
			amt += 100
		_add_cash(p, amt, "Lương qua Km 0")
		_log("%s qua Km 0, nhận lương %s." % [p["name"], BoardData.money(amt)])


func _land(p: Dictionary) -> void:
	var t: int = p["pos"]
	var ty: int = BoardData.tile(t)["type"]
	if ty == BoardData.T.START:
		_add_cash(p, SALARY, "Dừng đúng Km 0")
		_log("%s dừng đúng Km 0, thưởng thêm %s!" % [p["name"], BoardData.money(SALARY)])
	elif ty == BoardData.T.PROVINCE or ty == BoardData.T.INFRA:
		_land_property(p, t)
	elif ty == BoardData.T.CHANCE:
		_draw_chance(p)
	elif ty == BoardData.T.TAX:
		var amt := mini(200, _round5(net_worth(p["id"]) * 0.1))
		_log("%s nộp thuế %s." % [p["name"], BoardData.money(amt)])
		_pay(p, amt, -1, "Thuế")
	elif ty == BoardData.T.JAIL:
		_log("%s dính Kẹt Xe!" % p["name"])
		_send_jail(p)
	elif ty == BoardData.T.FESTIVAL:
		var opts := festival_options(p["id"])
		if opts.size() > 0:
			pending = {"type": "festival", "p": p["id"], "options": opts}
		else:
			_log("%s đến Lễ Hội nhưng chưa có tỉnh nào để tổ chức." % p["name"])
	elif ty == BoardData.T.TRAIN:
		p["train_pending"] = true
		_log("%s lên Tàu Thống Nhất — lượt sau được chọn ga đến!" % p["name"])
	elif ty == BoardData.T.MARKET:
		var mo := market_options(p["id"])
		if mo.size() > 0:
			pending = {"type": "market", "p": p["id"], "options": mo}
	elif ty == BoardData.T.LOTTERY:
		var bets: Array = []
		for b in LOTTERY_BETS:
			if p["cash"] >= b:
				bets.append(b)
		if bets.size() > 0:
			pending = {"type": "lottery", "p": p["id"], "bets": bets}


func _land_property(p: Dictionary, t: int) -> void:
	var o: int = owner[t]
	if o == -1:
		var opts := buy_options(p["id"], t)
		if opts.size() > 0:
			pending = {"type": "buy", "p": p["id"], "tile": t, "options": opts}
		else:
			_log("%s không đủ tiền mua %s." % [p["name"], BoardData.plain_name(t)])
	elif o == p["id"]:
		var bo := build_options(p["id"], t)
		if bo.size() > 0:
			pending = {"type": "build", "p": p["id"], "tile": t, "options": bo}
	else:
		var r := rent(t)
		if r >= FREE_RENT_THRESHOLD and p["cards"].has("MIEN_THUE"):
			_use_card(p, "MIEN_THUE")
			_log("%s dùng Miễn Thuê, không phải trả %s tại %s." % [p["name"], BoardData.money(r), BoardData.plain_name(t)])
		else:
			_log("%s trả %s tiền thuê cho %s tại %s." % [p["name"], BoardData.money(r), players[o]["name"], BoardData.plain_name(t)])
			_pay(p, r, o, "Tiền thuê")
		if not p["alive"]:
			return
		if BoardData.is_province(t):
			_give_specialty(p, t)
		if level[t] < 4 and owner[t] == o and players[o]["alive"]:
			var price := takeover_price(p["id"], t)
			if p["cash"] >= price:
				pending = {"type": "takeover", "p": p["id"], "tile": t, "price": price, "from": o}


func _send_jail(p: Dictionary) -> void:
	p["pos"] = BoardData.JAIL_TILE
	p["in_jail"] = true
	p["jail_tries"] = 0
	p["doubles"] = 0
	_bonus_roll = false
	_push({"t": "jail", "p": p["id"]})


# ---------------------------------------------------------------- thẻ

func _next_chance() -> int:
	if _chance_deck.is_empty():
		for i in CardsData.CHANCE.size():
			_chance_deck.append(i)
		for i in range(_chance_deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: int = _chance_deck[i]
			_chance_deck[i] = _chance_deck[j]
			_chance_deck[j] = tmp
	return _chance_deck.pop_back()


func _draw_chance(p: Dictionary) -> void:
	if p["character"] == "hoc_sinh":
		var a := _next_chance()
		var b := _next_chance()
		pending = {"type": "chance_pick", "p": p["id"], "cards": [a, b]}
		return
	_apply_chance(p, _next_chance())


func _apply_chance(p: Dictionary, idx: int) -> void:
	var c: Dictionary = CardsData.CHANCE[idx]
	_push({"t": "chance", "p": p["id"], "text": c["text"]})
	_log("%s rút Cơ Hội: %s" % [p["name"], c["text"]])
	match String(c["kind"]):
		"money":
			var amt: int = c["amount"]
			if amt >= 0:
				_add_cash(p, amt, "Cơ Hội")
			else:
				_pay(p, -amt, -1, "Cơ Hội")
		"move_to":
			_move(p, posmod(int(c["tile"]) - int(p["pos"]), BoardData.TILE_COUNT))
			_land(p)
		"move_steps":
			_move(p, c["steps"])
			_land(p)
		"jail":
			_send_jail(p)
		"pay_each":
			for pid in alive_players():
				if pid != p["id"] and p["alive"]:
					_pay(p, c["amount"], pid, "Lì xì")
		"collect_each":
			for pid in alive_players():
				if pid != p["id"]:
					_pay(players[pid], c["amount"], p["id"], "Mừng sinh nhật")
		"upgrade":
			var cands: Array = []
			for t in owned_tiles(p["id"]):
				if BoardData.is_province(t) and level[t] < 3:
					cands.append(t)
			if cands.is_empty():
				_log("...nhưng %s chưa có nhà nào để nâng cấp." % p["name"])
			else:
				var t: int = cands[rng.randi_range(0, cands.size() - 1)]
				_set_tile(t, p["id"], level[t] + 1)
				_log("%s được nâng lên %s miễn phí." % [BoardData.plain_name(t), LEVEL_NAMES[level[t]]])
		"skill":
			_give_skill(p, CardsData.COMMON_SKILLS[rng.randi_range(0, CardsData.COMMON_SKILLS.size() - 1)])
		"repair":
			var lv := 0
			for t in owned_tiles(p["id"]):
				lv += level[t]
			if lv > 0:
				_pay(p, lv * int(c["amount"]), -1, "Bảo trì nhà")


func _give_specialty(p: Dictionary, t: int) -> void:
	var sp: Array = p["specialties"]
	sp.append(t)
	if sp.size() > MAX_SPECIALTIES:
		sp.pop_front()
	_push({"t": "specialty", "p": p["id"], "tile": t})


func _give_skill(p: Dictionary, card: String) -> void:
	if p["cards"].size() >= MAX_CARDS:
		_log("%s đã đủ %d thẻ, không nhận thêm được." % [p["name"], MAX_CARDS])
		return
	p["cards"].append(card)
	_push({"t": "card_gain", "p": p["id"], "card": card})
	_log("%s nhận thẻ %s." % [p["name"], CardsData.SKILLS[card]["name"]])


func _use_card(p: Dictionary, card: String) -> void:
	p["cards"].erase(card)
	_push({"t": "card_use", "p": p["id"], "card": card})


func _do_exchange(p: Dictionary, kind: String) -> void:
	var sp: Array = p["specialties"]
	if kind == "rare":
		for r in 3:
			for i in sp.size():
				if BoardData.region_of(sp[i]) == r:
					sp.remove_at(i)
					break
		_log("%s đổi đặc sản 3 miền lấy thẻ hiếm!" % p["name"])
		_give_skill(p, CardsData.RARE_SKILLS[rng.randi_range(0, CardsData.RARE_SKILLS.size() - 1)])
	else:
		var counts := specialty_counts(p["id"])
		var region := 0
		for r in 3:
			if counts[r] >= 3:
				region = r
				break
		var removed := 0
		var i := 0
		while i < sp.size() and removed < 3:
			if BoardData.region_of(sp[i]) == region:
				sp.remove_at(i)
				removed += 1
			else:
				i += 1
		_log("%s đổi 3 đặc sản %s lấy thẻ kỹ năng." % [p["name"], BoardData.REGION_NAMES[region]])
		_give_skill(p, CardsData.COMMON_SKILLS[rng.randi_range(0, CardsData.COMMON_SKILLS.size() - 1)])


# ---------------------------------------------------------------- tiền & phá sản

func _add_cash(p: Dictionary, delta: int, reason: String) -> void:
	if delta == 0:
		return
	p["cash"] += delta
	_push({"t": "cash", "p": p["id"], "delta": delta, "cash": p["cash"], "reason": reason})


func _pay(p: Dictionary, amount: int, to: int, reason: String) -> void:
	if amount <= 0 or not p["alive"]:
		return
	if p["cash"] < amount:
		_liquidate(p, amount)
	if p["cash"] >= amount:
		_add_cash(p, -amount, reason)
		if to >= 0:
			_add_cash(players[to], amount, reason)
		return
	var left: int = p["cash"]
	_add_cash(p, -left, reason)
	if to >= 0 and left > 0:
		_add_cash(players[to], left, reason)
	_bankrupt(p)


## Bán bớt tài sản cho ngân hàng (50% giá trị) để đủ tiền trả. Bán món rẻ nhất trước.
func _liquidate(p: Dictionary, need: int) -> void:
	while p["cash"] < need:
		var best_t := -1
		var best_val := 1 << 30
		for t in BoardData.TILE_COUNT:
			if owner[t] != p["id"]:
				continue
			var val: int
			if level[t] > 0:
				val = base_build_cost(t, level[t]) / 2
			else:
				val = int(BoardData.tile(t)["price"]) / 2
			if val < best_val:
				best_val = val
				best_t = t
		if best_t < 0:
			return
		if level[best_t] > 0:
			_set_tile(best_t, p["id"], level[best_t] - 1)
			_log("%s bán bớt nhà ở %s lấy %s." % [p["name"], BoardData.plain_name(best_t), BoardData.money(best_val)])
		else:
			_set_tile(best_t, -1, 0)
			_log("%s bán đất %s lấy %s." % [p["name"], BoardData.plain_name(best_t), BoardData.money(best_val)])
		_add_cash(p, best_val, "Bán tài sản")


func _bankrupt(p: Dictionary) -> void:
	p["alive"] = false
	p["in_jail"] = false
	eliminated.append(p["id"])
	for t in BoardData.TILE_COUNT:
		if owner[t] == p["id"]:
			_set_tile(t, -1, 0)
	_push({"t": "bankrupt", "p": p["id"]})
	_log("%s đã PHÁ SẢN!" % p["name"])
	if p["id"] == current:
		pending = {}
		_bonus_roll = false
	var alive := alive_players()
	if alive.size() == 1:
		_finish(alive[0], "last")


func _check_domination(pid: int) -> void:
	var has := [false, false, false]
	for g in BoardData.GROUPS.size():
		if owns_group(pid, g):
			has[BoardData.GROUPS[g]["region"]] = true
	if has[0] and has[1] and has[2]:
		_log("%s làm BÁ CHỦ BA MIỀN!" % players[pid]["name"])
		_finish(pid, "domination")


func _finish(win_id: int, reason: String) -> void:
	if game_over:
		return
	game_over = true
	pending = {}
	winner = win_id
	win_reason = reason
	ranking = [win_id]
	for pid in _sorted_by_worth(alive_players()):
		if pid != win_id:
			ranking.append(pid)
	for i in range(eliminated.size() - 1, -1, -1):
		ranking.append(eliminated[i])
	var worths: Array = []
	for pid in ranking:
		worths.append(net_worth(pid) if players[pid]["alive"] else 0)
	_push({"t": "game_over", "winner": win_id, "reason": reason, "ranking": ranking, "worths": worths})


func _sorted_by_worth(ids: Array) -> Array:
	var res := ids.duplicate()
	res.sort_custom(func(a, b): return net_worth(a) > net_worth(b))
	return res


# ---------------------------------------------------------------- tiện ích

func _set_tile(t: int, o: int, l: int) -> void:
	owner[t] = o
	level[t] = l
	if o == -1 and festival_tile == t:
		festival_tile = -1
		_push({"t": "festival", "tile": -1})
	_push({"t": "tile", "tile": t, "owner": o, "level": l})


func _random_province() -> int:
	while true:
		var t := rng.randi_range(0, BoardData.TILE_COUNT - 1)
		if BoardData.is_province(t):
			return t
	return 1


func _find_option(opts: Array, lvl: int) -> Dictionary:
	for o in opts:
		if o["level"] == lvl:
			return o
	return {}


func _push(ev: Dictionary) -> void:
	_events.append(ev)


func _log(text: String) -> void:
	_events.append({"t": "log", "text": text})


static func _round5(v: float) -> int:
	return int(round(v / 5.0)) * 5
