class_name AuctionRules
extends RefCounted
## Luật đấu giá ô chưa có chủ (thuần logic, engine gọi sang; trạng thái nằm trong engine.auction).
##
## Kích hoạt: người dừng ở ô chưa có chủ chọn "Bỏ qua" → những người còn lại (trừ người vừa bỏ) đấu giá.
## Giá khởi điểm 50% giá niêm yết, bước giá 10% (chỉnh trong data/economy.tres).
## Lần lượt từng người còn trong cuộc: trả +1/+2/+3 bước hoặc bỏ. Còn 1 người dẫn đầu → thắng.
## Không ai trả giá khởi điểm → ô vẫn chưa có chủ. Mỗi người trả tối đa auction_max_bids lần.
##
## Sự kiện phát ra: auction_start, auction_bid, auction_fold, auction_end (+ log).
## Quyết định chờ: {"type": "auction_bid", "p": người đang được hỏi, "options": [số bước được phép], ...}


static func start(e: GameEngine, t: int, passer: int) -> void:
	var cfg := EconomyConfig.get_default()
	var list_price: int = BoardData.tile(t)["price"]
	var start_price := cfg.round_price(list_price * cfg.auction_start_ratio)
	var step := cfg.round_price(list_price * cfg.auction_step_ratio)
	var order: Array = []
	var excluded: Array = []
	var n := e.players.size()
	for k in range(1, n):
		var pid := (passer + k) % n
		var p: Dictionary = e.players[pid]
		if not p["alive"]:
			continue
		if int(p["cash"]) < start_price:
			excluded.append(pid)
		else:
			order.append(pid)
	e.auction = {
		"tile": t, "list_price": list_price, "start": start_price, "step": step,
		"price": 0, "leader": -1, "order": order, "active": order.duplicate(), "bids": {},
		"turn": -1, "excluded": excluded, "passer": passer, "ai": {},
	}
	e._push({"t": "auction_start", "tile": t, "list_price": list_price, "start": start_price, "step": step,
		"bidders": order, "excluded": excluded, "passer": passer})
	e._log("%s được đem ra ĐẤU GIÁ! Khởi điểm %s, bước giá %s." % [BoardData.plain_name(t), BoardData.money(start_price), BoardData.money(step)])
	_next(e)


## Giá sau khi trả k bước.
static func price_for(a: Dictionary, k: int) -> int:
	if int(a["leader"]) < 0:
		return int(a["start"]) + (k - 1) * int(a["step"])
	return int(a["price"]) + k * int(a["step"])


static func apply(e: GameEngine, pid: int, action: Dictionary) -> bool:
	var a: Dictionary = e.auction
	if a.is_empty():
		return false
	var kind: String = action.get("action", "")
	if kind == "fold":
		e.pending = {}
		_fold(e, pid, "bỏ cuộc")
		_next(e)
		return true
	if kind != "bid":
		return false
	var k: int = action.get("steps", 1)
	if not (e.pending["options"] as Array).has(k):
		return false
	var new_price := price_for(a, k)
	if new_price > int(e.players[pid]["cash"]):
		return false
	e.pending = {}
	a["price"] = new_price
	a["leader"] = pid
	a["bids"][pid] = int(a["bids"].get(pid, 0)) + 1
	e._push({"t": "auction_bid", "p": pid, "price": new_price, "steps": k})
	e._log("%s trả %s." % [e.players[pid]["name"], BoardData.money(new_price)])
	_next(e)
	return true


static func _fold(e: GameEngine, pid: int, reason: String) -> void:
	var a: Dictionary = e.auction
	(a["active"] as Array).erase(pid)
	e._push({"t": "auction_fold", "p": pid, "reason": reason})
	e._log("%s %s." % [e.players[pid]["name"], reason])


