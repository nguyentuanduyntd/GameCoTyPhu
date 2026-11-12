extends Node3D
## Màn chơi chính: nối GameEngine (luật) với bàn cờ 3D, quân cờ, xúc xắc và HUD.
## Engine xử lý xong ngay lập tức và trả về danh sách sự kiện; màn này diễn hoạt lần lượt từng sự kiện.

const PLAYER_COLORS := ["#e53935", "#1e88e5", "#43a047", "#fdd835", "#8e24aa", "#fb8c00"]

var engine: GameEngine
var board: BoardView
var dice: DiceView
var hud: Hud
var tokens: Array = []
var _slot_tws := {}          # pid -> Tween xếp chỗ đang chạy (huỷ trước khi tạo mới, không chồng)
var _moving_pid := -1        # quân đang nhảy trên đường đi (không chiếm chỗ ở các ô đi ngang)
var motion: PawnMotion
var token_tile: Array = []
var human_id := 0
var speed := 1.0

var _queue: Array = []
var _busy := false
# ---- online (lockstep): nước đi đến từ server theo số thứ tự, áp vào engine rồi diễn như thường
var online := false
var _applied := 0            # số nước đã áp dụng
var _inbox: Array = []       # nước đi nhận được nhưng chưa áp (đang bận diễn)
var _stepping := false       # đang trong bước chuẩn bị quyết định (mở bộ bài...) → chưa áp nước mới
var _room_code := ""
var _reconnect_t := -1.0
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
var juice: BuyJuice
var _in_auction := false
var _groups_done := {}
var _auction_fast := false   # người chơi thật không tham gia → các máy đấu giá nhanh, không mở panel
var _turn_player := -1
var cards_ui: CardOverlay
const CARD_STEPS := ["draw_card", "card_reveal", "card_pick"]
var _shot_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autotest = args.has("--autotest") or args.has("--autotest-human") or args.has("--showcase") or args.has("--auctiondemo") or args.has("--typeshow") or args.has("--builddemo") or args.has("--pickerdemo") or args.has("--juicedemo") or args.has("--motiondemo") or args.has("--netbot")
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
	motion = PawnMotion.new()
	add_child(motion)
	online = Global.online and not Net.start_info.is_empty()
	var cfg: Array
	var seed := 0
	var rounds := Global.max_rounds
	if online:
		cfg = Net.start_info["configs"]
		seed = int(Net.start_info["seed"])
		rounds = int(Net.start_info["rounds"])
		human_id = int(Net.start_info["seat"])
		_room_code = String(Net.room.get("code", _room_code))
	else:
		cfg = Global.make_player_configs(args.has("--autotest") or args.has("--showcase") or args.has("--typeshow") or args.has("--builddemo") or args.has("--juicedemo"))
	for i in cfg.size():
		var tok := Character3D.new().setup(cfg[i]["character"], Color(PLAYER_COLORS[i]))
		add_child(tok)
		tok.anim_speed = speed
		tokens.append(tok)
		token_tile.append(0)

	hud = Hud.new()
	add_child(hud)
	dice_tray = DiceTray.new()
	add_child(dice_tray)
	juice = BuyJuice.new()
	add_child(juice)
	juice.setup(board, cam_ctl, hud)
	juice.speed = speed
	dice_tray.settled.connect(func():
		if turn_state == TurnState.ROLLING_DICE:
			_set_state(TurnState.SHOWING_DICE_RESULT))
	cards_ui = CardOverlay.new()
	add_child(cards_ui)
	cards_ui.draw_pressed.connect(_on_card_draw)
	cards_ui.confirm_pressed.connect(_on_card_confirm)
	var events := engine.setup(cfg, seed, rounds)
	hud.online = online
	hud.setup(engine, PLAYER_COLORS, human_id)
	hud.set_speed_display(speed)
	hud.action_chosen.connect(_on_human_action)
	hud.pick_mode.connect(_on_pick_mode)
	hud.menu_requested.connect(_leave_to_lobby)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.speed_changed.connect(_on_speed_changed)
	hud.cam_toggled.connect(_on_cam_toggled)
	hud.auction_panel.bid.connect(func(k): _submit_auction({"action": "bid", "steps": k}))
	hud.auction_panel.fold.connect(func(): _submit_auction({"action": "fold"}))
	hud.building_picker.chosen.connect(func(id): _submit_choice({"action": "choose", "type": id}))
	hud.building_picker.later.connect(func(): _submit_choice({"action": "later"}))
	hud.decision_popup.avoid_point = _pending_screen_point
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
	if online:
		if _autotest:
			_start_autotest()
		_online_begin(events)
		return
	if _autotest:
		_start_autotest()
	if args.has("--showcase") or args.has("--typeshow"):
		return
	if args.has("--builddemo"):
		_build_demo()
		return
	if args.has("--juicedemo"):
		_juice_demo()
		return
	if args.has("--motiondemo"):
		_motion_demo()
		return
	for a in args:
		if a.begins_with("--carddemo="):
			_card_demo(a.substr(11))
			return
	if args.has("--pickerdemo"):
		# Kiểm thử hình ảnh: bạn vừa sở hữu Hà Nội → chọn loại công trình
		engine._events = []
		engine._set_tile(BoardData.find_tile("Hà Nội"), human_id, 0)
		engine.offer_building_choice(human_id, BoardData.find_tile("Hà Nội"))
		events.append_array(engine._events)
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
	# mặt đất của bầu trời trùng màu nền cỏ ở xa (ground.gdshader far_color) → không thấy đường nối
	sm.ground_horizon_color = Color(0.62, 0.74, 0.58)
	sm.ground_bottom_color = Color(0.45, 0.6, 0.4)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	# ánh sáng môi trường: lấy từ trời, pha thêm tông ấm cho hợp màu giao diện gỗ/giấy
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.8
	env.ambient_light_color = Color("#ffe8c8")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0
	# glow nhẹ: công trình/danh thắng phát sáng, nắng lấp lánh trên nước
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4                     # bóng mềm
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


