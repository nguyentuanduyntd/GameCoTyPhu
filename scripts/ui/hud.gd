class_name Hud
extends CanvasLayer
## Giao diện trong ván: bảng người chơi, nhật ký, bảng quyết định, thông báo.

signal action_chosen(action: Dictionary)
signal pick_mode(tiles: Array)
signal menu_requested
signal restart_requested
signal speed_changed(speed: float)
signal cam_toggled(auto: bool)

var engine: GameEngine
var colors: Array = []
var human_id: int = 0

var root: Control
var player_boxes: Array = []
var cards: Array = []
var top_bar: TopBar
var event_log: EventLog
var avatars: AvatarFactory
var _shown_cash := {}
var _cash_tw := {}
var round_label: Label
var log_box: RichTextLabel
var decision_panel: PanelContainer
var decision_title: Label
var decision_desc: Label
var decision_buttons: HFlowContainer
var tile_scroll: ScrollContainer
var tile_grid: GridContainer
var toast_panel: PanelContainer
var toast_label: Label
var waiting_label: Label
var over_panel: PanelContainer
var speed_btn: Button
var cam_btn: Button
var info_panel: PanelContainer
var log_panel: PanelContainer
var roll_area: VBoxContainer
var roll_title: Label
var roll_hint: Label
var roll_btn: RollButton
var roll_extras: HFlowContainer
var banner: PanelContainer
var auction_panel: AuctionPanel
var building_picker: BuildingPicker
var banner_label: Label
var _banner_tw: Tween
var info_label: RichTextLabel

var _pick_callback: Callable = Callable()
var _lottery_number: int = 1
var _speeds := [1.0, 2.0, 3.0, 4.0]
var _speed_idx := 0


