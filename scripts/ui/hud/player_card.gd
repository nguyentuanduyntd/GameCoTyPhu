class_name PlayerCard
extends PanelContainer
## Thẻ nhân vật bên trái HUD: avatar tròn, tên + nghề, số xu (đếm chạy mượt, nháy xanh/đỏ, "+X/−X" bay lên),
## hàng chỉ số có icon (Đất, Nhà, Đặc sản B/T/N), dòng trạng thái; thẻ đang đến lượt nổi bật (phóng nhẹ,
## viền phát sáng màu người chơi, mũi tên lượt), các thẻ khác hơi mờ.

var pid := 0
var color := Color.WHITE
var _avatar: TextureRect
var _initial: Label
var _name: Label
var _job: Label
var _money: Label
var _delta_lbl: Label
var _stats: HBoxContainer
var _stat_land: Label
var _stat_house: Label
var _stat_spec: Label
var _status: Label
var _parts: Array = []
## Ghi chú online (đồng hồ suy nghĩ, mất kết nối) — hiện đầu dòng trạng thái.
var _net_note := ""
var _net_urgent := false
var _turn_icon: TextureRect
var _glow: Panel
var _shown := 0
var _cash_tw: Tween
var _focus_tw: Tween
var _active := false

const AVATAR_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length(UV - vec2(0.5));
	c.a *= smoothstep(0.5, 0.47, d);
	COLOR = c * COLOR;
}
"""
static var _avatar_mat: ShaderMaterial


func setup(p: Dictionary, col: Color, is_human: bool) -> void:
	pid = p["id"]
	color = col
	theme_type_variation = "WoodPanel"
	custom_minimum_size = Vector2(228, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = Panel.new()
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0, 0, 0, 0)
	gs.set_corner_radius_all(14)
	gs.border_color = col
	gs.set_border_width_all(3)
	gs.shadow_color = Color(col, 0.65)
	gs.shadow_size = 12
	gs.set_expand_margin_all(4)
	_glow.add_theme_stylebox_override("panel", gs)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.show_behind_parent = true
	_glow.visible = false
	add_child(_glow)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	# avatar tròn trên nền màu người chơi
	var av_box := Control.new()
	av_box.custom_minimum_size = Vector2(54, 54)
	av_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(av_box)
	var ring := _Ring.new()
	ring.col = col
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	av_box.add_child(ring)
	_initial = Label.new()
	_initial.text = String(p["name"]).replace("Máy · ", "").substr(0, 1)
	_initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial.theme_type_variation = "LightTitleLabel"
	av_box.add_child(_initial)
	_avatar = TextureRect.new()
	_avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar.offset_left = 3
	_avatar.offset_top = 3
	_avatar.offset_right = -3
	_avatar.offset_bottom = -3
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if _avatar_mat == null:
		var sh := Shader.new()
		sh.code = AVATAR_SHADER
		_avatar_mat = ShaderMaterial.new()
		_avatar_mat.shader = sh
	_avatar.material = _avatar_mat
	av_box.add_child(_avatar)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_name = Label.new()
	_name.theme_type_variation = "LightLabel"
	_name.text = String(p["name"]) + ("  •" if is_human else "")
	_name.add_theme_color_override("font_color", col.lightened(0.45))
	_name.add_theme_font_override("font", UiTheme.bold_font())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	top.add_child(_name)
	_turn_icon = TextureRect.new()
	_turn_icon.texture = UiIcons.get_icon("turn")
	_turn_icon.custom_minimum_size = Vector2(18, 18)
	_turn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_turn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_turn_icon.visible = false
	top.add_child(_turn_icon)
	_job = Label.new()
	_job.theme_type_variation = "LightLabel"
	_job.text = CardsData.character(p["character"])["name"]
	_job.add_theme_font_size_override("font_size", 12)
	_job.modulate = Color(1, 1, 1, 0.7)
	v.add_child(_job)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 4)
	v.add_child(money_row)
	money_row.add_child(_icon("coin", 20))
	_money = Label.new()
	_money.theme_type_variation = "MoneyLabel"
	money_row.add_child(_money)
	_delta_lbl = Label.new()
	_delta_lbl.theme_type_variation = "MoneyLabel"
	_delta_lbl.add_theme_font_size_override("font_size", 15)
	_delta_lbl.modulate.a = 0.0
	money_row.add_child(_delta_lbl)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 3)
	_stats.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(_stats)
	_stat_land = _stat("land")
	_stat_house = _stat("house")
	_stat_spec = _stat("specialty")
	_status = Label.new()
	_status.theme_type_variation = "LightLabel"
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", UiPalette.get_default().gold)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	v.add_child(_status)
	_shown = p["cash"]
	_set_money_text(_shown)
	resized.connect(func(): pivot_offset = Vector2(0, size.y / 2.0))


func set_avatar(tex: Texture2D) -> void:
	_avatar.texture = tex
	_initial.visible = tex == null


## Tiền thay đổi: số đếm chạy, nháy màu, "+X/−X" nhỏ bay lên cạnh số.
func set_cash(cash: int, animate: bool, duration: float) -> void:
	var from := _shown
	_shown = cash
	if _cash_tw and _cash_tw.is_valid():
		_cash_tw.kill()
	if not animate or from == cash:
		_set_money_text(cash)
		_money.modulate = Color.WHITE
		return
	var pal := UiPalette.get_default()
	var up := cash > from
	_cash_tw = create_tween()
	_money.modulate = (pal.money_gain if up else pal.money_loss).lightened(0.3)
	_cash_tw.tween_method(func(v: float): _set_money_text(int(round(v))), float(from), float(cash), maxf(duration, 0.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cash_tw.tween_property(_money, "modulate", Color.WHITE, 0.25)
	_delta_lbl.text = ("+" if up else "−") + BoardData.money(absi(cash - from))
	_delta_lbl.add_theme_color_override("font_color", pal.money_gain if up else pal.money_loss)
	_delta_lbl.position.y = 0
	var dt := create_tween()
	_delta_lbl.modulate.a = 1.0
	dt.tween_property(_delta_lbl, "modulate:a", 0.0, maxf(duration, 0.1) + 0.5).set_delay(0.3)


func refresh(engine: GameEngine, p: Dictionary) -> void:
	if int(p["cash"]) != _shown and not (_cash_tw and _cash_tw.is_running()):
		set_cash(p["cash"], false, 0.0)
	if not p["alive"]:
		_stat_land.text = "—"
		_stat_house.text = "—"
		_stat_spec.text = "Phá sản"
		modulate = Color(1, 1, 1, 0.45)
		_status.visible = false
		return
	var owned := engine.owned_tiles(pid)
	var houses := 0
	for t in owned:
		if engine.level[t] > 0:
			houses += 1
	var sc := engine.specialty_counts(pid)
	_stat_land.text = str(owned.size())
	_stat_house.text = str(houses)
	_stat_spec.text = "%d/%d/%d" % [sc[0], sc[1], sc[2]]
	_stats.tooltip_text = "Đất %d · Nhà %d · Đặc sản Bắc/Trung/Nam %d/%d/%d" % [owned.size(), houses, sc[0], sc[1], sc[2]]
	var parts: Array = []
	if p["in_jail"]:
		parts.append("Đang kẹt xe")
	if p["train_pending"]:
		parts.append("Chờ đi tàu")
	if p["one_die"]:
		parts.append("Lượt sau tung 1 viên")
	for c in p["cards"]:
		parts.append(CardsData.SKILLS[c]["name"])
	for d in p["delayed"]:
		var amt: int = d["amount"]
		parts.append("%s %s%s (%d lượt)" % [d["text"], "+" if amt > 0 else "−", BoardData.money(absi(amt)), d["turns"]])
	_parts = parts
	_render_status()


func _render_status() -> void:
	var all: Array = []
	if _net_note != "":
		all.append(_net_note)
	all.append_array(_parts)
	_status.text = " · ".join(all)
	_status.visible = all.size() > 0
	if _net_urgent:
		_status.add_theme_color_override("font_color", UiPalette.get_default().danger.lightened(0.35))
	else:
		_status.add_theme_color_override("font_color", UiPalette.get_default().gold)


## Online: hiện đồng hồ suy nghĩ / "Mất kết nối" trên thẻ.
func set_net_note(text: String, urgent: bool = false) -> void:
	if text == _net_note and urgent == _net_urgent:
		return
	_net_note = text
	_net_urgent = urgent
	_render_status()


func set_active(on: bool) -> void:
	if on == _active and _focus_tw == null:
		pass
	_active = on
	_glow.visible = on
	_turn_icon.visible = on
	if _focus_tw and _focus_tw.is_valid():
		_focus_tw.kill()
	_focus_tw = create_tween().set_parallel(true)
	_focus_tw.tween_property(self, "scale", Vector2.ONE * (1.04 if on else 0.97), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if modulate.a > 0.5:
		_focus_tw.tween_property(self, "modulate", Color(1, 1, 1, 1.0 if on else 0.85), 0.25)


func _stat(icon: String) -> Label:
	_stats.add_child(_icon(icon, 15))
	var l := Label.new()
	l.theme_type_variation = "LightLabel"
	l.add_theme_font_size_override("font_size", 12)
	l.custom_minimum_size = Vector2(20, 0)
	_stats.add_child(l)
	return l


func _set_money_text(v: int) -> void:
	_money.text = BoardData.money(v)


func _icon(name: String, s: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiIcons.get_icon(name)
	r.custom_minimum_size = Vector2(s, s)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


class _Ring extends Control:
	var col := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_circle(c, r, UiPalette.get_default().wood_dark)
		draw_circle(c, r - 1.5, col.darkened(0.15))
		draw_circle(c, r - 4.0, col.lightened(0.35))