func _setup_camera() -> void:
	cam_ctl = CameraController.new()
	add_child(cam_ctl)
	cam_ctl.setup(board)
	camera = cam_ctl.camera


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and OS.is_debug_build():
		_debug_key((ev as InputEventKey).keycode)
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
	var q := Global.graphics_quality
	sun.shadow_enabled = Global.shadows and q > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	env.glow_enabled = q >= 1
	env.adjustment_enabled = q >= 1
	board.set_quality(q)
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

## Các quân (còn hiện) đang đứng ở ô `tile`, sắp theo id; `include` luôn được tính (quân sắp tới ô).
func _ids_on(tile: int, include: int = -1) -> Array:
	var ids: Array = []
	for q in tokens.size():
		if q == include or (tokens[q].visible and token_tile[q] == tile and q != _moving_pid):
			ids.append(q)
	return ids


## Đưa mọi quân về đúng chỗ đứng trong ô của mình (nhảy ngắn; đi xa thì cung nhảy cao hơn).
## `skip`: quân không bị đụng tới (vẫn được tính chỗ). Mỗi quân chỉ có một tween xếp chỗ tại một thời điểm.
func _relayout(instant: bool = false, skip: int = -1) -> void:
	var longest: Tween = null
	var longest_d := -1.0
	for pid in tokens.size():
		if pid == skip or pid == _moving_pid or not tokens[pid].visible:
			continue
		var t: int = token_tile[pid]
		var ids := _ids_on(t, pid)
		var target := board.slot_position(t, ids.find(pid), ids.size())
		var tok: Character3D = tokens[pid]
		if instant:
			var old: Tween = _slot_tws.get(pid)
			if old and old.is_valid():
				old.kill()
			tok.position = target
			tok.ground_y = target.y
			continue
		var d := tok.position.distance_to(target)
		if d < 0.01:
			continue
		var tw := PawnMotion.shuffle_to(tok, target, 0.2 / speed, _slot_tws.get(pid))
		_slot_tws[pid] = tw
		if d > longest_d:
			longest_d = d
			longest = tw
	# chờ bằng vòng lặp (tween có thể bị huỷ bởi lần xếp chỗ sau → không treo)
	while longest and longest.is_valid() and longest.is_running():
		await get_tree().process_frame