func setup(p_engine: GameEngine, p_colors: Array, p_human: int) -> void:
	engine = p_engine
	colors = p_colors
	human_id = p_human
	_build()
	auction_panel = AuctionPanel.new()
	root.add_child(auction_panel)
	auction_panel.setup(engine, colors, human_id)
	building_picker = BuildingPicker.new()
	root.add_child(building_picker)
	building_picker.setup(engine)


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Cột trái: thẻ nhân vật (neo trái, tự co theo nội dung)
	var left := VBoxContainer.new()
	_anchor(left, Control.PRESET_TOP_LEFT, 12, 12, 252, 12)
	left.grow_horizontal = Control.GROW_DIRECTION_END
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	for p in engine.players:
		var card := PlayerCard.new()
		card.setup(p, Color(colors[p["id"]]), p["id"] == human_id and not p["is_bot"])
		left.add_child(card)
		cards.append(card)
		player_boxes.append({"panel": card})
	avatars = AvatarFactory.new()
	add_child(avatars)
	avatars.ready_avatar.connect(func(pid, tex): cards[pid].set_avatar(tex))
	for p in engine.players:
		avatars.make(p["id"], p["character"], Color(colors[p["id"]]))

	# --- Trên giữa: Vòng / Mùa / Quỹ
	top_bar = TopBar.new()
	_anchor(top_bar, Control.PRESET_CENTER_TOP, -250, 10, 250, 52)
	root.add_child(top_bar)

	# --- Phải: cụm nút (neo phải, mọc sang trái nên không bao giờ bị cắt) + nhật ký
	var right := VBoxContainer.new()
	_anchor(right, Control.PRESET_TOP_RIGHT, -322, 10, -12, 10)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	right.add_child(row)
	speed_btn = _icon_button("speed", "x1", "Tốc độ ván (x1 → x2 → x3 → x4)", _on_speed)
	row.add_child(speed_btn)
	cam_btn = _icon_button("camera", "Điện ảnh", "Góc nhìn: Điện ảnh (bám quân cờ) / Toàn cảnh", func():
		var on := cam_btn.text == "Toàn cảnh"
		set_cam_auto(on)
		cam_toggled.emit(on))
	row.add_child(cam_btn)
	row.add_child(_icon_button("gear", "", "Cài đặt", func(): add_child(SettingsPanel.new())))
	row.add_child(_icon_button("menu", "", "Về sảnh", func(): menu_requested.emit()))
	event_log = EventLog.new()
	event_log.setup(engine.players, colors)
	event_log.custom_minimum_size = Vector2(310, 0)
	right.add_child(event_log)
	log_panel = event_log

	# --- Dưới giữa: bảng quyết định
	decision_panel = PanelContainer.new()
	decision_panel.add_theme_stylebox_override("panel", _style(Color("#3e2723", 0.92), 14, Color("#ffca28")))
	_anchor(decision_panel, Control.PRESET_CENTER_BOTTOM, -330, -14, 330, -14)
	decision_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(decision_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	decision_panel.add_child(dv)
	decision_title = Label.new()
	decision_title.add_theme_font_size_override("font_size", 22)
	decision_title.add_theme_color_override("font_color", Color("#ffca28"))
	decision_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(decision_title)
	decision_desc = Label.new()
	decision_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decision_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	decision_desc.add_theme_color_override("font_color", Color("#fff8e1"))
	dv.add_child(decision_desc)
	tile_scroll = ScrollContainer.new()
	tile_scroll.custom_minimum_size = Vector2(640, 150)
	tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tile_scroll.visible = false
	dv.add_child(tile_scroll)
	tile_grid = GridContainer.new()
	tile_grid.columns = 4
	tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_scroll.add_child(tile_grid)
	decision_buttons = HFlowContainer.new()
	decision_buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	decision_buttons.add_theme_constant_override("h_separation", 10)
	decision_buttons.add_theme_constant_override("v_separation", 8)
	dv.add_child(decision_buttons)
	decision_panel.visible = false

	_build_roll_area()
	_build_banner()
	waiting_label = Label.new()
	_anchor(waiting_label, Control.PRESET_CENTER_BOTTOM, -300, -60, 300, -24)
	waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_label.add_theme_font_size_override("font_size", 20)
	waiting_label.add_theme_color_override("font_color", Color("#ffffff"))
	waiting_label.add_theme_color_override("font_outline_color", Color("#000000"))
	waiting_label.add_theme_constant_override("outline_size", 6)
	root.add_child(waiting_label)

	# --- Thông báo giữa màn hình
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _style(Color("#fff8e1", 0.96), 14, Color("#e53935")))
	_anchor(toast_panel, Control.PRESET_CENTER, -210, -170, 210, -110)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)
	toast_label = Label.new()
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color("#3e2723"))
	toast_panel.add_child(toast_label)
	toast_panel.visible = false

	# --- Bảng thông tin ô (bấm vào ô trên bàn cờ)
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _style(Color("#fff8e1", 0.97), 12, Color("#5d4037")))
	_anchor(info_panel, Control.PRESET_CENTER_RIGHT, -300, -150, -10, 150)
	root.add_child(info_panel)
	var iv := VBoxContainer.new()
	info_panel.add_child(iv)
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.custom_minimum_size = Vector2(270, 0)
	info_label.add_theme_color_override("default_color", Color("#3e2723"))
	info_label.add_theme_font_size_override("normal_font_size", 14)
	info_label.add_theme_font_size_override("bold_font_size", 18)
	iv.add_child(info_label)
	iv.add_child(_button("Đóng", hide_tile_info))
	info_panel.visible = false


# ---------------------------------------------------------------- thẻ người chơi / thanh trên / nhật ký

func set_cash(pid: int, cash: int, animate: bool = false, duration: float = 0.6) -> void:
	(cards[pid] as PlayerCard).set_cash(cash, animate and Global.buy_fx > 0, duration)


func set_current(pid: int) -> void:
	for i in cards.size():
		(cards[i] as PlayerCard).set_active(i == pid)


func refresh_players() -> void:
	for p in engine.players:
		(cards[p["id"]] as PlayerCard).refresh(engine, p)
	top_bar.update(engine)


func set_round(_n: int) -> void:
	top_bar.update(engine)


func set_season(_s: int, _ev: Dictionary) -> void:
	top_bar.update(engine)


func set_pot(amount: int) -> void:
	top_bar.set_pot(amount)


func add_log(text: String) -> void:
	event_log.add_entry(text)


