extends SceneTree
## Mô phỏng nhiều ván toàn bot để kiểm tra luật và cân bằng.
## Chạy: godot --headless --path . --script res://tests/sim.gd -- [số_ván]

func _init() -> void:
	var games := 300
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		games = int(args[0])
	var chars: Array = []
	for c in CardsData.CHARACTERS:
		chars.append(c["id"])
	var reasons := {}
	var char_wins := {}
	var char_games := {}
	var diff_wins := [0, 0, 0]
	var total_rounds := 0
	var total_actions := 0
	var bankrupt_total := 0
	var errors := 0
	var pot_total := 0
	var auctions := 0
	var auctions_sold := 0
	var auction_ratio := 0.0
	var auction_wins := {}
	var auction_bids := {}
	var t0 := Time.get_ticks_msec()
	for g in games:
		var e := GameEngine.new()
		var n := 4 + g % 3
		var cfg: Array = []
		for i in n:
			var ch: String = chars[(g * 7 + i * 3) % chars.size()]
			cfg.append({"name": "Bot%d" % i, "character": ch, "is_bot": true, "difficulty": (g + i) % 3})
			char_games[ch] = char_games.get(ch, 0) + 1
		e.setup(cfg, g + 1, 25)
		var steps := 0
		while not e.game_over and steps < 20000:
			var pend := e.pending
			var a := BotAI.decide(e, pend)
			var cash_before: Array = []
			for pl in e.players:
				cash_before.append(int(pl["cash"]))
			var ev := e.act(pend["p"], a)
			for x in ev:
				if x["t"] == "auction_end":
					auctions += 1
					if int(x["winner"]) >= 0:
						auctions_sold += 1
						auction_ratio += float(x["price"]) / float(BoardData.tile(x["tile"])["price"])
						var wc: String = e.players[x["winner"]]["character"]
						auction_wins[wc] = auction_wins.get(wc, 0) + 1
				elif x["t"] == "auction_bid":
					var bc: String = e.players[x["p"]]["character"]
					auction_bids[bc] = auction_bids.get(bc, 0) + 1
					if int(x["price"]) > cash_before[x["p"]]:
						errors += 1
						printerr("Ván %d: trả giá vượt số tiền có" % g)
			if ev.is_empty():
				errors += 1
				printerr("Hành động không hợp lệ ván %d: %s cho %s" % [g, a, pend])
				break
			steps += 1
			_check_invariants(e, g)
		total_actions += steps
		if not e.game_over:
			errors += 1
			printerr("Ván %d không kết thúc!" % g)
			continue
		reasons[e.win_reason] = reasons.get(e.win_reason, 0) + 1
		total_rounds += mini(e.round_num, e.max_rounds)
		bankrupt_total += e.eliminated.size()
		pot_total += e.charity_pot
		var wch: String = e.players[e.winner]["character"]
		char_wins[wch] = char_wins.get(wch, 0) + 1
		diff_wins[e.players[e.winner]["difficulty"]] += 1
	print("=== %d ván, %d ms ===" % [games, Time.get_ticks_msec() - t0])
	print("Lỗi: %d" % errors)
	print("Lý do thắng: %s" % reasons)
	print("Số vòng TB: %.1f | Hành động TB: %.0f | Phá sản TB/ván: %.2f" % [float(total_rounds) / games, float(total_actions) / games, float(bankrupt_total) / games])
	print("Quỹ Từ Thiện cuối ván TB: %.0f" % (float(pot_total) / games))
	print("Đấu giá: %d cuộc (%.1f/ván), bán được %.0f%%, giá chốt TB %.0f%% giá niêm yết" % [auctions, float(auctions) / games, 100.0 * auctions_sold / maxi(1, auctions), 100.0 * auction_ratio / maxi(1, auctions_sold)])
	for ch in chars:
		print("  %-12s thắng đấu giá %3d, số lần trả giá %4d" % [ch, auction_wins.get(ch, 0), auction_bids.get(ch, 0)])
	print("Thắng theo độ khó (Dễ/Thường/Khó): %s" % [diff_wins])
	for ch in chars:
		print("  %-12s thắng %3d / %3d lượt tham gia (%.1f%%)" % [ch, char_wins.get(ch, 0), char_games.get(ch, 0), 100.0 * char_wins.get(ch, 0) / maxi(1, char_games.get(ch, 0))])
	quit(1 if errors > 0 else 0)


func _check_invariants(e: GameEngine, g: int) -> void:
	for p in e.players:
		if p["alive"] and p["cash"] < 0:
			printerr("Ván %d: %s âm tiền %d" % [g, p["name"], p["cash"]])
	for t in BoardData.TILE_COUNT:
		if e.owner[t] >= 0 and not e.players[e.owner[t]]["alive"]:
			printerr("Ván %d: ô %d thuộc người đã phá sản" % [g, t])
		if e.level[t] < 0 or e.level[t] > 4:
			printerr("Ván %d: cấp nhà sai ô %d" % [g, t])