func _move_token(pid: int, path: Array, fast: bool, follow: bool = false) -> void:
	if path.is_empty():
		return
	var tok: Character3D = tokens[pid]
	var quick := fast or path.size() > 12
	var step := (0.09 if quick else (0.3 if follow else 0.24)) / _pspeed(pid)
	var old: Tween = _slot_tws.get(pid)
	if old and old.is_valid():
		old.kill()
	var dest: int = path[path.size() - 1]
	var points: Array = []
	for t in path:
		points.append(board.tile_center(t))
	# đáp thẳng vào chỗ đứng cuối cùng trong ô đích (không trượt sau khi đáp)
	_moving_pid = pid
	var ids := _ids_on(dest, pid)
	points[points.size() - 1] = board.slot_position(dest, ids.find(pid), ids.size())
	tok.anim_speed = _pspeed(pid)
	var st := {"left": false}
	await motion.hop_path(tok, points, step, func(i: int):
		var t: int = path[i]
		token_tile[pid] = t
		if follow:
			cam_ctl.step_to(t)
		if not quick or i == path.size() - 1:
			Audio.play("step", 0.15, -6.0)
		if not st["left"]:
			st["left"] = true
			_relayout(false, pid)   # các quân còn lại ở ô xuất phát dàn lại chỗ
	, quick)
	_moving_pid = -1
	await _relayout(false, pid)   # các quân trong ô đích nhường chỗ


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
			for i in tokens.size():
				(tokens[i] as Character3D).set_active(i == ev["p"])
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
			hud.set_cash(ev["p"], ev["cash"], true, 0.6 / speed)
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
			(tokens[ev["p"]] as Character3D).react("sigh")
			if cam_ctl.mode != CameraController.Mode.OVERVIEW:
				cam_ctl.focus(BoardData.JAIL_TILE, 0.6 / speed)
			hud.notify.cancel_tag("land")   # gộp "Kẹt Xe" (tên ô) + "bị KẸT XE" thành một thông báo
			await hud.show_toast("%s bị KẸT XE!" % engine.players[ev["p"]]["name"], 0.9 / speed, "jail")
		"tile":
			var t_ev: int = ev["tile"]
			var grew: bool = ev["owner"] >= 0 and (ev["level"] > board._shown_level[t_ev] or ev["owner"] != board._shown_owner[t_ev])
			var new_owner: bool = ev["owner"] >= 0 and ev["owner"] != board._shown_owner[t_ev]
			var leveled_up: bool = ev["owner"] >= 0 and not new_owner and ev["level"] > board._shown_level[t_ev]
			board.anim_speed = speed
			juice.speed = speed
			board.set_tile_state(t_ev, ev["owner"], ev["level"], true, String(ev.get("kind", "")))
			if new_owner:
				Audio.play("buy_keng", 0.05, -2.0)
				if not _in_auction:
					juice.purchase(ev["owner"], t_ev)
			elif leveled_up and ev["level"] < GameEngine.LANDMARK:
				juice.build(ev["owner"], t_ev)
			_check_group(t_ev, ev["owner"])
			if ev["owner"] >= 0 and ev["owner"] == engine.current:
				tokens[ev["owner"]].cheer()
			# chờ công trình mọc xong rồi mới sang sự kiện tiếp theo
			await get_tree().create_timer((0.55 if grew and (ev["level"] > 0 or not BoardData.is_province(t_ev)) else 0.15) / speed).timeout
		"festival":
			board.set_festival(ev["tile"])
		"card":
			pass
		"rent":
			var payer: int = ev["p"]
			var own: int = ev["owner"]
			(tokens[payer] as Character3D).react("slump")
			if (payer == human_id or own == human_id) and not engine.players[human_id]["is_bot"]:
				hud.show_banner("%s trả %s xu thuê cho %s\n%s · %s" % [engine.players[payer]["name"], BoardData.money(ev["amount"]), engine.players[own]["name"], ev["label"], BoardData.plain_name(ev["tile"])], 1.6 / speed)
		"building":
			var bt := EconomyConfig.get_default().building(ev["type"])
			if bt:
				hud.show_banner("%s xây %s ở %s!" % [engine.players[ev["p"]]["name"], bt.name, BoardData.plain_name(ev["tile"])], 1.2 / speed)
		"passive":
			match String(ev["kind"]):
				"homestay":
					_float_text(ev["p"], "+%s Homestay" % BoardData.money(ev["amount"]), Color("#a1887f"))
				"market":
					_float_text(ev["p"], "+%s phí chợ" % BoardData.money(ev["amount"]), Color("#ffb74d"))
				"workshop":
					_float_text(ev["p"], "+%d đặc sản" % int(ev["amount"]), Color("#81c784"))
		"auction_start":
			_in_auction = true
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
			_in_auction = false
			if w >= 0:
				Audio.play("auction_win")
				tokens[w].cheer()
				juice.auction_win(w, ev["tile"])
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
			Audio.play("win", 0.0, -6.0)
			(tokens[ev["p"]] as Character3D).react("lucky")
			await hud.show_toast("%s nhận Quỹ Từ Thiện\n%s xu!" % [engine.players[ev["p"]]["name"], BoardData.money(ev["amount"])], 1.3 / speed)
		"blackout":
			season_fx.set_blackout(true)
			await hud.show_toast("CÚP ĐIỆN DIỆN RỘNG\nTiền thuê toàn bàn −50% đến hết vòng", 1.3 / speed)
		"lottery":
			var txt := "Xổ số: chọn %d — ra %d\n%s" % [ev["number"], ev["roll"], "TRÚNG LỚN!" if ev["win"] else "Trượt rồi!"]
			(tokens[ev["p"]] as Character3D).react("lucky" if ev["win"] else "jolt")
			await hud.show_toast(txt, 1.3 / speed)
		"landmark":
			Audio.play("landmark")
			Audio.play("firework", 0.1, -3.0)
			season_fx.fireworks()
			juice.celebrate(ev["tile"])
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
			(tokens[ev["p"]] as Character3D).set_active(false)
			_relayout()
			hud.refresh_players()
		"toll":
			Audio.play("toll")
		"game_over":
			for tk in tokens:
				(tk as Character3D).set_active(false)
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
	_stepping = true
	await _after_queue_inner()
	_stepping = false
	if online and not _busy:
		_drain_net()


