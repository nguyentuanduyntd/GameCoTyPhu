class_name AuctionPanel
extends PanelContainer
## Panel đấu giá (cùng phong cách bảng quyết định của HUD).
## Chỉ hiển thị và phát signal; luật nằm ở AuctionRules, game.gd chuyển hành động vào engine.

signal bid(steps: int)
signal fold

var _engine: GameEngine
var _colors: Array = []
var _human := 0
var _title: Label
var _list_label: Label
var _price_label: Label
var _leader_label: Label
var _status: Label
var _chips: HBoxContainer
var _chip_map := {}
var _out := {}
var _buttons: HBoxContainer
var _timer_bar: ProgressBar
var _timer_label: Label
var _time_left := 0.0
var _time_total := 0.0
var _counting := false
var _sent := false


func setup(engine: GameEngine, colors: Array, human: int) -> void:
	_engine = engine
	_colors = colors
	_human = human
	_build()
	visible = false


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3e2723", 0.95)
	sb.set_corner_radius_all(16)
	sb.border_color = Color("#ffca28")
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 16)
	add_theme_stylebox_override("panel", sb)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -360
	offset_right = 360
	offset_top = -14
	offset_bottom = -14
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = _label(26, Color("#ffca28"))
	v.add_child(_title)
	_list_label = _label(15, Color("#d7ccc8"))
	v.add_child(_list_label)
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 24)
	v.add_child(price_row)
	_price_label = _label(40, Color("#fff59d"))
	_price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_price_label.resized.connect(func(): _price_label.pivot_offset = _price_label.size / 2.0)
	price_row.add_child(_price_label)
	_leader_label = _label(18, Color("#fff8e1"))
	_leader_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	price_row.add_child(_leader_label)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 6)
	v.add_child(_chips)
	_status = _label(16, Color("#ffe0b2"))
	v.add_child(_status)
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 8)
	v.add_child(timer_row)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#ffca28")
	fg.set_corner_radius_all(5)
	_timer_bar.add_theme_stylebox_override("background", bg)
	_timer_bar.add_theme_stylebox_override("fill", fg)
	timer_row.add_child(_timer_bar)
	_timer_label = _label(16, Color("#fff8e1"))
	_timer_label.custom_minimum_size = Vector2(40, 0)
	timer_row.add_child(_timer_label)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 10)
	v.add_child(_buttons)


# ---------------------------------------------------------------- cập nhật từ sự kiện