## Tìm người kế tiếp được hỏi giá, hoặc kết thúc cuộc đấu giá.
static func _next(e: GameEngine) -> void:
	var cfg := EconomyConfig.get_default()
	var a: Dictionary = e.auction
	var order: Array = a["order"]
	var active: Array = a["active"]
	while true:
		var leader: int = a["leader"]
		if active.is_empty() or (leader >= 0 and active.size() == 1 and active[0] == leader):
			_finish(e)
			return
		# người kế tiếp còn trong cuộc, không phải người đang dẫn đầu
		var pid := -1
		var idx: int = a["turn"]
		for k in order.size():
			idx = (idx + 1) % order.size()
			var cand: int = order[idx]
			if active.has(cand) and cand != leader:
				pid = cand
				break
		if pid < 0:
			_finish(e)
			return
		a["turn"] = idx
		var cash: int = e.players[pid]["cash"]
		if cash < price_for(a, 1):
			_fold(e, pid, "không đủ tiền theo giá")
			continue
		if int(a["bids"].get(pid, 0)) >= cfg.auction_max_bids:
			_fold(e, pid, "đã hết lượt trả giá")
			continue
		var options: Array = []
		for k in range(1, cfg.auction_max_raise_steps + 1):
			if price_for(a, k) <= cash:
				options.append(k)
		e.pending = {
			"type": "auction_bid", "p": pid, "tile": a["tile"], "price": a["price"], "leader": leader,
			"step": a["step"], "start": a["start"], "options": options,
		}
		return


static func _finish(e: GameEngine) -> void:
	var a: Dictionary = e.auction
	e.pending = {}
	var t: int = a["tile"]
	var winner: int = a["leader"]
	var price: int = a["price"]
	e.auction = {}
	if winner < 0:
		e._push({"t": "auction_end", "tile": t, "winner": -1, "price": 0})
		e._log("Không ai trả giá — %s vẫn chưa có chủ." % BoardData.plain_name(t))
		return
	e._pay(e.players[winner], price, -1, "Thắng đấu giá")
	e._set_tile(t, winner, 0)
	e._push({"t": "auction_end", "tile": t, "winner": winner, "price": price})
	e._log("%s THẮNG ĐẤU GIÁ %s với giá %s!" % [e.players[winner]["name"], BoardData.plain_name(t), BoardData.money(price)])
	e._check_domination(winner)


# ---------------------------------------------------------------- AI đấu giá theo tính cách

## Giá trị ước tính của ô t đối với người chơi pid (chưa nhân tính cách).
static func estimate_value(e: GameEngine, pid: int, t: int, per: Dictionary) -> float:
	var cfg := EconomyConfig.get_default()
	var td := BoardData.tile(t)
	var progress := clampf(float(e.round_num - 1) / maxf(1.0, e.max_rounds - 1.0), 0.0, 1.0)
	var v: float = float(td["price"]) * lerpf(cfg.ai_value_early, cfg.ai_value_late, progress)
	if BoardData.is_province(t):
		var g: int = td["group"]
		var size := e.group_tiles(g).size()
		var owned := e.group_count(pid, g)
		v *= 1.0 + float(per["group_bonus"]) * owned
		if owned + 1 == size:
			v *= cfg.ai_complete_group_mult
		for other in e.alive_players():
			if other != pid and e.group_count(other, g) == size - 1:
				v *= cfg.ai_block_mult
				break
	else:
		v *= 1.0 + float(per["infra_bonus"]) + 0.2 * e.infra_count(pid)
	return v


static func ai_decide(e: GameEngine, pend: Dictionary) -> Dictionary:
	var cfg := EconomyConfig.get_default()
	var a: Dictionary = e.auction
	var pid: int = pend["p"]
	var p: Dictionary = e.players[pid]
	var per := cfg.personality(p["character"])
	var options: Array = pend["options"]
	if options.is_empty():
		return {"action": "fold"}
	# hệ số ngẫu nhiên cố định cho mỗi người trong một cuộc đấu giá
	var rolls: Dictionary = a["ai"]
	if not rolls.has(pid):
		var r: float = float(per["random"]) + (0.1 if int(p["difficulty"]) == 0 else 0.0)
		rolls[pid] = 1.0 + e.rng.randf_range(-r, r)
	var ceiling := estimate_value(e, pid, a["tile"], per) * float(per["bid_mult"]) * float(rolls[pid])
	var reserve := maxf(cfg.ai_min_reserve, cfg.ai_reserve_ratio * e.net_worth(pid)) * float(per["reserve"])
	var max_pay := minf(ceiling, float(p["cash"]) - reserve)
	if price_for(a, 1) > max_pay:
		return {"action": "fold"}
	var k := 1
	if int(a["leader"]) >= 0 and e.rng.randf() < float(per["jump"]):
		var want := e.rng.randi_range(2, cfg.auction_max_raise_steps)
		for kk in range(want, 1, -1):
			if options.has(kk) and price_for(a, kk) <= max_pay:
				k = kk
				break
	return {"action": "bid", "steps": k}