func _after_queue_inner() -> void:
	board.update_info(engine)
	hud.refresh_players()
	if online:
		if _drain_net():
			return
		Net.send_ready(_applied)
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
	if pend["type"] == "choose_building":
		await _choose_step(pend, p)
		return
	if pend["type"] == "turn":
		_set_state(TurnState.WAITING_FOR_ROLL)
		hud.set_focus(false)
	if not _is_local(pend["p"]):
		if pend["type"] == "turn":
			hud.show_roll_waiting(p["name"])
		else:
			hud.show_waiting("%s đang suy nghĩ..." % p["name"])
		if online:
			return   # chờ nước đi từ server
		await get_tree().create_timer(0.45 / speed).timeout
		if engine.pending != pend:
			return
		var a := BotAI.decide(engine, pend)
		hud.show_waiting("")
		_feed(engine.act(pend["p"], a))
	else:
		hud.show_decision(pend)
		if _net_idle_left() > 0:
			return   # kiểm thử: cố tình không bấm để server xử hết giờ
		if _autotest:
			var delay := 0.6
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--clickdelay="):
					delay = float(arg.substr(13))
			await get_tree().create_timer(delay).timeout
			hud.autotest_click()


## Đấu giá: người chơi thật trả giá qua panel (có đồng hồ), máy "cân nhắc" một chút rồi quyết định.
func _auction_step(pend: Dictionary, p: Dictionary) -> void:
	hud.show_waiting("")
	if _is_local(pend["p"]):
		var cfg := EconomyConfig.get_default()
		var secs := maxf(cfg.auction_human_min_seconds, cfg.auction_human_seconds / speed)
		if online:
			secs = ServerRoom.AUCTION_TIME + 1.0   # server tính giờ chính; panel chỉ hiển thị
		hud.auction_panel.prompt(pend, secs)
		if _autotest and not OS.get_cmdline_user_args().has("--auctiondemo"):
			await get_tree().create_timer(0.5).timeout
			hud.auction_panel.autopress()
		return
	if hud.auction_panel.visible:
		hud.auction_panel.on_thinking(pend["p"])
	if online:
		return
	var delay := 0.08 if _auction_fast else randf_range(0.35, 0.9)
	await get_tree().create_timer(delay / speed).timeout
	if engine.pending != pend:
		return
	_feed(engine.act(pend["p"], BotAI.decide(engine, pend)))


## Chọn loại công trình: người chơi thật dùng panel 4 thẻ, máy tự chọn theo tính cách.
func _choose_step(pend: Dictionary, p: Dictionary) -> void:
	hud.show_waiting("")
	hud.hide_roll()
	if _is_local(pend["p"]):
		hud.building_picker.open(pend)
		if _autotest and not OS.get_cmdline_user_args().has("--pickerdemo"):
			await get_tree().create_timer(0.8).timeout
			hud.building_picker.autopress()
		return
	hud.show_waiting("%s đang chọn công trình..." % p["name"])
	if online:
		return
	await get_tree().create_timer(0.4 / speed).timeout
	if engine.pending != pend:
		return
	hud.show_waiting("")
	_feed(engine.act(pend["p"], BotAI.decide(engine, pend)))


func _submit_choice(action: Dictionary) -> void:
	if _busy or engine.pending.is_empty() or engine.pending["type"] != "choose_building" or engine.pending["p"] != human_id:
		return
	if online:
		_send_local(action)
		return
	var evs := engine.act(human_id, action)
	if not evs.is_empty():
		_feed(evs)