func _icon_button(icon: String, text: String, tip: String, cb: Callable) -> Button:
	var b := _button(text, cb)
	b.icon = UiIcons.get_icon(icon)
	b.expand_icon = false
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(48 if text == "" else 0, 46)
	b.add_theme_constant_override("icon_max_width", 26)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


# ---------------------------------------------------------------- thông báo

func show_toast(text: String, duration: float) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(toast_panel, "modulate", Color.WHITE, 0.15)
	await get_tree().create_timer(duration).timeout
	toast_panel.visible = false


func show_waiting(text: String) -> void:
	waiting_label.text = text


# ---------------------------------------------------------------- quyết định

func clear_decision() -> void:
	decision_panel.visible = false
	if roll_area and roll_btn.state == RollButton.State.ACTIVE:
		roll_area.visible = false
	tile_scroll.visible = false
	_pick_callback = Callable()
	pick_mode.emit([])
	for c in decision_buttons.get_children():
		c.queue_free()
	for c in tile_grid.get_children():
		c.queue_free()


## Dùng cho kiểm thử tự động: bấm nút ô đầu tiên hoặc nút quyết định đầu tiên.
func autotest_click() -> void:
	if roll_area.visible and roll_btn.is_ready():
		roll_btn.press()
		return
	if not decision_panel.visible:
		return
	if tile_scroll.visible and tile_grid.get_child_count() > 0:
		(tile_grid.get_child(0) as Button).pressed.emit()
		return
	for c in decision_buttons.get_children():
		if c is Button and not c.is_queued_for_deletion():
			(c as Button).pressed.emit()
			return


func pick_tile(t: int) -> void:
	if _pick_callback.is_valid():
		_pick_callback.call(t)


