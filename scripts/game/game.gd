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
var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_dist := 27.0
var _drag_start := Vector2.ZERO
var _dragging := false
var _autotest := false
var season_fx: SeasonFx
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var cam_auto := true
var _cam_tween: Tween
var _cam_look_z := 1.4
var _shot_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autotest = args.has("--autotest") or args.has("--autotest-human") or args.has("--showcase")
	for a in args:
		if a.begins_with("--shot="):
			_shot_dir = a.substr(7)
	speed = 4.0 if _autotest else Global.speed

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

	engine = GameEngine.new()
	var cfg := Global.make_player_configs(args.has("--autotest") or args.has("--showcase"))
	for i in cfg.size():
		var tok := Character3D.new().setup(cfg[i]["character"], Color(PLAYER_COLORS[i]))
		add_child(tok)
		tokens.append(tok)
		token_tile.append(0)

	hud = Hud.new()
	add_child(hud)
	var events := engine.setup(cfg, 0, Global.max_rounds)
	hud.setup(engine, PLAYER_COLORS, human_id)
	hud.set_speed_display(speed)
	hud.action_chosen.connect(_on_human_action)
	hud.pick_mode.connect(_on_pick_mode)
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.speed_changed.connect(_on_speed_changed)
	hud.cam_toggled.connect(_on_cam_toggled)
	cam_auto = Global.cam_auto
	hud.set_cam_auto(cam_auto)
	Global.settings_changed.connect(_apply_settings)
	_apply_settings()
	if not _autotest:
		Audio.play_music("music_game_a")
	_relayout(true)
	hud.refresh_players()
	# Chế độ kiểm thử hình ảnh: dựng sẵn mọi danh thắng, đặt camera theo tham số
	for a in args:
		if a.begins_with("--camdist="):
			cam_dist = float(a.substr(10))
			_update_camera()
		if a.begins_with("--camlook="):
			_cam_look_z = float(a.substr(10))
			_update_camera()
		if a.begins_with("--camyaw="):
			cam_auto = false
			cam_yaw = deg_to_rad(float(a.substr(9)))
			_update_camera()
	if args.has("--showcase"):
		for t in BoardData.TILE_COUNT:
			if BoardData.is_province(t):
				board.set_tile_state(t, t % cfg.size(), 4)
	if _autotest:
		_start_autotest()
	if args.has("--showcase"):
		return
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
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.fov = 42
	cam_pivot.add_child(camera)
	_update_camera()


func _update_camera() -> void:
	cam_pivot.rotation.y = cam_yaw
	camera.position = Vector3(0, cam_dist * 0.88, cam_dist * 0.47 + (_cam_look_z - 1.4))
	camera.transform = Transform3D(Basis.looking_at(Vector3(0, 0, _cam_look_z) - camera.position, Vector3.UP), camera.position)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 1.0, 11.0, 34.0)
			_update_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 1.0, 11.0, 34.0)
			_update_camera()
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
			if _dragging:
				if cam_auto:
					_on_cam_toggled(false)
					hud.set_cam_auto(false)
				cam_yaw -= mm.relative.x * 0.006
				_update_camera()
	elif ev is InputEventMagnifyGesture:
		cam_dist = clampf(cam_dist / (ev as InputEventMagnifyGesture).factor, 11.0, 34.0)
		_update_camera()


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