func _submit_auction(action: Dictionary) -> void:
	if _busy or engine.pending.is_empty() or engine.pending["type"] != "auction_bid" or engine.pending["p"] != human_id:
		return
	if online:
		_send_local(action)
		return
	var evs := engine.act(human_id, action)
	if not evs.is_empty():
		_feed(evs)


## Bộ bài Khí Vận / Cơ Hội: khoá lượt cho tới khi người chơi rút bài và bấm XÁC NHẬN.
func _card_step(pend: Dictionary, p: Dictionary) -> void:
	hud.clear_decision()
	hud.show_waiting("")
	var human: bool = _is_local(pend["p"])
	match String(pend["type"]):
		"draw_card":
			if not cards_ui.is_open:
				await cards_ui.open(pend["deck"], p["name"], speed)
			if human:
				cards_ui.show_draw_button()
				if _autotest:
					await get_tree().create_timer(0.5).timeout
					cards_ui.autopress()
			elif not online:
				await get_tree().create_timer(0.5 / speed).timeout
				_submit_card({"action": "draw"})
		"card_reveal", "card_pick":
			var count: int = 2 if pend["type"] == "card_pick" else 1
			if human:
				cards_ui.show_confirm(count)
				if _autotest:
					await get_tree().create_timer(0.6).timeout
					cards_ui.autopress()
			elif not online:
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


## Kiểm thử hiệu ứng mua đất: mua Cao Bằng → xây Nhà hàng → thắng đấu giá Lạng Sơn, chụp từng pha.
func _juice_demo() -> void:
	speed = 1.0
	juice.speed = 1.0
	engine.pending = {}   # dừng ván: chỉ diễn hiệu ứng, máy không chơi tiếp
	await get_tree().create_timer(1.0).timeout
	var t := BoardData.find_tile("Cao Bằng")
	engine._events = []
	engine._pay(engine.players[human_id], 100, -1, "Mua đất")
	engine._set_tile(t, human_id, 0)
	_feed(engine._events.duplicate())
	await get_tree().create_timer(0.3).timeout
	_demo_shot("juice_1_coins")
	await get_tree().create_timer(0.35).timeout
	_demo_shot("juice_2_punch")
	await get_tree().create_timer(1.6).timeout
	engine._events = []
	engine._pay(engine.players[human_id], 60, -1, "Xây Nhà hàng")
	engine.btype[t] = "restaurant"
	engine._set_tile(t, human_id, 1)
	engine._push({"t": "building", "p": human_id, "tile": t, "type": "restaurant", "level": 1})
	_feed(engine._events.duplicate())
	await get_tree().create_timer(0.45).timeout
	_demo_shot("juice_3_build")
	await get_tree().create_timer(1.8).timeout
	var t2 := BoardData.find_tile("Lạng Sơn")
	engine._events = []
	engine._pay(engine.players[human_id], 70, -1, "Thắng đấu giá")
	engine._set_tile(t2, human_id, 0)
	engine._push({"t": "auction_end", "tile": t2, "winner": human_id, "price": 70})
	_in_auction = true
	_feed(engine._events.duplicate())
	await get_tree().create_timer(0.5).timeout
	_demo_shot("juice_4_auction")
	await get_tree().create_timer(2.0).timeout
	_demo_shot("juice_5_after")
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
	if online:
		if int(engine.pending["p"]) == human_id:
			_send_local(action)
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
		cam_ctl.impact(0.05)
		cam_ctl.focus(last, 0.7 / sp)
		hud.show_banner(hud.tile_summary(last), 1.8 / sp, "land")
		await get_tree().create_timer(0.55 / sp).timeout
	else:
		_set_state(TurnState.MOVING_PAWN)
		await _move_token(pid, path, fast)
		_focus_tile(last)
		if not fast:
			hud.show_banner(hud.tile_summary(last), 1.4 / sp, "land")
	_set_state(TurnState.PROCESSING_TILE)


# ---------------------------------------------------------------- phím kiểm thử (chỉ bản debug)
var _dbg_popup: UiPopup
var _dbg_variant := 0
var _dbg_react := -1


## Kiểm thử hình ảnh chuyển động: 4 quân chung một ô (xếp vòng), một quân nhảy đi rồi về,
## sau đó lần lượt các phản ứng. Chạy: --motiondemo --shot=<thư mục>
func _motion_demo() -> void:
	for i in tokens.size():
		token_tile[i] = 3
	await _relayout(true)
	(tokens[0] as Character3D).set_active(true)
	cam_ctl.focus(3, 0.6)
	await get_tree().create_timer(1.2).timeout
	await _debug_walk(4)
	cam_ctl.focus(3, 0.5)
	await get_tree().create_timer(0.6).timeout
	var kinds := ["cheer", "lucky", "jolt", "slump", "sigh", "sad"]
	for k in kinds.size():
		(tokens[k % tokens.size()] as Character3D).react(kinds[k])
		await get_tree().create_timer(0.4).timeout