func show_decision(pend: Dictionary) -> void:
	clear_decision()
	if ["draw_card", "card_reveal", "card_pick", "auction_bid", "choose_building"].has(String(pend["type"])):
		return
	waiting_label.text = ""
	var p: Dictionary = engine.players[pend["p"]]
	decision_panel.visible = true
	decision_desc.text = ""
	match String(pend["type"]):
		"turn":
			decision_panel.visible = false
			show_roll(p)
		"jail":
			decision_title.text = "Bạn đang Kẹt Xe"
			decision_desc.text = "Tung trượt %d/%d lần (đủ %d lần thì CSGT phân luồng, tự thoát). Tung đôi để thoát, gọi xe ôm, hoặc liều đi đường tắt." % [pend["tries"], pend["max_tries"], pend["max_tries"]]
			if int(p["cash"]) >= int(pend["fee"]):
				_add_btn("Gọi xe ôm (%s)" % BoardData.money(pend["fee"]), {"action": "pay"})
			_add_btn("Đường tắt (chẵn thoát, lẻ kẹt thêm)", {"action": "shortcut"})
			_add_btn("Tung tìm đôi", {"action": "roll"}, true)
		"train":
			decision_title.text = "Tàu Thống Nhất"
			decision_desc.text = "Chọn ga đến (vé %s) — bấm ô trên bàn cờ hoặc trong danh sách." % BoardData.money(pend["fee"])
			if int(p["cash"]) >= int(pend["fee"]):
				_show_tile_picker(engine.train_targets(), func(t): _emit({"action": "travel", "tile": t}))
			_add_btn("Không đi tàu, tung xúc xắc", {"action": "skip"})
		"buy":
			var t: int = pend["tile"]
			decision_title.text = "Mua %s?" % BoardData.plain_name(t)
			decision_desc.text = _tile_desc(t)
			for o in pend["options"]:
				var label := "Mua đất (%s)" % BoardData.money(o["cost"])
				if int(o["level"]) > 0:
					label = "Mua + %s (%s)" % [GameEngine.LEVEL_NAMES[o["level"]], BoardData.money(o["cost"])]
				_add_btn(label, {"action": "buy", "level": o["level"]}, true)
			_add_btn("Bỏ qua", {"action": "pass"})
		"build":
			var t: int = pend["tile"]
			var cur: int = engine.level[t]
			var bt := engine.building_type(t)
			var bname := bt.name if bt else "công trình"
			decision_title.text = ("Nâng cấp %s ở %s?" % [bname, BoardData.plain_name(t)]) if cur > 0 else ("Xây %s ở %s?" % [bname, BoardData.plain_name(t)])
			var rm: Array = EconomyConfig.get_default().rent_mult
			var next_mult: float = bt.at(bt.rent_mult, cur + 1) if bt else float(rm[mini(cur + 1, rm.size() - 1)])
			decision_desc.text = "Hiện tại: %s · thuê %s xu. Cấp tiếp theo: thuê cơ bản %s xu." % [engine.building_label(t), BoardData.money(engine.rent(t)), BoardData.money(_round5(int(BoardData.tile(t)["price"]) * next_mult))]
			for o in pend["options"]:
				var lv: int = o["level"]
				var lvname := "Danh Thắng" if lv >= GameEngine.LANDMARK else "Cấp %d" % lv
				_add_btn("Lên %s — %s xu" % [lvname, BoardData.money(o["cost"])], {"action": "build", "level": lv}, true)
			_add_btn("Để sau", {"action": "pass"})
		"takeover":
			var t: int = pend["tile"]
			decision_title.text = "Thâu tóm %s?" % BoardData.plain_name(t)
			decision_desc.text = "Mua lại từ %s với giá %s (1,5× giá trị đầu tư). Chủ cũ buộc phải bán." % [engine.players[pend["from"]]["name"], BoardData.money(pend["price"])]
			_add_btn("THÂU TÓM", {"action": "takeover"}, true)
			_add_btn("Bỏ qua", {"action": "pass"})
		"festival":
			decision_title.text = "Tổ chức Lễ Hội"
			decision_desc.text = "Chọn 1 tỉnh của bạn: tiền thuê ở đó ×2 cho đến khi có lễ hội mới."
			_show_tile_picker(pend["options"], func(t): _emit({"action": "festival", "tile": t}))
			_add_btn("Bỏ qua", {"action": "pass"})
		"lottery":
			decision_title.text = "Xổ Số Kiến Thiết"
			decision_desc.text = "Chọn 1 số từ 1 đến 6 rồi chọn mức cược. Trúng nhận ×%d tiền cược." % GameEngine.LOTTERY_PAYOUT
			_show_lottery(pend["bets"])
		"market":
			decision_title.text = "Chợ Phiên"
			var sc := engine.specialty_counts(p["id"])
			decision_desc.text = "Đặc sản của bạn — Bắc: %d, Trung: %d, Nam: %d." % [sc[0], sc[1], sc[2]]
			var opts: Array = pend["options"]
			if opts.has("exchange_rare"):
				_add_btn("Đổi 3 miền → thẻ hiếm", {"action": "exchange_rare"}, true)
			if opts.has("exchange_common"):
				_add_btn("Đổi 3 cùng miền → thẻ", {"action": "exchange_common"}, true)
			if opts.has("buy_specialty"):
				_add_btn("Mua 1 đặc sản (%s)" % BoardData.money(GameEngine.SPECIALTY_PRICE), {"action": "buy_specialty"})
			_add_btn("Rời chợ", {"action": "pass"})
		"card_pick":
			decision_title.text = "Cơ Hội — chọn 1 trong 2 thẻ"
			var cards: Array = pend["cards"]
			for i in cards.size():
				var c := CardsData.card(pend["deck"], cards[i])
				_add_btn("%s: %s" % [c["name"], c["text"]], {"action": "pick", "index": i}, true)
		"card_confirm":
			decision_title.text = String(pend["name"])
			decision_desc.text = String(pend["text"])
			_add_btn("Đồng ý", {"action": "accept"}, true)
			_add_btn("Bỏ qua", {"action": "pass"})
		"card_player":
			decision_title.text = String(pend["name"])
			decision_desc.text = String(pend["text"]) + " Chọn người chơi:"
			for oid in pend["options"]:
				var op: Dictionary = engine.players[oid]
				_add_btn("%s (%s xu)" % [op["name"], BoardData.money(op["cash"])], {"action": "pick_player", "target": oid}, true)
			_add_btn("Bỏ qua", {"action": "pass"})
		"card_tile":
			decision_title.text = String(pend["name"])
			decision_desc.text = String(pend["text"]) + " Bấm ô trên bàn cờ hoặc chọn trong danh sách."
			_show_tile_picker(pend["options"], func(t): _emit({"action": "pick_tile", "tile": t}))
			_add_btn("Bỏ qua", {"action": "pass"})


