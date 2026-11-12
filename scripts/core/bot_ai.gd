class_name BotAI
extends RefCounted
## Trí tuệ nhân tạo đơn giản cho máy. difficulty: 0 Dễ, 1 Thường, 2 Khó.


static func decide(e: GameEngine, pend: Dictionary) -> Dictionary:
	var pid: int = pend["p"]
	var p: Dictionary = e.players[pid]
	var diff: int = p["difficulty"]
	var reserve := _reserve(e, pid)
	var cash: int = p["cash"]
	match String(pend["type"]):
		"turn":
			return _turn(e, pid, diff)
		"jail":
			var fee: int = pend["fee"]
			var late: bool = e.round_num > int(e.max_rounds * 0.6)
			if cash >= fee + reserve * 2 and (not late or diff == 0):
				return {"action": "pay"}
			# Cuối ván ngồi kẹt xe an toàn hơn; đầu ván thử đường tắt (50%) để được đi tiếp
			if not late and diff >= 1:
				return {"action": "shortcut"}
			return {"action": "roll"}
		"train":
			var fee: int = pend["fee"]
			if cash < fee + reserve:
				return {"action": "skip"}
			var best := -1
			var best_score := 40.0
			for t in e.train_targets():
				var s := tile_score(e, pid, t)
				if s > best_score:
					best_score = s
					best = t
			if best >= 0:
				return {"action": "travel", "tile": best}
			return {"action": "skip"}
		"buy":
			var t: int = pend["tile"]
			var opts: Array = pend["options"]
			if diff == 0 and e.rng.randf() < 0.25:
				return {"action": "pass"}
			var need := reserve
			if BoardData.is_province(t):
				var g: int = BoardData.tile(t)["group"]
				if e.group_count(pid, g) + 1 >= e.group_tiles(g).size():
					need = reserve / 2
			var choice := -1
			for o in opts:
				if cash - int(o["cost"]) >= need:
					choice = o["level"]
			if choice >= 0:
				return {"action": "buy", "level": choice}
			return {"action": "pass"}
		"build":
			var choice := -1
			for o in pend["options"]:
				if cash - int(o["cost"]) >= reserve:
					choice = o["level"]
			if choice >= 0:
				return {"action": "build", "level": choice}
			return {"action": "pass"}
		"takeover":
			var t: int = pend["tile"]
			var price: int = pend["price"]
			if cash - price < int(reserve * 1.5):
				return {"action": "pass"}
			var worth: bool = diff == 2 or int(e.level[t]) >= 2
			if BoardData.is_province(t):
				var g: int = BoardData.tile(t)["group"]
				if e.group_count(pid, g) + 1 >= e.group_tiles(g).size():
					worth = true
			if diff == 0:
				worth = e.rng.randf() < 0.3
			return {"action": "takeover"} if worth else {"action": "pass"}
		"festival":
			var best := -1
			var best_rent := -1
			for t in pend["options"]:
				var r := e.rent(t)
				if r > best_rent:
					best_rent = r
					best = t
			return {"action": "festival", "tile": best}
		"lottery":
			if diff == 0 and e.rng.randf() < 0.4:
				return {"action": "bet", "amount": pend["bets"][0], "number": e.rng.randi_range(1, 6)}
			return {"action": "pass"}
		"market":
			var opts: Array = pend["options"]
			if opts.has("exchange_rare"):
				return {"action": "exchange_rare"}
			if opts.has("exchange_common"):
				return {"action": "exchange_common"}
			if opts.has("buy_specialty") and diff >= 1 and cash > 1000:
				return {"action": "buy_specialty"}
			return {"action": "pass"}
		"auction_bid":
			return AuctionRules.ai_decide(e, pend)
		"choose_building":
			return choose_building(e, pid, pend, reserve)
		"draw_card":
			return {"action": "draw"}
		"card_reveal":
			return {"action": "confirm"}
		"card_pick":
			var cards: Array = pend["cards"]
			var a: int = CardsData.card(pend["deck"], cards[0])["value"]
			var b: int = CardsData.card(pend["deck"], cards[1])["value"]
			return {"action": "pick", "index": 0 if a >= b else 1}
		"card_confirm":
			return _card_confirm(e, pid, pend, reserve)
		"card_player":
			return _card_player(e, pid, pend)
		"card_tile":
			return _card_tile(e, pid, pend, reserve)
	return {"action": "pass"}