## F3: cho quân đang tới lượt nhảy thử n ô rồi nhảy về (chỉ hình ảnh, không đổi trạng thái ván).
func _debug_walk(n: int) -> void:
	if _busy:
		return
	_busy = true
	var pid: int = maxi(engine.current, 0)
	var start: int = token_tile[pid]
	var fwd: Array = []
	for k in range(1, n + 1):
		fwd.append((start + k) % BoardData.TILE_COUNT)
	await _move_token(pid, fwd, false, cam_ctl.mode == CameraController.Mode.FOLLOW)
	var back: Array = []
	for k in range(n - 1, -1, -1):
		back.append((start + k) % BoardData.TILE_COUNT)
	await _move_token(pid, back, true)
	_busy = false


## F1: xem popup mẫu (lần lượt thường / xui / may) · F2: loạt thông báo (có trùng để thử gộp)
## F3: nhảy thử 6 ô rồi về · F4: thử vào Kẹt Xe (chỉ hình ảnh) · F5: lần lượt các phản ứng của nhân vật
## F6: đổi độ phân giải cửa sổ 1280×720 ↔ 1920×1080.
func _debug_key(k: int) -> void:
	match k:
		KEY_F1:
			if _dbg_popup == null:
				_dbg_popup = UiPopup.new()
				hud.root.add_child(_dbg_popup)
				_dbg_popup.avoid_point = _pending_screen_point
			var titles := ["Mua Hà Nội?", "Bạn đang Kẹt Xe", "Trúng xổ số!"]
			var icons := ["land", "jail", "star"]
			_dbg_popup.open_popup(titles[_dbg_variant], icons[_dbg_variant], _dbg_variant)
			_dbg_popup.set_desc("Popup mẫu (F1). Enter = nút chính, Esc = nút phụ.")
			_dbg_popup.add_action("Đồng ý", _dbg_popup.close_popup, "primary")
			_dbg_popup.add_action("Thêm nút", func(): pass, "accent")
			_dbg_popup.add_action("Bỏ qua", _dbg_popup.close_popup)
			_dbg_variant = (_dbg_variant + 1) % 3
		KEY_F2:
			hud.show_banner("Thông báo thường", 1.6)
			hud.show_banner("Thông báo thường", 1.6)   # trùng → tự gộp
			hud.show_toast("Bạn bị KẸT XE!", 1.6)
			hud.show_toast("Bạn nhận Quỹ Từ Thiện 300 xu!", 1.6)
		KEY_F3:
			_debug_walk(6)
		KEY_F4:
			var pj: int = maxi(engine.current, 0)
			token_tile[pj] = BoardData.JAIL_TILE
			await _relayout()
			(tokens[pj] as Character3D).react("sigh")
			hud.show_toast("%s bị KẸT XE! (thử)" % engine.players[pj]["name"], 1.2, "jail")
		KEY_F5:
			var kinds := ["lucky", "jolt", "cheer", "slump", "sigh", "sad"]
			_dbg_react = (_dbg_react + 1) % kinds.size()
			(tokens[maxi(engine.current, 0)] as Character3D).react(kinds[_dbg_react])
			hud.show_banner("Phản ứng: %s" % kinds[_dbg_react], 1.0)
		KEY_F6:
			var big := DisplayServer.window_get_size().x < 1600
			DisplayServer.window_set_size(Vector2i(1920, 1080) if big else Vector2i(1280, 720))


## Toạ độ màn hình của quân cờ đang phải quyết định (để popup không che nhân vật). (-1,-1) nếu không có.
func _pending_screen_point() -> Vector2:
	if engine == null or engine.pending.is_empty() or camera == null:
		return Vector2(-1, -1)
	var pid: int = engine.pending.get("p", -1)
	if pid < 0 or pid >= tokens.size() or not is_instance_valid(tokens[pid]):
		return Vector2(-1, -1)
	var wp: Vector3 = (tokens[pid] as Node3D).global_position + Vector3(0, 0.6, 0)
	if camera.is_position_behind(wp):
		return Vector2(-1, -1)
	return camera.unproject_position(wp)


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