# ---------------------------------------------------------------- nút TUNG

func _build_roll_area() -> void:
	roll_area = VBoxContainer.new()
	roll_area.alignment = BoxContainer.ALIGNMENT_END
	roll_area.add_theme_constant_override("separation", 0)
	_anchor(roll_area, Control.PRESET_CENTER_BOTTOM, -260, -330, 260, -6)
	roll_area.grow_vertical = Control.GROW_DIRECTION_BEGIN
	roll_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(roll_area)
	roll_extras = HFlowContainer.new()
	roll_extras.alignment = FlowContainer.ALIGNMENT_CENTER
	roll_extras.add_theme_constant_override("h_separation", 8)
	roll_area.add_child(roll_extras)
	roll_title = Label.new()
	roll_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_title.add_theme_font_size_override("font_size", 34)
	roll_title.add_theme_color_override("font_color", Color("#ffd54f"))
	roll_title.add_theme_constant_override("outline_size", 12)
	roll_title.add_theme_color_override("font_outline_color", Color("#4e1a00"))
	roll_area.add_child(roll_title)
	roll_hint = Label.new()
	roll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_hint.add_theme_font_size_override("font_size", 18)
	roll_hint.add_theme_color_override("font_color", Color("#fff8e1"))
	roll_hint.add_theme_constant_override("outline_size", 6)
	roll_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	roll_area.add_child(roll_hint)
	roll_btn = RollButton.new()
	roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roll_area.add_child(roll_btn)
	roll_btn.pressed.connect(func():
		roll_title.text = "Tung nào!"
		roll_hint.text = ""
		_clear_extras()
		roll_btn.set_busy()
		action_chosen.emit({"action": "roll"}))
	roll_area.visible = false


## Đến lượt người chơi: hiện nút TUNG màu người chơi, kèm các nút phụ (thẻ kỹ năng, đổi đặc sản).
func show_roll(p: Dictionary) -> void:
	_clear_extras()
	roll_title.text = "ĐẾN LƯỢT BẠN!"
	roll_hint.text = "Nhấn để tung xúc xắc  ·  đang ở %s" % BoardData.plain_name(p["pos"])
	roll_btn.activate(Color(colors[p["id"]]))
	if p["cards"].has("XUC_XAC_VANG"):
		roll_extras.add_child(_small_btn("Xúc Xắc Vàng", func():
			_open_panel("Xúc Xắc Vàng")
			_show_golden()))
	if p["cards"].has("GIAI_TOA") and engine.giai_toa_targets(p["id"]).size() > 0:
		roll_extras.add_child(_small_btn("Giải Tỏa", func():
			_open_panel("Giải Tỏa")
			_show_giai_toa()))
	if engine.can_exchange(p["id"], "rare"):
		roll_extras.add_child(_small_btn("Đổi đặc sản 3 miền → thẻ hiếm", func(): _emit({"action": "exchange", "kind": "rare"})))
	if engine.can_exchange(p["id"], "common"):
		roll_extras.add_child(_small_btn("Đổi 3 đặc sản cùng miền → thẻ", func(): _emit({"action": "exchange", "kind": "common"})))
	_pop_roll_area()


## Không phải lượt của bạn: nút xám, không bấm được, ghi rõ đang chờ ai.
func show_roll_waiting(player_name: String) -> void:
	_clear_extras()
	roll_title.text = ""
	roll_hint.text = "Lượt của %s" % player_name
	roll_btn.set_waiting()
	if not roll_area.visible:
		_pop_roll_area()


func hide_roll() -> void:
	if roll_area.visible:
		roll_area.visible = false