## Camera tự động xoay về cạnh bàn cờ có ô t, để chữ trên ô luôn đọc xuôi chiều.
func _focus_tile(t: int) -> void:
	if not cam_auto:
		return
	var side: int = t / BoardData.SIDE
	var target: float = [0.0, -PI / 2, PI, PI / 2][side]
	var diff := wrapf(target - cam_yaw, -PI, PI)
	if absf(diff) < 0.01:
		return
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_method(func(v: float): cam_yaw = v; _update_camera(), cam_yaw, cam_yaw + diff, 0.6 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_settings() -> void:
	sun.shadow_enabled = Global.shadows
	season_fx.set_weather_enabled(Global.weather_fx)


func _season_music(s: int) -> String:
	return "music_game_a" if s <= 1 else "music_game_b"


func _on_cam_toggled(on: bool) -> void:
	cam_auto = on
	if on and engine and not engine.pending.is_empty():
		_focus_tile(token_tile[engine.pending["p"]])


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


func _move_token(pid: int, path: Array, fast: bool) -> void:
	var tok: Node3D = tokens[pid]
	var step := (0.07 if (fast or path.size() > 12) else 0.2) / speed
	for t in path:
		var target := board.tile_center(t)
		var mid := (tok.position + target) / 2.0 + Vector3(0, 0.45, 0)
		var dir := target - tok.position
		dir.y = 0
		if dir.length() > 0.01:
			tok.rotation.y = atan2(dir.x, dir.z)
		var tw := create_tween()
		tw.tween_property(tok, "position", mid, step * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tok, "position", target, step * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		if not fast or path.size() <= 12:
			Audio.play("step", 0.15, -6.0)
		token_tile[pid] = t
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
			if ev["p"] == human_id and not engine.players[human_id]["is_bot"]:
				Audio.play("turn")
			hud.set_current(ev["p"])
			hud.refresh_players()
			_focus_tile(token_tile[ev["p"]])
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
			Audio.play("dice", 0.08)
			await dice.roll(ev["d"], speed)
		"move":
			await _move_token(ev["p"], ev["path"], ev["fast"])
			_focus_tile(token_tile[ev["p"]])
		"jail":
			Audio.play("horn")
			token_tile[ev["p"]] = BoardData.JAIL_TILE
			await _relayout()
			await hud.show_toast("%s bị KẸT XE!" % engine.players[ev["p"]]["name"], 0.9 / speed)
		"tile":
			board.set_tile_state(ev["tile"], ev["owner"], ev["level"])
			if ev["owner"] >= 0 and ev["level"] < 4:
				Audio.play("buy" if ev["level"] == 0 else "build", 0.05)
			if ev["owner"] >= 0 and ev["owner"] == engine.current:
				tokens[ev["owner"]].cheer()
			await get_tree().create_timer(0.12 / speed).timeout
		"festival":
			board.set_festival(ev["tile"])
		"card":
			Audio.play("card", 0.1)
			var title := "KHÍ VẬN" if ev["deck"] == "khi_van" else "CƠ HỘI"
			await hud.show_toast("%s — %s\n\n%s" % [title, ev["name"], ev["text"]], 1.9 / speed)
		"duel":
			Audio.play("duel")
			await dice.roll([ev["ra"], ev["rb"]], speed)
			if ev["ra"] != ev["rb"]:
				tokens[ev["a"] if ev["ra"] > ev["rb"] else ev["b"]].cheer()
				tokens[ev["b"] if ev["ra"] > ev["rb"] else ev["a"]].sad()
			await hud.show_toast("ĐỤNG ĐỘ\n%s  %d – %d  %s" % [engine.players[ev["a"]]["name"], ev["ra"], ev["rb"], engine.players[ev["b"]]["name"]], 1.2 / speed)
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
	if p["is_bot"]:
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


func _on_speed_changed(s: float) -> void:
	speed = s
	Global.speed = s


func _on_human_action(action: Dictionary) -> void:
	if _busy or engine.pending.is_empty() or engine.pending["p"] != human_id:
		return
	var evs := engine.act(human_id, action)
	if evs.is_empty():
		hud.show_decision(engine.pending)
		return
	_feed(evs)


# ---------------------------------------------------------------- kiểm thử tự động

func _start_autotest() -> void:
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		var shots := 0
		while shots < 6:
			await get_tree().create_timer(5.0).timeout
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_dir.path_join("game_%d.png" % shots))
			shots += 1
		get_tree().quit()