## Gom đủ cả vùng: pháo giấy + banner (mỗi lần gom đủ chỉ báo một lần; mất vùng rồi gom lại thì báo lại).
func _check_group(t: int, owner_id: int) -> void:
	if not BoardData.is_province(t):
		return
	var g: int = BoardData.tile(t)["group"]
	for pid in engine.players.size():
		var key := "%d|%d" % [pid, g]
		var has_all := engine.owns_group(pid, g)
		if has_all and not _groups_done.has(key) and pid == owner_id:
			_groups_done[key] = true
			juice.celebrate(t)
			Audio.play("auction_win", 0.0, -3.0)
			hud.show_banner("%s gom đủ vùng %s! Tiền thuê cả vùng ×2" % [engine.players[pid]["name"], BoardData.GROUPS[g]["name"]], 1.6 / speed)
		elif not has_all:
			_groups_done.erase(key)


func _on_building_landed(_t: int, strength: float) -> void:
	if strength >= 0.5:
		Audio.play("hammer", 0.1, -3.0 if strength >= 0.9 else -7.0)
		cam_ctl.impact(0.03 * strength)


func _on_speed_changed(s: float) -> void:
	speed = s
	for tk in tokens:
		(tk as Character3D).anim_speed = s
	juice.speed = s
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
	if online:
		_send_local(action)
		return
	var evs := engine.act(human_id, action)
	if evs.is_empty():
		hud.show_decision(engine.pending)
		return
	_feed(evs)


# ---------------------------------------------------------------- online

## Quân `pid` do người ngồi ở máy này điều khiển? (online: đúng ghế của mình; offline: mọi người thật)
func _is_local(pid: int) -> bool:
	if online:
		return pid == human_id
	return not engine.players[pid]["is_bot"]


func _online_begin(events: Array) -> void:
	Net.move_received.connect(_on_net_move)
	Net.timer_started.connect(func(pid, secs): hud.start_timer(pid, secs))
	Net.notice.connect(func(t): hud.show_banner(t, 2.2))
	Net.message.connect(_on_net_message)
	Net.disconnected.connect(_on_net_lost)
	Net.game_started.connect(func(_info): get_tree().reload_current_scene())
	for i in (Net.room.get("seats", []) as Array).size():
		if not Net.room["seats"][i]["connected"]:
			hud.set_presence(i, false)
	var log: Array = Net.start_info.get("log", [])
	if log.is_empty():
		_feed(events)
		return
	# Vào lại giữa ván: chạy nhanh mọi nước đã đi (không diễn), rồi dựng lại bàn cờ theo trạng thái
	for en in log:
		if en["k"] == "forfeit":
			engine.forfeit(en["p"])
		else:
			engine.act(en["p"], en["a"])
	_applied = log.size()
	var h := String(Net.start_info.get("hash", ""))
	if h != "" and engine.state_hash() != h:
		push_warning("Trạng thái sau khi tải lại khác server.")
	_sync_visuals()
	hud.show_banner("Đã vào lại ván — chơi tiếp nào!", 2.0)
	_after_queue()


## Dựng lại toàn bộ hình ảnh theo trạng thái engine (sau khi tải lại ván).
func _sync_visuals() -> void:
	board.rebuild_from(engine)
	for i in tokens.size():
		token_tile[i] = int(engine.players[i]["pos"])
		tokens[i].visible = engine.players[i]["alive"]
		(tokens[i] as Character3D).set_active(i == engine.current)
	_relayout(true)
	board.set_season(engine.season, engine.season_event)
	season_fx.set_season(engine.season, engine.season_event)
	hud.set_season(engine.season, engine.season_event)
	hud.set_round(engine.round_num)
	board.set_pot(engine.charity_pot)
	hud.set_pot(engine.charity_pot)
	if engine.blackout_round == engine.round_num:
		season_fx.set_blackout(true)
	_turn_player = engine.current
	hud.set_current(engine.current)
	hud.refresh_players()
	board.update_info(engine)
	_focus_tile(token_tile[engine.current])


## Kiểm thử: --netidle=K → K lần đầu tới lượt thì không bấm gì.
func _net_idle_left() -> int:
	if not online:
		return 0
	var k := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--netidle="):
			k = int(arg.substr(10))
	var used: int = Global.get_meta("netidle_used", 0)
	if used < k:
		Global.set_meta("netidle_used", used + 1)
		return k - used
	return 0


func _send_local(action: Dictionary) -> void:
	hud.stop_timer()
	Net.send_action(action)


func _on_net_move(m: Dictionary) -> void:
	_inbox.append(m)
	if not _busy and not _stepping:
		_drain_net()