static func _turn(e: GameEngine, pid: int, diff: int) -> Dictionary:
	var p: Dictionary = e.players[pid]
	if e.can_exchange(pid, "rare"):
		return {"action": "exchange", "kind": "rare"}
	if e.can_exchange(pid, "common"):
		return {"action": "exchange", "kind": "common"}
	if p["cards"].has("GIAI_TOA") and diff >= 1:
		var best := -1
		var best_rent := 0
		for t in e.giai_toa_targets(pid):
			var r := e.rent(t)
			if r > best_rent:
				best_rent = r
				best = t
		if best >= 0:
			return {"action": "giai_toa", "tile": best}
	if p["cards"].has("XUC_XAC_VANG") and diff >= 1:
		var best_total := 7
		var best_score := -INF
		for total in range(2, 13):
			var s := tile_score(e, pid, (int(p["pos"]) + total) % BoardData.TILE_COUNT)
			if s > best_score:
				best_score = s
				best_total = total
		if best_score >= 80:
			return {"action": "golden", "total": best_total}
	return {"action": "roll"}


## Ước lượng lợi/hại khi dừng ở ô t.
static func tile_score(e: GameEngine, pid: int, t: int) -> float:
	var p: Dictionary = e.players[pid]
	var td := BoardData.tile(t)
	var ty: int = td["type"]
	if ty == BoardData.T.PROVINCE or ty == BoardData.T.INFRA or ty == BoardData.T.TOLL:
		var o: int = e.owner[t]
		if o == -1:
			if int(p["cash"]) < e.buy_price(pid, t):
				return 0.0
			var s := 60.0 + float(td["price"]) * 0.4
			if ty == BoardData.T.PROVINCE:
				var g: int = td["group"]
				if e.group_count(pid, g) + 1 >= e.group_tiles(g).size():
					s += 150.0
			return s
		if o == pid:
			return 50.0 if e.build_options(pid, t).size() > 0 else 5.0
		return -float(e.rent(t))
	if ty == BoardData.T.START:
		return 200.0
	if ty == BoardData.T.KHI_VAN:
		return 25.0
	if ty == BoardData.T.CO_HOI:
		return 60.0
	if ty == BoardData.T.CHARITY:
		return float(e.charity_pot)
	if ty == BoardData.T.TAX:
		return -100.0
	if ty == BoardData.T.JAIL:
		return -60.0
	if ty == BoardData.T.FESTIVAL:
		return 70.0 if e.festival_options(pid).size() > 0 else 0.0
	if ty == BoardData.T.TRAIN:
		return 30.0
	if ty == BoardData.T.MARKET:
		return 10.0
	return 0.0


static func _reserve(e: GameEngine, pid: int) -> int:
	var diff: int = e.players[pid]["difficulty"]
	var base: int = [60, 150, 220][diff]
	return base + e.round_num * 6


static func _card_confirm(e: GameEngine, pid: int, pend: Dictionary, reserve: int) -> Dictionary:
	var c: Dictionary = CardsData.card(pend["deck"], pend["idx"])
	var cash: int = e.players[pid]["cash"]
	var yes := false
	match String(c["kind"]):
		"invest", "gamble":
			yes = cash - int(c["cost"]) >= reserve
		"loan":
			yes = cash < reserve * 2 and e.round_num + 3 < e.max_rounds
		"duel_richest":
			yes = cash >= int(c["lose"]) + reserve
		"sell_specialties":
			yes = e.players[pid]["specialties"].size() >= 4 or cash < reserve
	return {"action": "accept"} if yes else {"action": "pass"}


