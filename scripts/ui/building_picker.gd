class_name BuildingPicker
extends PanelContainer
## Panel chọn loại công trình: 4 thẻ (biểu tượng, tên, lợi ích, giá xây, nút "Xây"); thẻ không đủ tiền thì mờ
## và ghi lý do; nút "Để sau" giữ ô trống. Chỉ phát signal — game.gd chuyển lựa chọn vào engine.

signal chosen(type_id: String)
signal later

var _engine: GameEngine
var _title: Label
var _sub: Label
var _cards: GridContainer
var _sent := false


func setup(engine: GameEngine) -> void:
	_engine = engine
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3e2723", 0.96)
	sb.set_corner_radius_all(18)
	sb.border_color = Color("#ffca28")
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 16)
	add_theme_stylebox_override("panel", sb)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -470
	offset_right = 470
	offset_top = -230
	offset_bottom = 230
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	_title = _label(26, Color("#ffca28"))
	v.add_child(_title)
	_sub = _label(15, Color("#d7ccc8"))
	v.add_child(_sub)
	_cards = GridContainer.new()
	_cards.columns = 4
	_cards.add_theme_constant_override("h_separation", 10)
	_cards.add_theme_constant_override("v_separation", 10)
	v.add_child(_cards)
	var later_btn := Button.new()
	later_btn.text = "Để sau (giữ đất trống, quay lại ô này để xây)"
	later_btn.custom_minimum_size = Vector2(0, 40)
	later_btn.focus_mode = Control.FOCUS_NONE
	later_btn.pressed.connect(func():
		Audio.play("click")
		_send("", true))
	v.add_child(later_btn)
	resized.connect(_on_resized)
	visible = false


func open(pend: Dictionary) -> void:
	_sent = false
	var t: int = pend["tile"]
	var pid: int = pend["p"]
	var price: int = BoardData.tile(t)["price"]
	_title.text = "Chọn công trình cho %s" % BoardData.plain_name(t)
	_sub.text = "Giá đất %s xu · bạn có %s xu · lên cấp 3 thành Danh Thắng %s" % [BoardData.money(price), BoardData.money(_engine.players[pid]["cash"]), BoardData.tile(t)["landmark"]]
	for c in _cards.get_children():
		c.queue_free()
	var cfg := EconomyConfig.get_default()
	for o in pend["options"]:
		_cards.add_child(_card(cfg.building(o["id"]), o, price))
	_on_resized()
	visible = true
	modulate.a = 0.0
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.85
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false)


func autopress() -> void:
	for card in _cards.get_children():
		var b := card.find_child("BuildBtn", true, false) as Button
		if b and not b.disabled:
			b.pressed.emit()
			return
	_send("", true)


func _send(id: String, is_later: bool) -> void:
	if _sent:
		return
	_sent = true
	close()
	if is_later:
		later.emit()
	else:
		chosen.emit(id)


func _on_resized() -> void:
	# màn hình hẹp (điện thoại dọc): 2 × 2 thẻ
	var vp := get_viewport_rect().size
	_cards.columns = 4 if vp.x >= 900 else 2


