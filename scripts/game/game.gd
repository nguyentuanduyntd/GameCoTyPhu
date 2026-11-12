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
var _shot_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autotest = args.has("--autotest") or args.has("--autotest-human")
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
	_setup_camera()

	engine = GameEngine.new()
	var cfg := Global.make_player_configs(args.has("--autotest"))
	for i in cfg.size():
		var tok := _make_token(Color(PLAYER_COLORS[i]), cfg[i]["character"])
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
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.speed_changed.connect(_on_speed_changed)
	_relayout(true)
	hud.refresh_players()
	if _autotest:
		_start_autotest()
	_feed(events)


# ---------------------------------------------------------------- môi trường & camera

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
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
	var sun := DirectionalLight3D.new()
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
	camera.position = Vector3(0, cam_dist * 0.88, cam_dist * 0.47)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1.4) - camera.position, Vector3.UP), camera.position)


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
				cam_yaw -= mm.relative.x * 0.006
				_update_camera()
	elif ev is InputEventMagnifyGesture:
		cam_dist = clampf(cam_dist / (ev as InputEventMagnifyGesture).factor, 11.0, 34.0)
		_update_camera()


func _try_pick(screen: Vector2) -> void:
	if _picking.is_empty():
		return
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return
	var hit := from + dir * ((BoardView.TILE_Y - from.y) / dir.y)
	var t := board.tile_at(hit)
	if _picking.has(t):
		hud.pick_tile(t)


func _on_pick_mode(tiles: Array) -> void:
	_picking = tiles
	board.highlight(tiles)


# ---------------------------------------------------------------- quân cờ

func _make_token(col: Color, character: String) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.16
	cm.height = 0.55
	body.mesh = cm
	body.position.y = 0.28
	body.material_override = _mat(col)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.26
	head.mesh = hm
	head.position.y = 0.66
	head.material_override = _mat(Color("#ffcc99"))
	root.add_child(head)
	# Nón lá cho mọi nhân vật — mũ bảo hiểm cho anh xe ôm
	var hat := MeshInstance3D.new()
	var hat_mesh := CylinderMesh.new()
	if character == "xe_om":
		hat_mesh.top_radius = 0.1
		hat_mesh.bottom_radius = 0.15
		hat_mesh.height = 0.1
		hat.material_override = _mat(Color("#212121"))
		hat.position.y = 0.76
	else:
		hat_mesh.top_radius = 0.0
		hat_mesh.bottom_radius = 0.24
		hat_mesh.height = 0.13
		hat.material_override = _mat(Color("#e8d39a"))
		hat.position.y = 0.8
	hat.mesh = hat_mesh
	root.add_child(hat)
	return root


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	return m


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
			hud.set_current(ev["p"])
			hud.refresh_players()
		"round":
			hud.set_round(ev["n"])
		"season":
			board.set_season(ev["season"], ev["event"])
			hud.set_season(ev["season"], ev["event"])
		"cash":
			hud.set_cash(ev["p"], ev["cash"])
			var d: int = ev["delta"]
			_float_text(ev["p"], ("+" if d > 0 else "") + BoardData.money(d), Color("#76ff03") if d > 0 else Color("#ff5252"))
		"dice":
			await dice.roll(ev["d"], speed)
		"move":
			await _move_token(ev["p"], ev["path"], ev["fast"])
		"jail":
			token_tile[ev["p"]] = BoardData.JAIL_TILE
			await _relayout()
			await hud.show_toast("%s bị KẸT XE!" % engine.players[ev["p"]]["name"], 0.9 / speed)
		"tile":
			board.set_tile_state(ev["tile"], ev["owner"], ev["level"])
			await get_tree().create_timer(0.12 / speed).timeout
		"festival":
			board.set_festival(ev["tile"])
		"card":
			var title := "KHÍ VẬN" if ev["deck"] == "khi_van" else "CƠ HỘI"
			await hud.show_toast("%s — %s\n\n%s" % [title, ev["name"], ev["text"]], 1.9 / speed)
		"duel":
			await dice.roll([ev["ra"], ev["rb"]], speed)
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
			await hud.show_toast("CÚP ĐIỆN DIỆN RỘNG\nTiền thuê toàn bàn −50% đến hết vòng", 1.3 / speed)
		"lottery":
			var txt := "Xổ số: chọn %d — ra %d\n%s" % [ev["number"], ev["roll"], "TRÚNG LỚN!" if ev["win"] else "Trượt rồi!"]
			await hud.show_toast(txt, 1.3 / speed)
		"landmark":
			await hud.show_toast("DANH THẮNG\n%s" % BoardData.tile(ev["tile"])["landmark"], 1.3 / speed)
		"takeover":
			await hud.show_toast("THÂU TÓM %s!" % BoardData.plain_name(ev["tile"]).to_upper(), 1.0 / speed)
		"card_gain":
			_float_text(ev["p"], "+ " + String(CardsData.SKILLS[ev["card"]]["name"]), Color("#40c4ff"))
		"specialty":
			_float_text(ev["p"], "+ " + String(BoardData.tile(ev["tile"])["specialty"]), Color("#ffd740"))
		"bankrupt":
			await hud.show_toast("%s PHÁ SẢN!" % engine.players[ev["p"]]["name"], 1.3 / speed)
			tokens[ev["p"]].visible = false
			hud.refresh_players()
		"game_over":
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
