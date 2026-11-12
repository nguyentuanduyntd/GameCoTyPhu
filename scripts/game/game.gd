extends Node3D
## Màn chơi chính: nối GameEngine (luật) với bàn cờ 3D, quân cờ, xúc xắc và HUD.
## Engine xử lý xong ngay lập tức và trả về danh sách sự kiện; màn này diễn hoạt lần lượt từng sự kiện.

const PLAYER_COLORS := ["#e53935", "#1e88e5", "#43a047", "#fdd835", "#8e24aa", "#fb8c00"]

var engine: GameEngine
var board: BoardView
var dice: DiceView
var hud: Hud
var tokens: Array = []
var token_tile: Array = []
var human_id := 0
var speed := 1.0

var _queue: Array = []
var _busy := false
var _picking: Array = []
var cam_ctl: CameraController
var camera: Camera3D
var dice_tray: DiceTray
var _drag_start := Vector2.ZERO
var _dragging := false
var _autotest := false
var season_fx: SeasonFx
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var cinematic_on := true

## Máy trạng thái trình diễn lượt chơi. Luật vẫn do GameEngine quyết định; trạng thái này chỉ điều phối
## camera, nút bấm và hoạt ảnh, đồng thời chặn thao tác sai lúc (vd. bấm TUNG khi đang di chuyển).
enum TurnState {
	WAITING_FOR_TURN, CAMERA_TRANSITION_TO_PLAYER, WAITING_FOR_ROLL, ROLLING_DICE, SHOWING_DICE_RESULT,
	CAMERA_FOLLOWING_PAWN, MOVING_PAWN, LANDING_ANIMATION, PROCESSING_TILE, CAMERA_RETURNING, TURN_COMPLETE,
}
var turn_state: int = TurnState.WAITING_FOR_TURN
var _auction_fast := false   # người chơi thật không tham gia → các máy đấu giá nhanh, không mở panel
var _turn_player := -1
var cards_ui: CardOverlay
const CARD_STEPS := ["draw_card", "card_reveal", "card_pick"]
var _shot_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autotest = args.has("--autotest") or args.has("--autotest-human") or args.has("--showcase") or args.has("--auctiondemo") or args.has("--typeshow") or args.has("--builddemo")
	for a in args:
		if a.begins_with("--carddemo="):
			_autotest = true
	for a in args:
		if a.begins_with("--shot="):
			_shot_dir = a.substr(7)
	speed = 4.0 if _autotest else Global.speed
	for a in args:
		if a.begins_with("--speed="):
			speed = float(a.substr(8))

	_setup_environment()
	board = BoardView.new()
	add_child(board)
	board.build(PLAYER_COLORS)
	dice = DiceView.new()
	add_child(dice)
	season_fx = SeasonFx.new()
	add_child(season_fx)
	season_fx.setup(sun, env, sky_mat, BoardView.H)
	_setup_camera()
	board.building_landed.connect(_on_building_landed)

	engine = GameEngine.new()
	var cfg := Global.make_player_configs(args.has("--autotest") or args.has("--showcase") or args.has("--typeshow") or args.has("--builddemo"))
	for i in cfg.size():
		var tok := Character3D.new().setup(cfg[i]["character"], Color(PLAYER_COLORS[i]))
		add_child(tok)
		tokens.append(tok)
		token_tile.append(0)

	hud = Hud.new()
	add_child(hud)
	dice_tray = DiceTray.new()
	add_child(dice_tray)
	dice_tray.settled.connect(func():
		if turn_state == TurnState.ROLLING_DICE:
			_set_state(TurnState.SHOWING_DICE_RESULT))
	cards_ui = CardOverlay.new()
	add_child(cards_ui)
	cards_ui.draw_pressed.connect(_on_card_draw)
	cards_ui.confirm_pressed.connect(_on_card_confirm)
	var events := engine.setup(cfg, 0, Global.max_rounds)
	hud.setup(engine, PLAYER_COLORS, human_id)
	hud.set_speed_display(speed)
	hud.action_chosen.connect(_on_human_action)
	hud.pick_mode.connect(_on_pick_mode)
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.speed_changed.connect(_on_speed_changed)
	hud.cam_toggled.connect(_on_cam_toggled)
	hud.auction_panel.bid.connect(func(k): _submit_auction({"action": "bid", "steps": k}))
	hud.auction_panel.fold.connect(func(): _submit_auction({"action": "fold"}))
	cinematic_on = Global.cinematic > 0
	hud.set_cam_auto(cinematic_on)
	Global.settings_changed.connect(_apply_settings)
	_apply_settings()
	if not _autotest:
		Audio.play_music("music_game_a")
	_relayout(true)
	hud.refresh_players()
	# Chế độ kiểm thử hình ảnh: dựng sẵn mọi danh thắng, đặt camera theo tham số
	for a in args:
		if a.begins_with("--camdist="):
			cam_ctl.dist = float(a.substr(10))
		if a.begins_with("--camlook="):
			cam_ctl.set_look_z(float(a.substr(10)))
		if a.begins_with("--camyaw="):
			cam_ctl.auto_side = false
			cam_ctl.yaw = deg_to_rad(float(a.substr(9)))
			cam_ctl.orbit(0.0)
		cam_ctl.snap()
	if args.has("--typeshow"):
		# Trưng bày công trình: mỗi tỉnh một loại × cấp khác nhau, hạ tầng có chủ
		var kinds := ["generic", "restaurant", "homestay", "market", "workshop"]
		board.kind_of = func(t: int) -> String: return kinds[(t / 2) % kinds.size()]
		for t in BoardData.TILE_COUNT:
			if BoardData.is_province(t):
				board.set_tile_state(t, t % cfg.size(), 1 + t % 3, false)
			elif BoardData.is_property(t):
				board.set_tile_state(t, t % cfg.size(), 0, false)
	if args.has("--showcase"):
		for t in BoardData.TILE_COUNT:
			if BoardData.is_province(t):
				board.set_tile_state(t, t % cfg.size(), GameEngine.LANDMARK, false)
			elif BoardData.is_property(t):
				board.set_tile_state(t, t % cfg.size(), 0, false)
	if _autotest:
		_start_autotest()
	if args.has("--showcase") or args.has("--typeshow"):
		return
	if args.has("--builddemo"):
		_build_demo()
		return
	for a in args:
		if a.begins_with("--carddemo="):
			_card_demo(a.substr(11))
			return
	if args.has("--auctiondemo"):
		# Kiểm thử hình ảnh: Máy · An bỏ qua Hà Nội → đấu giá, người chơi tham gia
		engine._events = []
		AuctionRules.start(engine, BoardData.find_tile("Hà Nội"), 1)
		events.append_array(engine._events)
	_feed(events)


