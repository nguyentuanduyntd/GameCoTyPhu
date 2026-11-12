class_name TopBar
extends PanelContainer
## Thanh trên cùng: icon mùa + tên mùa/sự kiện · đồng hồ + "Vòng x/y" + thanh tiến trình · Quỹ có icon.
## Đổi mùa: icon nảy, tông màu thanh chuyển mượt theo mùa. Quỹ thay đổi: con số "nhói" lên.

var _season_icon: TextureRect
var _season: Label
var _round: Label
var _bar: ProgressBar
var _fund: Label
var _fund_icon: TextureRect
var _last_season := -1
var _last_pot := -1


func _ready() -> void:
	theme_type_variation = "WoodPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_season_icon = _icon("spring", 28)
	row.add_child(_season_icon)
	_season = _label(16)
	row.add_child(_season)
	row.add_child(_sep())
	row.add_child(_icon("clock", 22))
	_round = _label(16)
	row.add_child(_round)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(90, 10)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	row.add_child(_sep())
	_fund_icon = _icon("fund", 24)
	row.add_child(_fund_icon)
	_fund = _label(16)
	_fund.theme_type_variation = "MoneyLabel"
	_fund.add_theme_font_size_override("font_size", 17)
	_fund.resized.connect(func(): _fund.pivot_offset = _fund.size / 2.0)
	row.add_child(_fund)
	resized.connect(func(): pivot_offset = size / 2.0)


func update(engine: GameEngine) -> void:
	var r := mini(engine.round_num, engine.max_rounds)
	_round.text = "Vòng %d/%d" % [r, engine.max_rounds]
	_bar.max_value = engine.max_rounds
	_bar.value = r
	var name: String = GameEngine.SEASON_NAMES[engine.season]
	var ev: String = engine.season_event.get("name", "")
	_season.text = name + ((" · " + ev) if ev != "" else "")
	_season.tooltip_text = GameEngine.SEASON_DESC[engine.season]
	tooltip_text = GameEngine.SEASON_DESC[engine.season]
	if engine.season != _last_season:
		_season_icon.texture = UiIcons.season_icon(engine.season)
		if _last_season >= 0:
			_pop(_season_icon, 1.5)
		var tint := Color.WHITE.lerp(UiPalette.get_default().seasons[engine.season], 0.45)
		create_tween().tween_property(self, "self_modulate", tint, 0.8)
		_last_season = engine.season
	set_pot(engine.charity_pot)


func set_pot(v: int) -> void:
	_fund.text = BoardData.money(v)
	_fund.tooltip_text = "Quỹ Từ Thiện: ai dừng ở ô Quỹ nhận hết"
	if _last_pot >= 0 and v != _last_pot:
		_pop(_fund, 1.35)
		_pop(_fund_icon, 1.3)
	_last_pot = v


func _pop(c: Control, s: float) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * s, 0.1)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _label(size: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = "LightLabel"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.bold_font())
	return l


func _icon(name: String, s: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiIcons.get_icon(name)
	r.custom_minimum_size = Vector2(s, s)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color(UiPalette.get_default().gold, 0.35)
	c.custom_minimum_size = Vector2(2, 22)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c