func _card(bt: BuildingType, opt: Dictionary, price: int) -> Control:
	var ok: bool = opt["ok"]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff8e1") if ok else Color("#9e9e9e")
	sb.set_corner_radius_all(14)
	sb.border_color = bt.color
	sb.set_border_width_all(4)
	sb.border_width_top = 10
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(205, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var icon := BuildingIcon.new()
	icon.kind = bt.id
	icon.col = bt.color
	icon.custom_minimum_size = Vector2(0, 74)
	v.add_child(icon)
	var name_l := _label(21, bt.color.darkened(0.35))
	name_l.text = bt.name
	v.add_child(name_l)
	var desc := _label(13, Color("#4e342e"))
	desc.text = bt.desc
	desc.custom_minimum_size = Vector2(180, 0)
	v.add_child(desc)
	var stats := _label(14, Color("#3e2723"))
	var lines: Array = ["Thuê cấp 1: %s xu" % BoardData.money(_r5(price * bt.at(bt.rent_mult, 1)))]
	match bt.id:
		"homestay":
			lines.append("+%s xu mỗi lần qua Km 0" % BoardData.money(_r5(price * bt.at(bt.lap_income, 1))))
		"market":
			lines.append("Phí chợ %s xu/lượt (%d%% cho bạn)" % [BoardData.money(_r5(price * bt.at(bt.pass_fee, 1))), int(bt.fee_owner_share * 100)])
		"workshop":
			lines.append("+%d đặc sản mỗi vòng" % int(bt.at(bt.specialties_per_round, 1)))
		"restaurant":
			lines.append("Thuê cấp 3: %s xu" % BoardData.money(_r5(price * bt.at(bt.rent_mult, 3))))
	stats.text = "\n".join(lines)
	v.add_child(stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var btn := Button.new()
	btn.name = "BuildBtn"
	btn.text = "Xây — %s xu" % BoardData.money(opt["cost"])
	btn.custom_minimum_size = Vector2(0, 42)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": bt.color.darkened(0.15), "hover": bt.color, "pressed": bt.color.darkened(0.35), "disabled": Color(0.4, 0.4, 0.4)}[st]
		b.set_corner_radius_all(10)
		b.border_color = Color("#ffca28") if st != "disabled" else Color(0.5, 0.5, 0.5)
		b.set_border_width_all(2)
		btn.add_theme_stylebox_override(st, b)
	btn.add_theme_color_override("font_color", Color.WHITE)
	if ok:
		var id := bt.id
		btn.pressed.connect(func():
			Audio.play("click")
			_send(id, false))
		panel.mouse_entered.connect(func(): _hover(panel, true))
		panel.mouse_exited.connect(func(): _hover(panel, false))
	else:
		btn.disabled = true
		btn.tooltip_text = "Không đủ tiền"
		panel.modulate = Color(1, 1, 1, 0.6)
		var why := _label(13, Color("#b71c1c"))
		why.text = "Không đủ tiền (cần %s xu)" % BoardData.money(opt["cost"])
		v.add_child(why)
	v.add_child(btn)
	return panel


func _hover(panel: Control, on: bool) -> void:
	panel.pivot_offset = panel.size / 2.0
	create_tween().tween_property(panel, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.12).set_trans(Tween.TRANS_BACK)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func _r5(v: float) -> int:
	return int(round(v / 5.0)) * 5


## Biểu tượng 2D đơn giản cho từng loại công trình.
class BuildingIcon extends Control:
	var kind := ""
	var col := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 34.0, col.lightened(0.6))
		draw_arc(c, 34.0, 0, TAU, 48, col, 3.0, true)
		match kind:
			"restaurant":
				# bát phở + đũa + hơi nóng
				var bowl := PackedVector2Array()
				for k in 17:
					var a := PI * k / 16.0
					bowl.append(c + Vector2(cos(a) * 20.0, sin(a) * 14.0 + 2.0))
				draw_colored_polygon(bowl, Color("#e53935"))
				draw_line(c + Vector2(-22, 2), c + Vector2(22, 2), Color("#b71c1c"), 3.0)
				draw_line(c + Vector2(4, 2), c + Vector2(20, -20), Color("#6d4c41"), 3.0)
				draw_line(c + Vector2(9, 2), c + Vector2(25, -17), Color("#6d4c41"), 3.0)
				for k in 3:
					draw_arc(c + Vector2(-10 + k * 8, -10), 4.0, PI * 0.5, PI * 1.5, 8, Color(1, 1, 1, 0.9), 2.0)
			"homestay":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -4), c + Vector2(24, -4), c + Vector2(0, -24)]), Color("#c8a165"))
				draw_rect(Rect2(c + Vector2(-17, -4), Vector2(34, 16)), Color("#a1887f"))
				draw_rect(Rect2(c + Vector2(-4, 1), Vector2(8, 11)), Color("#ffe082"))
				for x in [-14, -5, 5, 14]:
					draw_line(c + Vector2(x, 12), c + Vector2(x, 22), Color("#5d4037"), 3.0)
			"market":
				for k in 4:
					var x0 := -24.0 + k * 12.0
					draw_colored_polygon(PackedVector2Array([c + Vector2(x0, -2), c + Vector2(x0 + 12, -2), c + Vector2(x0 + 6, -18)]), col if k % 2 == 0 else Color.WHITE)
				draw_rect(Rect2(c + Vector2(-22, -2), Vector2(44, 4)), Color("#6d4c41"))
				draw_rect(Rect2(c + Vector2(-18, 8), Vector2(36, 8)), Color("#d7a86e"))
				for k in 4:
					draw_circle(c + Vector2(-12 + k * 8, 6), 4.0, [Color("#e53935"), Color("#fdd835"), Color("#43a047"), Color("#ff9800")][k])
			"workshop":
				draw_rect(Rect2(c + Vector2(-22, -4), Vector2(36, 22)), Color("#90a4ae"))
				for k in 3:
					var x0 := -22.0 + k * 12.0
					draw_colored_polygon(PackedVector2Array([c + Vector2(x0, -4), c + Vector2(x0 + 12, -4), c + Vector2(x0 + 12, -14)]), col)
				draw_rect(Rect2(c + Vector2(16, -22), Vector2(7, 40)), Color("#8d6e63"))
				draw_circle(c + Vector2(20, -26), 5.0, Color(0.85, 0.85, 0.85, 0.9))
				draw_circle(c + Vector2(25, -31), 4.0, Color(0.85, 0.85, 0.85, 0.7))
				draw_rect(Rect2(c + Vector2(-8, 6), Vector2(8, 12)), Color("#3e2723"))