func open(ev: Dictionary) -> void:
	var t: int = ev["tile"]
	_title.text = "ĐẤU GIÁ — %s" % BoardData.plain_name(t).to_upper()
	_list_label.text = "Giá niêm yết %s xu · Khởi điểm %s · Bước giá %s" % [BoardData.money(ev["list_price"]), BoardData.money(ev["start"]), BoardData.money(ev["step"])]
	_price_label.text = "Chưa có giá"
	_leader_label.text = ""
	_status.text = ""
	_clear_buttons()
	_hide_timer()
	for c in _chips.get_children():
		c.queue_free()
	_chip_map.clear()
	_out.clear()
	for pid in ev["bidders"]:
		_add_chip(pid, "")
	for pid in ev["excluded"]:
		_add_chip(pid, "không đủ tiền")
	_add_chip(ev["passer"], "đã bỏ qua")
	visible = true
	modulate.a = 0.0
	scale = Vector2.ONE * 0.9
	pivot_offset = Vector2(size.x / 2.0, size.y)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func on_bid(pid: int, price: int) -> void:
	_price_label.text = "%s xu" % BoardData.money(price)
	_leader_label.text = "Dẫn đầu: %s" % _engine.players[pid]["name"]
	_status.text = "%s trả %s xu" % [_engine.players[pid]["name"], BoardData.money(price)]
	var tw := create_tween()
	tw.tween_property(_price_label, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(_price_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	for id in _chip_map.keys():
		if not _out.has(id):
			_set_chip_state(id, "leader" if id == pid else "")


func on_fold(pid: int, reason: String) -> void:
	_status.text = "%s %s" % [_engine.players[pid]["name"], reason]
	_set_chip_state(pid, "out", reason)


func on_thinking(pid: int) -> void:
	_status.text = "%s đang cân nhắc..." % _engine.players[pid]["name"]
	_clear_buttons()
	_hide_timer()


func show_result(winner: int, price: int) -> void:
	_clear_buttons()
	_hide_timer()
	if winner >= 0:
		_status.text = "%s thắng với giá %s xu!" % [_engine.players[winner]["name"], BoardData.money(price)]
		_set_chip_state(winner, "winner")
	else:
		_status.text = "Không ai trả giá — ô vẫn chưa có chủ."


func close() -> void:
	_counting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)


# ---------------------------------------------------------------- lượt của người chơi

## Hiện nút trả giá cho người chơi thật, kèm đồng hồ đếm ngược (hết giờ coi như bỏ).
func prompt(pend: Dictionary, seconds: float) -> void:
	_clear_buttons()
	_sent = false
	var a := {"leader": pend["leader"], "start": pend["start"], "price": pend["price"], "step": pend["step"]}
	var cash: int = _engine.players[_human]["cash"]
	var options: Array = pend["options"]
	_status.text = "Đến lượt bạn trả giá! (bạn có %s xu)" % BoardData.money(cash)
	var max_steps := EconomyConfig.get_default().auction_max_raise_steps
	for k in range(1, max_steps + 1):
		var price := AuctionRules.price_for(a, k)
		var txt := ("Trả %s" % BoardData.money(price)) if int(pend["leader"]) < 0 and k == 1 else ("Trả +%s → %s" % [BoardData.money(int(pend["step"]) * k), BoardData.money(price)])
		var b := _button(txt, Color("#2e7d32"))
		if not options.has(k):
			b.disabled = true
			b.tooltip_text = "Không đủ tiền (cần %s xu)" % BoardData.money(price)
		else:
			b.pressed.connect(func(): _send_bid(k))
		_buttons.add_child(b)
	var f := _button("Bỏ", Color("#8d1b1b"))
	f.pressed.connect(_send_fold)
	_buttons.add_child(f)
	_time_total = seconds
	_time_left = seconds
	_counting = true
	_timer_bar.visible = true
	_timer_label.visible = true


func autopress() -> void:
	for b in _buttons.get_children():
		if b is Button and not b.disabled:
			(b as Button).pressed.emit()
			return


func _process(delta: float) -> void:
	if not _counting:
		return
	_time_left -= delta
	_timer_bar.value = 100.0 * maxf(_time_left, 0.0) / maxf(_time_total, 0.01)
	_timer_label.text = "%ds" % ceili(maxf(_time_left, 0.0))
	if _time_left <= 3.0:
		(_timer_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("#ff5252")
	if _time_left <= 0.0:
		_status.text = "Hết giờ — coi như bỏ."
		_send_fold()


func _send_bid(k: int) -> void:
	if _sent:
		return
	_sent = true
	_counting = false
	_clear_buttons()
	_hide_timer()
	bid.emit(k)


func _send_fold() -> void:
	if _sent:
		return
	_sent = true
	_counting = false
	_clear_buttons()
	_hide_timer()
	fold.emit()


# ---------------------------------------------------------------- tiện ích

func _add_chip(pid: int, note: String) -> void:
	var chip := PanelContainer.new()
	var l := Label.new()
	l.text = String(_engine.players[pid]["name"]).replace("Máy · ", "")
	l.add_theme_font_size_override("font_size", 14)
	chip.add_child(l)
	_chips.add_child(chip)
	_chip_map[pid] = chip
	_set_chip_state(pid, "out" if note != "" else "", note)


func _set_chip_state(pid: int, st: String, note: String = "") -> void:
	if not _chip_map.has(pid):
		return
	var chip: PanelContainer = _chip_map[pid]
	var col := Color(_colors[pid])
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	var l: Label = chip.get_child(0)
	match st:
		"leader", "winner":
			sb.bg_color = col.darkened(0.2)
			sb.border_color = Color("#ffd54f")
			sb.set_border_width_all(3)
			l.add_theme_color_override("font_color", Color.WHITE)
			chip.modulate.a = 1.0
		"out":
			_out[pid] = true
			sb.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			l.add_theme_color_override("font_color", Color("#9e9e9e"))
			chip.modulate.a = 0.75
			chip.tooltip_text = note
			if not l.text.begins_with("✕"):
				l.text = "✕ " + l.text
		_:
			sb.bg_color = col.darkened(0.45)
			sb.border_color = col
			sb.set_border_width_all(2)
			l.add_theme_color_override("font_color", Color.WHITE)
			chip.modulate.a = 1.0
	chip.add_theme_stylebox_override("panel", sb)


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()


func _hide_timer() -> void:
	_counting = false
	_timer_bar.visible = false
	_timer_label.visible = false
	(_timer_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("#ffca28")


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": col, "hover": col.lightened(0.15), "pressed": col.darkened(0.2), "disabled": Color(0.3, 0.3, 0.3)}[st]
		sb.set_corner_radius_all(12)
		sb.border_color = Color("#ffca28") if st != "disabled" else Color(0.45, 0.45, 0.45)
		sb.set_border_width_all(2)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func(): Audio.play("click"))
	return b