func _pop_roll_area() -> void:
	roll_area.visible = true
	roll_area.modulate.a = 0.0
	roll_btn.scale = Vector2.ONE * 0.6
	roll_btn.pivot_offset = roll_btn.custom_minimum_size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(roll_area, "modulate:a", 1.0, 0.2)
	tw.tween_property(roll_btn, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_panel(title: String) -> void:
	decision_panel.visible = true
	decision_title.text = title
	roll_area.visible = false


func _clear_extras() -> void:
	for c in roll_extras.get_children():
		c.queue_free()


func _small_btn(text: String, cb: Callable) -> Button:
	var b := _button(text, cb)
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 14)
	return b


## Làm mờ các thành phần phụ (nhật ký) khi đang tung và đi, để tập trung vào hành trình.
func set_focus(on: bool) -> void:
	create_tween().tween_property(log_panel, "modulate:a", 0.25 if on else 1.0, 0.3)
	if on:
		info_panel.visible = false


# ---------------------------------------------------------------- banner thông tin ô / kết thúc lượt

func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _style(Color("#3e2723", 0.92), 14, Color("#ffca28")))
	_anchor(banner, Control.PRESET_CENTER_TOP, -260, 56, 260, 120)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.add_theme_color_override("font_color", Color("#fff8e1"))
	banner_label.add_theme_font_size_override("font_size", 17)
	banner.add_child(banner_label)
	banner.visible = false


func show_banner(text: String, duration: float = 2.0) -> void:
	banner_label.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2.ONE * 0.85
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	_banner_tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_banner_tw.tween_interval(duration)
	_banner_tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	_banner_tw.tween_callback(func(): banner.visible = false)


## Dòng tóm tắt ô vừa đáp xuống.
func tile_summary(t: int) -> String:
	var td := BoardData.tile(t)
	var name := BoardData.plain_name(t)
	if BoardData.is_property(t):
		var o: int = engine.owner[t]
		if o < 0:
			return "%s · Chưa có chủ · Giá %s xu" % [name, BoardData.money(td["price"])]
		return "%s · Chủ: %s · %s · Thuê %s xu" % [name, engine.players[o]["name"], engine.building_label(t), BoardData.money(engine.rent(t))]
	return name


func _tile_desc(t: int) -> String:
	var td := BoardData.tile(t)
	if td["type"] == BoardData.T.INFRA:
		return "Hạ tầng. Tiền thuê tăng theo số hạ tầng sở hữu: 50 / 100 / 200 / 400."
	if td["type"] == BoardData.T.TOLL:
		return "Trạm BOT: ai đi ngang qua trả %d xu cho chủ, dừng đúng trạm trả %d xu." % [GameEngine.TOLL_FEE, GameEngine.TOLL_FEE * GameEngine.TOLL_LAND_MULT]
	if not td.has("group"):
		return ""
	var g: Dictionary = BoardData.GROUPS[td["group"]]
	var base := _round5(td["price"] * EconomyConfig.get_default().rent_mult[0])
	return "Vùng %s (%s, %d tỉnh). Thuê cơ bản %s. Đặc sản: %s. Danh thắng: %s." % [
		g["name"], BoardData.REGION_NAMES[g["region"]], engine.group_tiles(td["group"]).size(),
		BoardData.money(base), td["specialty"], td["landmark"]]


func _show_golden() -> void:
	for c in decision_buttons.get_children():
		c.queue_free()
	decision_desc.text = "Chọn tổng điểm muốn tung:"
	for total in range(2, 13):
		var dest := (int(engine.players[human_id]["pos"]) + total) % BoardData.TILE_COUNT
		_add_btn("%d → %s" % [total, BoardData.plain_name(dest)], {"action": "golden", "total": total})


func _show_giai_toa() -> void:
	for c in decision_buttons.get_children():
		c.queue_free()
	decision_desc.text = "Chọn 1 ô nhà của đối thủ để hạ 1 cấp:"
	_show_tile_picker(engine.giai_toa_targets(human_id), func(t): _emit({"action": "giai_toa", "tile": t}))
	decision_buttons.add_child(_button("Quay lại", func(): show_decision(engine.pending)))


