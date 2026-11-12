extends Control
## Màn hình chính (bản tạm cho giai đoạn chơi với máy). Sảnh 3D sẽ làm ở giai đoạn M3.

var _name_edit: LineEdit
var _char_desc: Label
var _char_buttons: Array = []
var _bots: OptionButton
var _diff: OptionButton
var _rounds: OptionButton
const ROUND_CHOICES := [15, 20, 25, 30]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest") or args.has("--autotest-human") or args.has("--showcase"):
		Global.bot_count = 5
		Global.max_rounds = 15
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
		return
	_build()
	for a in args:
		if a.begins_with("--menushot="):
			_menu_shot(a.substr(11))


func _build() -> void:
	var th := Theme.new()
	th.default_font_size = 18
	theme = th

	var bg := ColorRect.new()
	bg.color = Color("#7f1d1d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color("#b71c1c")
	stripe.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripe.offset_top = 150
	stripe.offset_bottom = -150
	add_child(stripe)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(760, 0)
	center.add_child(v)

	var title := Label.new()
	title.text = "TỶ PHÚ ĐẤT VIỆT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color("#3e2723"))
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Hành trình xuyên Việt — 34 tỉnh thành"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("#fff8e1"))
	v.add_child(sub)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff8e1")
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	v.add_child(panel)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	panel.add_child(form)

	var name_row := HBoxContainer.new()
	form.add_child(name_row)
	name_row.add_child(_label("Tên của bạn:"))
	_name_edit = LineEdit.new()
	_name_edit.text = Global.player_name
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)

	form.add_child(_label("Chọn nhân vật:"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	form.add_child(grid)
	var group := ButtonGroup.new()
	for c in CardsData.CHARACTERS:
		var b := Button.new()
		b.text = c["name"]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(170, 44)
		b.add_theme_font_size_override("font_size", 15)
		b.button_pressed = c["id"] == Global.character
		var cid: String = c["id"]
		b.pressed.connect(func(): _select_character(cid))
		grid.add_child(b)
		_char_buttons.append(b)
	_char_desc = _label("")
	_char_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_desc.add_theme_color_override("font_color", Color("#b71c1c"))
	form.add_child(_char_desc)
	_select_character(Global.character)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 14)
	form.add_child(opts)
	opts.add_child(_label("Số máy:"))
	_bots = OptionButton.new()
	for n in [3, 4, 5]:
		_bots.add_item("%d máy (%d người)" % [n, n + 1])
	_bots.select(Global.bot_count - 3)
	opts.add_child(_bots)
	opts.add_child(_label("Độ khó:"))
	_diff = OptionButton.new()
	for d in ["Dễ", "Thường", "Khó"]:
		_diff.add_item(d)
	_diff.select(Global.difficulty)
	opts.add_child(_diff)
	opts.add_child(_label("Số vòng:"))
	_rounds = OptionButton.new()
	for r in ROUND_CHOICES:
		_rounds.add_item(str(r))
	_rounds.select(maxi(0, ROUND_CHOICES.find(Global.max_rounds)))
	opts.add_child(_rounds)

	var start := Button.new()
	start.text = "CHƠI VỚI MÁY"
	start.custom_minimum_size = Vector2(0, 56)
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(_on_start)
	form.add_child(start)

	var online := HBoxContainer.new()
	online.alignment = BoxContainer.ALIGNMENT_CENTER
	online.add_theme_constant_override("separation", 10)
	form.add_child(online)
	for t in ["Tạo phòng", "Nhập mã phòng", "Ghép trận", "Leo hạng"]:
		var b := Button.new()
		b.text = t + " (sắp có)"
		b.disabled = true
		b.add_theme_font_size_override("font_size", 14)
		online.add_child(b)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#3e2723"))
	return l


func _select_character(id: String) -> void:
	Global.character = id
	var c := CardsData.character(id)
	_char_desc.text = "%s — %s" % [c["name"], c["desc"]]


func _on_start() -> void:
	var n := _name_edit.text.strip_edges()
	Global.player_name = n if n != "" else "Bạn"
	Global.bot_count = _bots.selected + 3
	Global.difficulty = _diff.selected
	Global.max_rounds = ROUND_CHOICES[_rounds.selected]
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _menu_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