## Áp nước tiếp theo (đúng số thứ tự) nếu có. Trả về true nếu đã bắt đầu áp một nước.
func _drain_net() -> bool:
	while not _inbox.is_empty() and int(_inbox[0]["n"]) <= _applied:
		_inbox.pop_front()
	if _inbox.is_empty():
		return false
	_inbox.sort_custom(func(x, y): return int(x["n"]) < int(y["n"]))
	if int(_inbox[0]["n"]) != _applied + 1:
		return false
	_apply_net(_inbox.pop_front())
	return true


func _apply_net(m: Dictionary) -> void:
	_busy = true
	hud.stop_timer()
	var pend := engine.pending
	var a: Dictionary = m.get("a", {})
	# Bộ bài đang mở mà có kết quả xác nhận / chọn lá: diễn đóng bài trước khi áp
	if m["k"] == "act" and not pend.is_empty() and ["card_reveal", "card_pick"].has(String(pend["type"])) and cards_ui.is_open:
		await cards_ui.close(int(a.get("index", 0)))
	# Nước của mình bị server quyết thay (hết giờ): đóng các bảng đang mở
	if not pend.is_empty() and int(pend["p"]) == human_id:
		hud.clear_decision()
		hud.hide_roll()
		if hud.building_picker.visible:
			hud.building_picker.close()
	var evs: Array = engine.forfeit(m["p"]) if m["k"] == "forfeit" else engine.act(m["p"], a)
	_applied = int(m["n"])
	# kiểm thử: --netdrop=N giả lập rớt mạng sau nước thứ N (một lần)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--netdrop=") and _applied == int(arg.substr(10)) and not Global.has_meta("netdropped"):
			Global.set_meta("netdropped", true)
			Net._ws.close()
	_busy = false
	if engine.state_hash() != String(m.get("h", "")):
		_resync("Lệch trạng thái với server — đang đồng bộ lại...")
		return
	if evs.is_empty():
		_after_queue()
	else:
		_feed(evs)


func _on_net_message(m: Dictionary) -> void:
	match String(m.get("t", "")):
		"presence":
			var seat := int(m["seat"])
			hud.set_presence(seat, bool(m["connected"]))
			if seat != human_id and seat < engine.players.size():
				hud.show_banner("%s %s" % [engine.players[seat]["name"], "đã vào lại" if m["connected"] else "mất kết nối"], 1.8)
		"reject":
			# server từ chối (thường do vừa hết giờ): nếu vẫn tới lượt mình thì hiện lại lựa chọn
			if not _busy and not _stepping and _inbox.is_empty() and not engine.pending.is_empty() and int(engine.pending["p"]) == human_id:
				_after_queue()


func _resync(text: String) -> void:
	hud.show_banner(text, 2.0)
	if _room_code != "":
		Net.join_room(_room_code)   # server gửi lại toàn bộ ván → cảnh được tải lại


func _on_net_lost() -> void:
	hud.show_banner("Mất kết nối tới server — đang kết nối lại...", 3.0)
	_reconnect_t = 0.0


func _process(delta: float) -> void:
	if online and _reconnect_t >= 0.0 and not Net.is_online():
		_reconnect_t -= delta
		if _reconnect_t <= 0.0:
			_reconnect_t = 3.0
			# giữ nguyên token đã dùng khi vào phòng → server nhận lại đúng ghế
			Net.connect_to(Net.url if Net.url != "" else Global.server_url)
			Net.join_room(_room_code)


func _leave_to_lobby() -> void:
	if online:
		Net.leave_room()
		Net.close()
		Net.start_info = {}
		Global.online = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


# ---------------------------------------------------------------- kiểm thử tự động

func _exit_tree() -> void:
	if _autotest and engine:
		print("AUTOTEST round=%d game_over=%s state=%d pending=%s cache=%s fps=%d online=%s applied=%d hash=%s" % [engine.round_num, engine.game_over, turn_state, engine.pending.get("type", "-"), MeshCache.stats(), Engine.get_frames_per_second(), online, _applied, engine.state_hash()])


func _start_autotest() -> void:
	if OS.get_cmdline_user_args().has("--until-over"):
		# chạy tới hết ván (kiểm thử online), chụp ảnh mỗi --every giây nếu có --shot
		var every2 := 6.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--every="):
				every2 = float(a.substr(8))
		var k := 0
		var t0 := Time.get_ticks_msec()
		while not engine.game_over and Time.get_ticks_msec() - t0 < 600000:
			await get_tree().create_timer(every2).timeout
			if _shot_dir != "" and k < 40:
				DirAccess.make_dir_recursive_absolute(_shot_dir)
				get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("game_%02d.png" % k))
				k += 1
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()
		return
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