# ---------------------------------------------------------------- môi trường & camera

func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky_mat = sm
	sm.sky_top_color = Color("#4f8fd6")
	sm.sky_horizon_color = Color("#cde6f5")
	sm.ground_horizon_color = Color("#cde6f5")
	sm.ground_bottom_color = Color("#2f5d34")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _setup_camera() -> void:
	cam_ctl = CameraController.new()
	add_child(cam_ctl)
	cam_ctl.setup(board)
	camera = cam_ctl.camera


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_ctl.zoom(0.94)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_ctl.zoom(1.06)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = mb.position
				_dragging = false
			elif not _dragging:
				_try_pick(mb.position)
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if mm.position.distance_to(_drag_start) > 10:
				_dragging = true
			if _dragging and cam_ctl.mode == CameraController.Mode.OVERVIEW:
				cam_ctl.orbit(mm.relative.x * 0.006)
	elif ev is InputEventMagnifyGesture:
		cam_ctl.zoom(1.0 / (ev as InputEventMagnifyGesture).factor)


func _try_pick(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return
	var hit := from + dir * ((BoardView.TILE_Y - from.y) / dir.y)
	var t := board.tile_at(hit)
	if _picking.is_empty():
		if t >= 0:
			hud.show_tile_info(t)
		else:
			hud.hide_tile_info()
	elif _picking.has(t):
		hud.pick_tile(t)


## Toàn cảnh: xoay bàn cờ về cạnh chứa ô t để chữ trên ô đọc xuôi.
func _focus_tile(t: int) -> void:
	cam_ctl.face_side_of(t)


func _apply_settings() -> void:
	sun.shadow_enabled = Global.shadows
	cam_ctl.auto_side = Global.cam_auto
	season_fx.set_weather_enabled(Global.weather_fx)


func _season_music(s: int) -> String:
	return "music_game_a" if s <= 1 else "music_game_b"


## Nút "Góc nhìn": bật/tắt camera điện ảnh ngay trong ván; tắt thì lập tức về toàn cảnh.
func _on_cam_toggled(on: bool) -> void:
	cinematic_on = on
	if not on and cam_ctl.mode != CameraController.Mode.OVERVIEW:
		cam_ctl.overview(0.8)


## Tốc độ trình diễn: lượt của máy chạy nhanh hơn để ván không kéo dài.
func _pspeed(pid: int) -> float:
	return speed * (1.7 if engine.players[pid]["is_bot"] else 1.0)


## Có dùng camera điện ảnh (POV) cho lượt của người chơi pid không.
func _cinematic_for(pid: int) -> bool:
	if not cinematic_on or Global.cinematic == 0:
		return false
	return Global.cinematic == 2 or not engine.players[pid]["is_bot"]


func _set_state(st: int) -> void:
	turn_state = st


func _on_pick_mode(tiles: Array) -> void:
	_picking = tiles
	board.highlight(tiles)


# ---------------------------------------------------------------- quân cờ

func _relayout(instant: bool = false) -> void:
	var groups := {}
	for pid in tokens.size():
		if not tokens[pid].visible:
			continue
		var t: int = token_tile[pid]
		if not groups.has(t):
			groups[t] = []
		groups[t].append(pid)
	var tw: Tween = null
	for t in groups.keys():
		var ids: Array = groups[t]
		for i in ids.size():
			var target := board.slot_position(t, i, ids.size())
			var tok: Node3D = tokens[ids[i]]
			if instant:
				tok.position = target
			else:
				if tw == null:
					tw = create_tween().set_parallel(true)
				tw.tween_property(tok, "position", target, 0.15 / speed)
	if tw != null:
		await tw.finished


func _move_token(pid: int, path: Array, fast: bool, follow: bool = false) -> void:
	var tok: Character3D = tokens[pid]
	var step := (0.07 if (fast or path.size() > 12) else (0.27 if follow else 0.2)) / _pspeed(pid)
	tok.set_walking(true)
	for t in path:
		var target := board.tile_center(t)
		var mid := (tok.position + target) / 2.0 + Vector3(0, 0.35, 0)
		var dir := target - tok.position
		dir.y = 0
		if dir.length() > 0.01:
			tok.rotation.y = atan2(dir.x, dir.z)
		var tw := create_tween()
		tw.tween_property(tok, "position", mid, step * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tok, "position", target, step * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		if follow:
			cam_ctl.step_to(t)
		if not fast or path.size() <= 12:
			Audio.play("step", 0.15, -6.0)
		token_tile[pid] = t
	tok.set_walking(false)
	await _relayout()


func _float_text(pid: int, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 56
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.no_depth_test = true
	# Giữ cỡ chữ vừa mắt khi camera đang ở gần (POV / zoom ô)
	var cam_d := camera.global_position.distance_to(tokens[pid].global_position)
	l.pixel_size = 0.006 * clampf(cam_d / 22.0, 0.22, 1.0)
	l.position = tokens[pid].position + Vector3(0, 1.1, 0)
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.9, 1.1 / speed)
	tw.tween_property(l, "modulate:a", 0.0, 1.1 / speed).set_delay(0.4 / speed)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- hàng đợi sự kiện

func _feed(events: Array) -> void:
	_queue.append_array(events)
	if not _busy:
		_process_queue()


func _process_queue() -> void:
	_busy = true
	while _queue.size() > 0:
		var ev: Dictionary = _queue.pop_front()
		await _play(ev)
	_busy = false
	_after_queue()


func _play(ev: Dictionary) -> void:
	match String(ev["t"]):
		"log":
			hud.add_log(ev["text"])
		"turn":
			await _finish_turn_presentation(ev["p"])
			_set_state(TurnState.CAMERA_TRANSITION_TO_PLAYER)
			_turn_player = ev["p"]
			if ev["p"] == human_id and not engine.players[human_id]["is_bot"]:
				Audio.play("turn")
			hud.set_current(ev["p"])
			hud.refresh_players()
			_focus_tile(token_tile[ev["p"]])
			_set_state(TurnState.WAITING_FOR_TURN)
		"round":
			hud.set_round(ev["n"])
			season_fx.set_blackout(false)
		"season":
			board.set_season(ev["season"], ev["event"])
			season_fx.set_season(ev["season"], ev["event"])
			if not _autotest:
				Audio.play_music(_season_music(ev["season"]), 2.5)
			if String(ev["event"].get("type", "")) == "storm":
				Audio.play("thunder")
			hud.set_season(ev["season"], ev["event"])
		"cash":
			hud.set_cash(ev["p"], ev["cash"])
			Audio.play("coin" if int(ev["delta"]) > 0 else "pay", 0.05, -4.0)
			var d: int = ev["delta"]
			_float_text(ev["p"], ("+" if d > 0 else "") + BoardData.money(d), Color("#76ff03") if d > 0 else Color("#ff5252"))
		"dice":
			# Giá trị lấy nguyên từ engine: mâm xúc xắc chỉ diễn lại, quân cờ đi đúng số này
			_set_state(TurnState.ROLLING_DICE)
			hud.hide_roll()
			hud.set_focus(true)
			await dice_tray.roll(ev["d"], _pspeed(ev["p"]))
			dice.show_values(ev["d"])
			_set_state(TurnState.PROCESSING_TILE)
		"move":
			await _present_move(ev["p"], ev["path"], ev["fast"])
		"jail":
			Audio.play("horn")
			token_tile[ev["p"]] = BoardData.JAIL_TILE
			await _relayout()
			if cam_ctl.mode != CameraController.Mode.OVERVIEW:
				cam_ctl.focus(BoardData.JAIL_TILE, 0.6 / speed)
			await hud.show_toast("%s bị KẸT XE!" % engine.players[ev["p"]]["name"], 0.9 / speed)
		"tile":
			var t_ev: int = ev["tile"]
			var grew: bool = ev["owner"] >= 0 and (ev["level"] > board._shown_level[t_ev] or ev["owner"] != board._shown_owner[t_ev])
			var new_owner: bool = ev["owner"] >= 0 and ev["owner"] != board._shown_owner[t_ev]
			board.anim_speed = speed
			board.set_tile_state(t_ev, ev["owner"], ev["level"])
			if new_owner:
				Audio.play("buy_keng", 0.05, -2.0)
			if ev["owner"] >= 0 and ev["owner"] == engine.current:
				tokens[ev["owner"]].cheer()
			# chờ công trình mọc xong rồi mới sang sự kiện tiếp theo
			await get_tree().create_timer((0.55 if grew and (ev["level"] > 0 or not BoardData.is_province(t_ev)) else 0.15) / speed).timeout
		"festival":
			board.set_festival(ev["tile"])
		"card":
			pass
		"auction_start":
			var human_in: bool = (ev["bidders"] as Array).has(human_id) and not engine.players[human_id]["is_bot"]
			_auction_fast = not human_in
			hud.clear_decision()
			hud.hide_roll()
			Audio.play("auction_bid", 0.0, -2.0)
			if _auction_fast:
				hud.show_banner("Đấu giá %s giữa các máy..." % BoardData.plain_name(ev["tile"]), 1.2 / speed)
			else:
				hud.auction_panel.open(ev)
				await get_tree().create_timer(0.35 / speed).timeout
		"auction_bid":
			Audio.play("auction_bid", 0.1, -4.0)
			if hud.auction_panel.visible:
				hud.auction_panel.on_bid(ev["p"], ev["price"])
				await get_tree().create_timer((0.12 if _auction_fast else 0.25) / speed).timeout
		"auction_fold":
			if hud.auction_panel.visible:
				hud.auction_panel.on_fold(ev["p"], ev["reason"])
				await get_tree().create_timer((0.08 if _auction_fast else 0.2) / speed).timeout
		"auction_end":
			var w: int = ev["winner"]
			if hud.auction_panel.visible:
				hud.auction_panel.show_result(w, ev["price"])
			if w >= 0:
				Audio.play("auction_win")
				tokens[w].cheer()
				hud.show_banner("THẮNG ĐẤU GIÁ!  %s — %s · %s xu" % [engine.players[w]["name"], BoardData.plain_name(ev["tile"]), BoardData.money(ev["price"])], 1.6 / speed)
			else:
				hud.show_banner("Không ai mua %s — ô vẫn trống" % BoardData.plain_name(ev["tile"]), 1.2 / speed)
			if hud.auction_panel.visible:
				await get_tree().create_timer(1.0 / speed).timeout
				hud.auction_panel.close()
			_auction_fast = false
		"card_drawn":
			await cards_ui.play_draw(ev["cards"])
		"duel":
			Audio.play("duel")
			var na: String = engine.players[ev["a"]]["name"]
			var nb: String = engine.players[ev["b"]]["name"]
			await dice_tray.roll([ev["ra"], ev["rb"]], speed, "ĐỤNG ĐỘ: %s  vs  %s" % [na, nb])
			if ev["ra"] != ev["rb"]:
				tokens[ev["a"] if ev["ra"] > ev["rb"] else ev["b"]].cheer()
				tokens[ev["b"] if ev["ra"] > ev["rb"] else ev["a"]].sad()
		"swap":
			var ta: int = token_tile[ev["a"]]
			token_tile[ev["a"]] = token_tile[ev["b"]]
			token_tile[ev["b"]] = ta
			await _relayout()
		"pot":
			board.set_pot(ev["amount"])
			hud.set_pot(ev["amount"])
		"charity":
			await hud.show_toast("%s nhận Quỹ Từ Thiện\n%s xu!" % [engine.players[ev["p"]]["name"], BoardData.money(ev["amount"])], 1.3 / speed)
		"blackout":
			season_fx.set_blackout(true)
			await hud.show_toast("CÚP ĐIỆN DIỆN RỘNG\nTiền thuê toàn bàn −50% đến hết vòng", 1.3 / speed)
		"lottery":
			var txt := "Xổ số: chọn %d — ra %d\n%s" % [ev["number"], ev["roll"], "TRÚNG LỚN!" if ev["win"] else "Trượt rồi!"]
			await hud.show_toast(txt, 1.3 / speed)
		"landmark":
			Audio.play("landmark")
			Audio.play("firework", 0.1, -3.0)
			season_fx.fireworks()
			await hud.show_toast("DANH THẮNG\n%s" % BoardData.tile(ev["tile"])["landmark"], 1.3 / speed)
		"takeover":
			Audio.play("takeover")
			await hud.show_toast("THÂU TÓM %s!" % BoardData.plain_name(ev["tile"]).to_upper(), 1.0 / speed)
		"card_gain":
			_float_text(ev["p"], "+ " + String(CardsData.SKILLS[ev["card"]]["name"]), Color("#40c4ff"))
		"specialty":
			_float_text(ev["p"], "+ " + String(BoardData.tile(ev["tile"])["specialty"]), Color("#ffd740"))
		"bankrupt":
			tokens[ev["p"]].sad()
			Audio.play("bankrupt")
			await hud.show_toast("%s PHÁ SẢN!" % engine.players[ev["p"]]["name"], 1.3 / speed)
			tokens[ev["p"]].visible = false
			hud.refresh_players()
		"toll":
			Audio.play("toll")
		"charity":
			Audio.play("win", 0.0, -6.0)
		"game_over":
			cam_ctl.overview(1.2)
			hud.hide_roll()
			hud.set_focus(false)
			Audio.stop_music(0.8)
			Audio.play("win")
			tokens[ev["winner"]].cheer()
			hud.refresh_players()
			board.update_info(engine)
			hud.show_game_over(ev)


func _after_queue() -> void:
	board.update_info(engine)
	hud.refresh_players()
	if engine.game_over:
		return
	var pend := engine.pending
	if pend.is_empty():
		return
	var p: Dictionary = engine.players[pend["p"]]
	if CARD_STEPS.has(String(pend["type"])):
		await _card_step(pend, p)
		return
	if pend["type"] == "auction_bid":
		await _auction_step(pend, p)
		return
	if pend["type"] == "turn":
		_set_state(TurnState.WAITING_FOR_ROLL)
		hud.set_focus(false)
	if p["is_bot"]:
		if pend["type"] == "turn":
			hud.show_roll_waiting(p["name"])
		else:
			hud.show_waiting("%s đang suy nghĩ..." % p["name"])
		await get_tree().create_timer(0.45 / speed).timeout
		if engine.pending != pend:
			return
		var a := BotAI.decide(engine, pend)
		hud.show_waiting("")
		_feed(engine.act(pend["p"], a))
	else:
		hud.show_decision(pend)
		if _autotest:
			await get_tree().create_timer(0.6).timeout
			hud.autotest_click()


## Đấu giá: người chơi thật trả giá qua panel (có đồng hồ), máy "cân nhắc" một chút rồi quyết định.
func _auction_step(pend: Dictionary, p: Dictionary) -> void:
	hud.show_waiting("")
	if not p["is_bot"]:
		var cfg := EconomyConfig.get_default()
		var secs := maxf(cfg.auction_human_min_seconds, cfg.auction_human_seconds / speed)
		hud.auction_panel.prompt(pend, secs)
		if _autotest and not OS.get_cmdline_user_args().has("--auctiondemo"):
			await get_tree().create_timer(0.5).timeout
			hud.auction_panel.autopress()
		return
	if hud.auction_panel.visible:
		hud.auction_panel.on_thinking(pend["p"])
	var delay := 0.08 if _auction_fast else randf_range(0.35, 0.9)
	await get_tree().create_timer(delay / speed).timeout
	if engine.pending != pend:
		return
	_feed(engine.act(pend["p"], BotAI.decide(engine, pend)))


func _submit_auction(action: Dictionary) -> void:
	if _busy or engine.pending.is_empty() or engine.pending["type"] != "auction_bid" or engine.pending["p"] != human_id:
		return
	var evs := engine.act(human_id, action)
	if not evs.is_empty():
		_feed(evs)


## Bộ bài Khí Vận / Cơ Hội: khoá lượt cho tới khi người chơi rút bài và bấm XÁC NHẬN.
func _card_step(pend: Dictionary, p: Dictionary) -> void:
	hud.clear_decision()
	hud.show_waiting("")
	var human: bool = not p["is_bot"]
	match String(pend["type"]):
		"draw_card":
			if not cards_ui.is_open:
				await cards_ui.open(pend["deck"], p["name"], speed)
			if human:
				cards_ui.show_draw_button()
				if _autotest:
					await get_tree().create_timer(0.5).timeout
					cards_ui.autopress()
			else:
				await get_tree().create_timer(0.5 / speed).timeout
				_submit_card({"action": "draw"})
		"card_reveal", "card_pick":
			var count: int = 2 if pend["type"] == "card_pick" else 1
			if human:
				cards_ui.show_confirm(count)
				if _autotest:
					await get_tree().create_timer(0.6).timeout
					cards_ui.autopress()
			else:
				await get_tree().create_timer(0.9 / speed).timeout
				var a := BotAI.decide(engine, pend)
				await cards_ui.close(int(a.get("index", 0)))
				_submit_card(a)


## Kiểm thử hình ảnh bộ bài: --carddemo=<khi_van|co_hoi>:<chỉ số lá>[:<chỉ số lá 2>] --shot=<thư mục>
func _card_demo(spec: String) -> void:
	var parts := spec.split(":")
	var ids: Array = []
	for i in range(1, parts.size()):
		ids.append(int(parts[i]))
	await get_tree().create_timer(0.5).timeout
	await cards_ui.open(parts[0], "Bạn", 1.0)
	_demo_shot("card_1_open")
	cards_ui.show_draw_button()
	await get_tree().create_timer(0.4).timeout
	_demo_shot("card_2_button")
	cards_ui.autopress()
	cards_ui.play_draw(ids)
	await get_tree().create_timer(0.75).timeout
	_demo_shot("card_3_shuffle")
	await get_tree().create_timer(1.9).timeout
	_demo_shot("card_4_reveal")
	await get_tree().create_timer(1.6).timeout
	cards_ui.show_confirm(ids.size())
	await get_tree().create_timer(0.5).timeout
	_demo_shot("card_5_confirm")
	get_tree().quit()


## Kiểm thử hoạt ảnh xây dựng: mua → cấp 1 → cấp 2 → Danh Thắng → bị hạ cấp, chụp ảnh từng pha.
func _build_demo() -> void:
	cam_ctl.focus(5, 0.01)
	board.kind_of = func(_t: int) -> String: return "restaurant"
	var steps := [[0, 0.5], [1, 0.25], [2, 0.25], [3, 0.25], [2, 0.25]]
	var k := 0
	await get_tree().create_timer(1.2).timeout
	for st in steps:
		board.anim_speed = 1.0
		board.set_tile_state(5, 0, st[0])
		await get_tree().create_timer(st[1]).timeout
		_demo_shot("build_%d_mid" % k)
		await get_tree().create_timer(0.9).timeout
		_demo_shot("build_%d_done" % k)
		k += 1
	get_tree().quit()


func _demo_shot(name: String) -> void:
	if _shot_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(name + ".png"))


func _on_card_draw() -> void:
	_submit_card({"action": "draw"})


func _on_card_confirm(index: int) -> void:
	var pend := engine.pending
	if pend.is_empty() or not CARD_STEPS.has(String(pend["type"])):
		return
	await cards_ui.close(index)
	if pend["type"] == "card_pick":
		_submit_card({"action": "pick", "index": index})
	else:
		_submit_card({"action": "confirm"})


## Gửi hành động của bước rút bài; engine kiểm tra hợp lệ nên hiệu ứng chỉ áp dụng đúng một lần.
func _submit_card(action: Dictionary) -> void:
	if _busy or engine.pending.is_empty() or not CARD_STEPS.has(String(engine.pending["type"])):
		return
	var evs := engine.act(engine.pending["p"], action)
	if not evs.is_empty():
		_feed(evs)


## Di chuyển quân cờ: với camera điện ảnh thì chuyển cảnh xuống POV, bám theo từng bước,
## dừng lại zoom vào ô đích và hiện thông tin ô; còn lại đi trong góc nhìn toàn cảnh.
func _present_move(pid: int, path: Array, fast: bool) -> void:
	if path.is_empty():
		return
	var start: int = token_tile[pid]
	var backward: bool = path[0] == posmod(start - 1, BoardData.TILE_COUNT)
	var follow := _cinematic_for(pid) and not fast and not backward and path.size() <= 14
	var last: int = path[path.size() - 1]
	var sp := _pspeed(pid)
	if follow:
		_set_state(TurnState.CAMERA_FOLLOWING_PAWN)
		cam_ctl.follow(tokens[pid], start, 0.85 / sp)
		await get_tree().create_timer(0.5 / sp).timeout
		_set_state(TurnState.MOVING_PAWN)
		await _move_token(pid, path, fast, true)
		_set_state(TurnState.LANDING_ANIMATION)
		(tokens[pid] as Character3D).land()
		cam_ctl.impact(0.05)
		cam_ctl.focus(last, 0.7 / sp)
		hud.show_banner(hud.tile_summary(last), 1.8 / sp)
		await get_tree().create_timer(0.55 / sp).timeout
	else:
		_set_state(TurnState.MOVING_PAWN)
		await _move_token(pid, path, fast)
		(tokens[pid] as Character3D).land()
		_focus_tile(last)
		if not fast:
			hud.show_banner(hud.tile_summary(last), 1.4 / sp)
	_set_state(TurnState.PROCESSING_TILE)


## Kết thúc phần trình diễn của lượt trước: camera nâng lên, lùi về toàn cảnh, báo hoàn thành lượt.
func _finish_turn_presentation(next_pid: int) -> void:
	if _turn_player < 0:
		return
	_set_state(TurnState.CAMERA_RETURNING)
	hud.set_focus(false)
	if cam_ctl.mode != CameraController.Mode.OVERVIEW:
		cam_ctl.face_side_of(token_tile[next_pid])
		cam_ctl.overview(1.1 / speed)
		await get_tree().create_timer(0.45 / speed).timeout
	_set_state(TurnState.TURN_COMPLETE)
	var prev: Dictionary = engine.players[_turn_player]
	if _turn_player == human_id and not prev["is_bot"] and prev["alive"]:
		hud.show_banner("Được tung tiếp!" if next_pid == _turn_player else "Hoàn thành lượt!", 1.0 / speed)


func _on_building_landed(_t: int, strength: float) -> void:
	if strength >= 0.5:
		Audio.play("hammer", 0.1, -3.0 if strength >= 0.9 else -7.0)
		cam_ctl.impact(0.03 * strength)


func _on_speed_changed(s: float) -> void:
	speed = s
	Global.speed = s


func _on_human_action(action: Dictionary) -> void:
	if _busy or engine.pending.is_empty() or engine.pending["p"] != human_id:
		return
	# Chỉ được tung khi đang chờ tung — chặn bấm lặp hoặc bấm lúc đang di chuyển/xử lý ô
	var kind: String = action.get("action", "")
	var is_turn_roll: bool = engine.pending["type"] == "turn" and (kind == "roll" or kind == "golden")
	if is_turn_roll and turn_state != TurnState.WAITING_FOR_ROLL:
		return
	if is_turn_roll:
		_set_state(TurnState.ROLLING_DICE)
	var evs := engine.act(human_id, action)
	if evs.is_empty():
		hud.show_decision(engine.pending)
		return
	_feed(evs)


# ---------------------------------------------------------------- kiểm thử tự động

func _exit_tree() -> void:
	if _autotest and engine:
		print("AUTOTEST round=%d game_over=%s state=%d pending=%s cache=%s fps=%d" % [engine.round_num, engine.game_over, turn_state, engine.pending.get("type", "-"), MeshCache.stats(), Engine.get_frames_per_second()])


func _start_autotest() -> void:
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		var shots := 0
		var total := 6
		var every := 5.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				total = int(a.substr(8))
			if a.begins_with("--every="):
				every = float(a.substr(8))
		while shots < total:
			await get_tree().create_timer(every).timeout
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_dir.path_join("game_%02d.png" % shots))
			shots += 1
		get_tree().quit()