func _show_lottery(bets: Array) -> void:
	_lottery_number = 1
	var nums := HBoxContainer.new()
	var group := ButtonGroup.new()
	for n in range(1, 7):
		var b := Button.new()
		b.text = "  %d  " % n
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = n == 1
		b.pressed.connect(func(): _lottery_number = n)
		nums.add_child(b)
	decision_buttons.add_child(nums)
	var brk := Control.new()
	brk.custom_minimum_size = Vector2(620, 0)
	decision_buttons.add_child(brk)
	for amt in bets:
		decision_buttons.add_child(_button("Cược %s" % BoardData.money(amt), func(): _emit({"action": "bet", "amount": amt, "number": _lottery_number})))
	_add_btn("Không chơi", {"action": "pass"})


func _show_tile_picker(tiles: Array, cb: Callable) -> void:
	tile_scroll.visible = true
	_pick_callback = func(t):
		if tiles.has(t):
			cb.call(t)
	for t in tiles:
		var label := BoardData.plain_name(t)
		if engine.owner[t] >= 0:
			label += " (%s)" % String(engine.players[engine.owner[t]]["name"]).get_slice(" ", 0)
		var b := _button(label, func(): _pick_callback.call(t))
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_grid.add_child(b)
	pick_mode.emit(tiles)


func _add_btn(text: String, action: Dictionary, primary: bool = false) -> void:
	var b := _button(text, func(): _emit(action))
	if primary:
		b.add_theme_color_override("font_color", Color("#ffca28"))
	decision_buttons.add_child(b)


func _emit(action: Dictionary) -> void:
	clear_decision()
	action_chosen.emit(action)


# ---------------------------------------------------------------- kết thúc