static func _card_player(e: GameEngine, pid: int, pend: Dictionary) -> Dictionary:
	var c: Dictionary = CardsData.card(pend["deck"], pend["idx"])
	var opts: Array = pend["options"]
	var best: int = opts[0]
	var best_score := -INF
	for oid in opts:
		var score := 0.0
		match String(c["kind"]):
			"swap_pos":
				# Đổi tới vị trí gần Km 0 nhất phía trước để sớm nhận lương
				score = -float(posmod(BoardData.START_TILE - int(e.players[oid]["pos"]), BoardData.TILE_COUNT))
			_:
				score = float(e.players[oid]["cash"])
		if score > best_score:
			best_score = score
			best = oid
	if c["kind"] == "swap_pos" and best_score < -float(posmod(BoardData.START_TILE - int(e.players[pid]["pos"]), BoardData.TILE_COUNT)):
		return {"action": "pass"}
	return {"action": "pick_player", "target": best}


static func _card_tile(e: GameEngine, pid: int, pend: Dictionary, reserve: int) -> Dictionary:
	var c: Dictionary = CardsData.card(pend["deck"], pend["idx"])
	var cash: int = e.players[pid]["cash"]
	var best := -1
	var best_score := -INF
	for t in pend["options"]:
		var score := 0.0
		match String(c["kind"]):
			"buy_remote", "build_anywhere":
				var price := e.card_price(pid, t, c)
				if cash - price < reserve:
					continue
				score = float(BoardData.tile(t)["price"])
				if BoardData.is_province(t):
					var g: int = BoardData.tile(t)["group"]
					if e.owner[t] == -1 and e.group_count(pid, g) + 1 >= e.group_tiles(g).size():
						score += 300.0
			"sell_bonus":
				if cash >= reserve:
					continue
				score = -float(BoardData.tile(t)["price"])
			"move_ahead", "move_anywhere":
				score = tile_score(e, pid, t)
			"move_festival":
				score = float(e.rent(t))
		if score > best_score:
			best_score = score
			best = t
	if best < 0:
		return {"action": "pass"}
	return {"action": "pick_tile", "tile": best}


## Chọn loại công trình theo tính cách và tình huống: giai đoạn ván, lượng người qua lại, giá xây.
static func choose_building(e: GameEngine, pid: int, pend: Dictionary, reserve: int) -> Dictionary:
	var cfg := EconomyConfig.get_default()
	var per := cfg.personality(e.players[pid]["character"])
	var prefs: Dictionary = per.get("build_pref", {})
	var t: int = pend["tile"]
	var price := float(BoardData.tile(t)["price"])
	var progress := clampf(float(e.round_num - 1) / maxf(1.0, e.max_rounds - 1.0), 0.0, 1.0)
	var remaining := 1.0 - progress
	# đoạn sau Kẹt Xe và sau Km 0 là nơi đông người qua lại nhất
	var busy := (t > BoardData.JAIL_TILE and t <= BoardData.JAIL_TILE + 12) or t <= 8
	var traffic := 1.0 if busy else 0.6
	var cash: int = e.players[pid]["cash"]
	var best := ""
	var best_score := -INF
	for o in pend["options"]:
		if not o["ok"] or cash - int(o["cost"]) < reserve:
			continue
		var id: String = o["id"]
		var bt := cfg.building(id)
		var s: float = bt.at(bt.rent_mult, 1)
		# giá trị kỳ vọng xấp xỉ (đơn vị: × giá đất), các hằng số rút ra từ mô phỏng
		match id:
			"restaurant":
				s *= 0.9 + 0.2 * traffic
			"homestay":
				s += bt.at(bt.lap_income, 1) * 3.5 * remaining
			"market":
				s += bt.at(bt.pass_fee, 1) * 6.0 * traffic
			"workshop":
				s += 0.3 * (0.4 + remaining)
		s -= float(o["cost"]) / price * 0.3
		s *= float(prefs.get(id, 1.0)) * e.rng.randf_range(0.9, 1.1)
		if s > best_score:
			best_score = s
			best = id
	if best == "":
		return {"action": "later"}
	return {"action": "choose", "type": best}

