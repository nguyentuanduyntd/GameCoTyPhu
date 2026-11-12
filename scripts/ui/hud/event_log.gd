class_name EventLog
extends PanelContainer
## Khung nhật ký: nền gỗ đặc (đọc rõ trên mọi nền 3D), mỗi dòng có icon theo loại sự kiện, tên người chơi tô
## đúng màu, dòng mới nhất nổi bật, dòng cũ mờ dần, tự cuộn mượt; nút thu gọn/mở rộng; khi không có sự kiện
## mới một lúc thì tự giảm độ rõ để bớt che bàn cờ (rê chuột vào thì rõ lại).

const MAX_ROWS := 40
const IDLE_SECONDS := 6.0

var _scroll: ScrollContainer
var _list: VBoxContainer
var _toggle: Button
var _names: Array = []   # [[tên, màu], ...]
var _idle := 0.0
var _collapsed := false
var _hover := false
var _scroll_tw: Tween


func setup(players: Array, colors: Array) -> void:
	for p in players:
		_names.append([String(p["name"]), colors[p["id"]]])
	# tên dài trước để không thay nhầm một phần tên
	_names.sort_custom(func(a, b): return String(a[0]).length() > String(b[0]).length())
	theme_type_variation = "WoodPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = UiIcons.get_icon("log")
	ic.custom_minimum_size = Vector2(20, 20)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(ic)
	var title := Label.new()
	title.text = "Nhật ký"
	title.theme_type_variation = "LightLabel"
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_toggle = Button.new()
	_toggle.theme_type_variation = "GhostButton"
	_toggle.text = "–"
	_toggle.tooltip_text = "Thu gọn / mở rộng nhật ký"
	_toggle.custom_minimum_size = Vector2(30, 26)
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(_on_toggle)
	head.add_child(_toggle)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 200)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	_scroll.add_child(_list)
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)


func _process(delta: float) -> void:
	_idle += delta
	var target := 1.0 if (_hover or _idle < IDLE_SECONDS) else 0.6
	modulate.a = lerpf(modulate.a, target, 1.0 - exp(-4.0 * delta))


func add_entry(text: String) -> void:
	_idle = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = UiIcons.get_icon(_icon_for(text))
	ic.custom_minimum_size = Vector2(18, 18)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_color_override("default_color", UiPalette.get_default().paper)
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.add_theme_font_size_override("bold_font_size", 13)
	rt.text = _colorize(text)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rt)
	_list.add_child(row)
	while _list.get_child_count() > MAX_ROWS:
		var old := _list.get_child(0)
		_list.remove_child(old)
		old.queue_free()
	_restyle()
	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.25)
	_scroll_to_end.call_deferred()


func _restyle() -> void:
	# dòng mới nhất rõ nhất, các dòng cũ mờ dần
	var n := _list.get_child_count()
	for i in n:
		var row: Control = _list.get_child(i)
		var age := n - 1 - i
		row.self_modulate = Color(1, 1, 1, clampf(1.0 - age * 0.09, 0.45, 1.0))
		var rt := row.get_child(1) as RichTextLabel
		rt.add_theme_color_override("default_color", Color("#fff8e1") if age == 0 else UiPalette.get_default().paper.darkened(0.08))


func _scroll_to_end() -> void:
	var bar := _scroll.get_v_scroll_bar()
	if _scroll_tw and _scroll_tw.is_valid():
		_scroll_tw.kill()
	_scroll_tw = create_tween()
	_scroll_tw.tween_property(_scroll, "scroll_vertical", int(bar.max_value), 0.25).set_trans(Tween.TRANS_SINE)


func _on_toggle() -> void:
	_collapsed = not _collapsed
	_scroll.visible = not _collapsed
	_toggle.text = "+" if _collapsed else "–"
	Audio.play("click")


func _colorize(text: String) -> String:
	var s := text.replace("[", "(").replace("]", ")")
	for pair in _names:
		var n: String = pair[0]
		if s.find(n) >= 0:
			s = s.replace(n, "[b][color=#%s]%s[/color][/b]" % [(pair[1] as Color).lightened(0.35).to_html(false), n])
	return s


func _icon_for(text: String) -> String:
	var t := text.to_lower()
	if t.find("đấu giá") >= 0 or t.find("trả ") == 0 and t.find("xu.") >= 0:
		return "gavel"
	if t.find("kẹt xe") >= 0:
		return "jail"
	if t.find("rút") >= 0 or t.find("khí vận") >= 0 or t.find("cơ hội") >= 0:
		return "card"
	if t.find("phá sản") >= 0 or t.find("bão") >= 0 or t.find("lũ") >= 0:
		return "alert"
	if t.find("xây") >= 0 or t.find("nâng") >= 0 or t.find("danh thắng") >= 0:
		return "house"
	if t.find("mua") >= 0 or t.find("thâu tóm") >= 0:
		return "land"
	if t.find("mùa") >= 0:
		return "spring"
	if t.find("tung") >= 0 or t.find("đụng độ") >= 0:
		return "dice"
	if t.find("quỹ") >= 0:
		return "fund"
	if t.find("thuê") >= 0 or t.find("lương") >= 0 or t.find("nhận") >= 0 or t.find("nộp") >= 0 or t.find("trả") >= 0:
		return "coin"
	return "turn"