func show_game_over(ev: Dictionary) -> void:
	clear_decision()
	waiting_label.text = ""
	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", _style(Color("#3e2723", 0.95), 16, Color("#ffca28")))
	_anchor(over_panel, Control.PRESET_CENTER, -240, -180, 240, 180)
	root.add_child(over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	over_panel.add_child(v)
	var title := Label.new()
	var win_name: String = engine.players[ev["winner"]]["name"]
	var reasons := {"last": "Người cuối cùng trụ lại", "domination": "Bá Chủ Ba Miền", "rounds": "Giàu nhất khi hết vòng"}
	title.text = "%s CHIẾN THẮNG!" % win_name.to_upper()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffca28"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = reasons.get(ev["reason"], "")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("#fff8e1"))
	v.add_child(sub)
	var ranking: Array = ev["ranking"]
	var worths: Array = ev["worths"]
	for i in ranking.size():
		var pid: int = ranking[i]
		var l := Label.new()
		var w: int = worths[i]
		l.text = "%d. %s — %s" % [i + 1, engine.players[pid]["name"], (BoardData.money(w) + " xu") if w > 0 else "Phá sản"]
		l.add_theme_color_override("font_color", Color(colors[pid]).lightened(0.3))
		v.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(_button("Chơi lại", func(): restart_requested.emit()))
	row.add_child(_button("Về menu", func(): menu_requested.emit()))


# ---------------------------------------------------------------- tiện ích

func _anchor(c: Control, preset: int, l: float, t: float, r: float, b: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _on_speed() -> void:
	_speed_idx = (_speed_idx + 1) % _speeds.size()
	speed_btn.text = "x%d" % int(_speeds[_speed_idx])
	speed_changed.emit(_speeds[_speed_idx])


func set_cam_auto(on: bool) -> void:
	cam_btn.text = "Điện ảnh" if on else "Toàn cảnh"


func hide_tile_info() -> void:
	info_panel.visible = false


func show_tile_info(t: int) -> void:
	var td := BoardData.tile(t)
	var ty: int = td["type"]
	var lines: Array = ["[b]%s[/b]" % BoardData.plain_name(t)]
	if ty == BoardData.T.PROVINCE:
		var g: Dictionary = BoardData.GROUPS[td["group"]]
		lines.append("Vùng %s · %s%s" % [g["name"], BoardData.REGION_NAMES[g["region"]], " · ven biển" if td.get("coastal", false) else ""])
		lines.append("Giá đất: %s xu" % BoardData.money(td["price"]))
		var o: int = engine.owner[t]
		if o >= 0:
			lines.append("Chủ: [color=%s]%s[/color] · %s" % [colors[o], engine.players[o]["name"], engine.building_label(t)])
			lines.append("Tiền thuê hiện tại: [b]%s xu[/b]" % BoardData.money(engine.rent(t)))
		else:
			lines.append("Chưa có chủ")
		var rents: Array = []
		var bt := engine.building_type(t)
		if bt:
			for l in range(1, GameEngine.LANDMARK + 1):
				rents.append(BoardData.money(_round5(td["price"] * bt.at(bt.rent_mult, l))))
			lines.append("Thuê %s cấp 1 / 2 / Danh Thắng: %s" % [bt.name, " / ".join(rents)])
		else:
			lines.append("Thuê đất trống: %s · chưa chọn loại công trình" % BoardData.money(_round5(td["price"] * float(EconomyConfig.get_default().rent_mult[0]))))
		lines.append("Đặc sản: %s" % td["specialty"])
		lines.append("Danh thắng: %s" % td["landmark"])
		if t == engine.festival_tile:
			lines.append("[color=#c62828]Đang có Lễ Hội![/color]")
	elif ty == BoardData.T.INFRA or ty == BoardData.T.TOLL:
		lines.append("Giá: %s xu" % BoardData.money(td["price"]))
		var o: int = engine.owner[t]
		lines.append(("Chủ: %s · thuê %s xu" % [engine.players[o]["name"], BoardData.money(engine.rent(t))]) if o >= 0 else "Chưa có chủ")
		if ty == BoardData.T.TOLL:
			lines.append("Ai đi ngang qua mất %d xu; dừng đúng trạm trả %d xu." % [GameEngine.TOLL_FEE, GameEngine.TOLL_FEE * GameEngine.TOLL_LAND_MULT])
		else:
			lines.append("Thuê theo số hạ tầng sở hữu: 50 / 100 / 200 / 400.")
	else:
		var desc := {
			BoardData.T.START: "Đi qua nhận lương 200 xu, dừng đúng ô thưởng thêm 200.",
			BoardData.T.JAIL: "Kẹt Xe: tung đôi, gọi xe ôm hoặc đi đường tắt để thoát. Trượt 2 lần thì CSGT phân luồng.",
			BoardData.T.FESTIVAL: "Chọn 1 tỉnh của bạn tổ chức Lễ Hội: tiền thuê ×2.",
			BoardData.T.TRAIN: "Lượt sau trả vé để đi thẳng tới bất kỳ ô nào.",
			BoardData.T.KHI_VAN: "Rút thẻ Khí Vận: may rủi, có hiệu lực ngay.",
			BoardData.T.CO_HOI: "Rút thẻ Cơ Hội: cơ hội làm ăn, bạn được quyết định.",
			BoardData.T.TAX: "Nộp 10% tổng tài sản (tối đa 200) vào Quỹ Từ Thiện.",
			BoardData.T.MARKET: "Đổi đặc sản lấy Thẻ Kỹ Năng hoặc mua đặc sản.",
			BoardData.T.LOTTERY: "Chọn số 1–6 và đặt cược, trúng nhận ×5.",
			BoardData.T.CHARITY: "Dừng ở đây nhận toàn bộ quỹ: [b]%s xu[/b]." % BoardData.money(engine.charity_pot),
		}
		lines.append(String(desc.get(ty, "")))
	info_label.text = "\n".join(lines)
	info_panel.visible = true


func set_speed_display(speed: float) -> void:
	_speed_idx = maxi(0, _speeds.find(speed))
	speed_btn.text = "x%d" % int(_speeds[_speed_idx])


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): Audio.play("click"))
	b.pressed.connect(cb)
	return b


func _style(bg: Color, radius: int, border: Color = Color.TRANSPARENT, border_left: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if border.a > 0:
		if border_left >= 0:
			s.border_width_left = maxi(border_left, 6)
			s.border_width_top = 0 if border_left == 0 else 2
			s.border_width_bottom = 0 if border_left == 0 else 2
			s.border_width_right = 0 if border_left == 0 else 2
		else:
			s.set_border_width_all(2)
		s.border_color = border
	return s


static func _round5(v: float) -> int:
	return int(round(v / 5.0)) * 5
