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
		"chance_pick":
			var cards: Array = pend["cards"]
			var a: int = CardsData.CHANCE[cards[0]]["value"]
			var b: int = CardsData.CHANCE[cards[1]]["value"]
			return {"action": "pick", "index": 0 if a >= b else 1}
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
	if ty == BoardData.T.PROVINCE or ty == BoardData.T.INFRA:
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
	if ty == BoardData.T.CHANCE:
		return 15.0
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
