extends SceneTree
## Kiểm thử nền tảng cho chơi online (lockstep):
##  1. Chơi N ván toàn bot, thỉnh thoảng chèn hành động "hết giờ" và xử thua (forfeit) như server sẽ làm.
##     Mọi hành động hết giờ phải được engine chấp nhận.
##  2. Ghi lại danh sách nước đi, đi qua JSON (như gửi qua mạng), rồi một engine MỚI cùng seed
##     chơi lại đúng danh sách đó: mã trạng thái (state_hash) phải khớp sau TỪNG nước.
## Chạy: godot --headless --path . --script res://tests/net_determinism.gd -- 150

const CHARS := ["xe_om", "tieu_thuong", "tho_ho", "ngu_dan", "doanh_nhan", "hoc_sinh", "nong_dan", "nghe_si"]


func _initialize() -> void:
	var games := 150
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		games = int(args[0])
	var trng := RandomNumberGenerator.new()
	trng.seed = 4242
	var fails := 0
	var total_moves := 0
	var timeouts := 0
	var forfeits := 0
	var finished := 0
	var t0 := Time.get_ticks_msec()
	for g in games:
		var n := 3 + g % 4
		var cfg: Array = []
		for i in n:
			cfg.append({"name": "P%d" % i, "character": CHARS[(g * 5 + i * 3) % CHARS.size()], "is_bot": true, "difficulty": (g + i) % 3})
		var seed := 100000 + g * 7
		var e := GameEngine.new()
		e.setup(cfg, seed, 25)
		var log: Array = []
		var hashes: Array = []
		var steps := 0
		while not e.game_over and steps < 20000:
			steps += 1
			var pend := e.pending
			var pid: int = pend["p"]
			var entry: Dictionary
			if trng.randf() < 0.002 and e.alive_players().size() > 2:
				e.forfeit(pid)
				forfeits += 1
				entry = {"k": "forfeit", "p": pid}
			else:
				var a: Dictionary
				if trng.randf() < 0.06:
					a = GameEngine.timeout_action(pend)
					timeouts += 1
				elif String(pend["type"]) == "auction_bid":
					a = AuctionRules.ai_decide(e, pend)
				else:
					a = BotAI.decide(e, pend)
				var before := e.state_hash()
				e.act(pid, a)
				if e.state_hash() == before:
					push_error("ván %d: engine từ chối %s cho %s" % [g, a, pend])
					fails += 1
					break
				entry = {"k": "act", "p": pid, "a": a}
			# đi qua JSON như khi truyền mạng
			log.append(NetUtil.decode(NetUtil.encode(entry)))
			hashes.append(e.state_hash())
		if e.game_over:
			finished += 1
		total_moves += log.size()
		# chơi lại
		var r := GameEngine.new()
		r.setup(cfg, seed, 25)
		for i in log.size():
			var en: Dictionary = log[i]
			if en["k"] == "forfeit":
				r.forfeit(en["p"])
			else:
				r.act(en["p"], en["a"])
			if r.state_hash() != hashes[i]:
				push_error("ván %d: LỆCH ở nước %d (%s)" % [g, i, en])
				fails += 1
				break
	print("NET_DETERMINISM games=%d finished=%d moves=%d timeouts=%d forfeits=%d fails=%d time=%dms" % [
		games, finished, total_moves, timeouts, forfeits, fails, Time.get_ticks_msec() - t0])
	quit(1 if fails > 0 else 0)
