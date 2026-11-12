extends Node3D
## Sảnh 3D: sân khấu kiểu đình làng, các nhân vật đứng thành hàng ngang trên bục.
## Người chơi chọn nhân vật bằng nút ◀ ▶; nhân vật của đối thủ đứng cạnh bên.

const PLAYER_COLORS := ["#e53935", "#1e88e5", "#43a047", "#fdd835", "#8e24aa", "#fb8c00"]
const SPACING := 1.7
const ROUND_CHOICES := [15, 20, 25, 30]

var _stage: Node3D
var _row: Node3D
var _spot: SpotLight3D
var _ui: CanvasLayer
var _name_edit: LineEdit
var _char_title: Label
var _char_desc: Label
var _bots: OptionButton
var _diff: OptionButton
var _rounds: OptionButton
var _player_char: Character3D
var _player_slot := 0
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var jump := args.has("--autotest") or args.has("--autotest-human") or args.has("--showcase") or args.has("--auctiondemo") or args.has("--typeshow") or args.has("--builddemo") or args.has("--pickerdemo") or args.has("--juicedemo")
	for a in args:
		if a.begins_with("--carddemo="):
			jump = true
	if jump:
		Global.bot_count = 5
		Global.max_rounds = 15
		Global.reroll_bots()
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
		return
	if Global.bot_characters.size() != Global.bot_count:
		Global.reroll_bots()
	Global.fix_bots()
	_build_world()
	_build_ui()
	_rebuild_row()
	Audio.play_music("music_lobby")
	for a in args:
		if a.begins_with("--menushot="):
			_shot(a.substr(11))


# ---------------------------------------------------------------- sân khấu 3D

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a0f0f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffcc99")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 20, 0)
	key.light_energy = 0.9
	key.light_color = Color("#fff1dc")
	key.shadow_enabled = Global.shadows
	add_child(key)

	_stage = Node3D.new()
	add_child(_stage)
	# Sàn gỗ và thảm đỏ
	_stage.add_child(_box(Vector3(18, 0.3, 6), "#6d4c41", Vector3(0, -0.15, 0)))
	_stage.add_child(_box(Vector3(12, 0.02, 2.2), "#b71c1c", Vector3(0, 0.01, 0.6)))
	# Tường hậu và cột đình
	_stage.add_child(_box(Vector3(18, 6, 0.3), "#7f1d1d", Vector3(0, 3, -2.6)))
	for x in [-8.2, -3.2, 3.2, 8.2]:
		_stage.add_child(_cyl(0.22, 4.2, "#c62828", Vector3(x, 2.1, -2.1)))
		_stage.add_child(_cyl(0.3, 0.25, "#3e2723", Vector3(x, 0.12, -2.1)))
	# Mái đình cong (lăng trụ)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(15, 1.2, 1.8)
	roof.mesh = pm
	roof.position = Vector3(0, 4.8, -1.9)
	roof.material_override = _mat("#4e342e")
	_stage.add_child(roof)
	_stage.add_child(_box(Vector3(15.4, 0.15, 2.0), "#ffca28", Vector3(0, 4.2, -1.9), true))
	# Hoành phi
	var plaque := _box(Vector3(5.2, 0.9, 0.12), "#3e2723", Vector3(0, 3.55, -2.0))
	_stage.add_child(plaque)
	var title := Label3D.new()
	title.text = "TỶ PHÚ ĐẤT VIỆT"
	title.font_size = 96
	title.pixel_size = 0.0075
	title.modulate = Color("#ffd54f")
	title.outline_size = 12
	title.outline_modulate = Color("#3e2723")
	title.position = Vector3(0, 3.55, -1.93)
	_stage.add_child(title)
	# Đèn lồng
	for x in [-5.2, -4.0, 4.0, 5.2]:
		var string := _box(Vector3(0.015, 0.6, 0.015), "#212121", Vector3(x, 3.85, -0.9))
		_stage.add_child(string)
		var lantern := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.5
		lantern.mesh = sm
		lantern.position = Vector3(x, 3.4, -0.9)
		lantern.material_override = _mat("#e53935", true)
		_stage.add_child(lantern)
		var glow := OmniLight3D.new()
		glow.light_color = Color("#ff7043")
		glow.light_energy = 0.8
		glow.omni_range = 3.0
		glow.position = Vector3(x, 3.2, -0.6)
		_stage.add_child(glow)
		var tw := create_tween().set_loops()
		tw.tween_property(lantern, "rotation:z", 0.08, 1.4 + x * 0.05).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lantern, "rotation:z", -0.08, 1.4 + x * 0.05).set_trans(Tween.TRANS_SINE)
	# Câu đối hai bên
	for side in [-1, 1]:
		var board := _box(Vector3(0.7, 2.6, 0.08), "#b71c1c", Vector3(side * 7.4, 2.0, -2.38))
		_stage.add_child(board)
		var verse := Label3D.new()
		verse.text = "Phú\nQuý\nVinh\nHoa" if side < 0 else "Phát\nTài\nPhát\nLộc"
		verse.font_size = 64
		verse.pixel_size = 0.006
		verse.modulate = Color("#ffd54f")
		verse.position = Vector3(side * 7.4, 2.0, -2.33)
		_stage.add_child(verse)

	_row = Node3D.new()
	add_child(_row)

	_spot = SpotLight3D.new()
	_spot.light_color = Color("#fff3e0")
	_spot.light_energy = 6.0
	_spot.spot_range = 8.0
	_spot.spot_angle = 18.0
	_spot.rotation_degrees = Vector3(-90, 0, 0)
	add_child(_spot)

	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)


## Dựng lại hàng nhân vật theo số máy và lựa chọn hiện tại.
func _rebuild_row() -> void:
	for c in _row.get_children():
		c.queue_free()
	var n := Global.bot_count + 1
	_player_slot = n / 2
	# Lùi camera theo số người để cả hàng nằm gọn trong khung hình
	var dist := 4.6 + n * 1.0
	create_tween().tween_property(_cam, "position", Vector3(0, 2.0 + n * 0.05, dist), 0.4).set_trans(Tween.TRANS_SINE)
	if _cam.position == Vector3.ZERO:
		_cam.position = Vector3(0, 2.0 + n * 0.05, dist)
	_cam.look_at_from_position(_cam.position, Vector3(0, 1.0, 0), Vector3.UP)
	var bot_i := 0
	for slot in n:
		var x := (slot - (n - 1) / 2.0) * SPACING
		var is_player := slot == _player_slot
		var pid := 0 if is_player else bot_i + 1
		var char_id: String = Global.character if is_player else Global.bot_characters[bot_i]
		var name: String = Global.player_name if is_player else Global.BOT_NAMES[bot_i]
		if not is_player:
			bot_i += 1
		var col := Color(PLAYER_COLORS[pid])
		var podium := _cyl(0.55, 0.45, "#5d4037", Vector3(x, 0.22, 0.4))
		_row.add_child(podium)
		_row.add_child(_cyl(0.58, 0.06, PLAYER_COLORS[pid], Vector3(x, 0.47, 0.4)))
		var ch := Character3D.new().setup(char_id, col)
		ch.position = Vector3(x, 0.5, 0.4)
		ch.scale = Vector3.ONE * 1.6
		_row.add_child(ch)
		var tag := Label3D.new()
		tag.text = "%s\n%s" % [name, CardsData.character(char_id)["name"]]
		tag.font_size = 40
		tag.pixel_size = 0.0036
		tag.width = SPACING * 0.95 / tag.pixel_size
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = col.lightened(0.45)
		tag.outline_size = 10
		tag.outline_modulate = Color(0, 0, 0, 0.9)
		tag.position = Vector3(x, 2.1, 0.4)
		_row.add_child(tag)
		if is_player:
			_player_char = ch
			_spot.position = Vector3(x, 5.5, 0.4)
			var you := Label3D.new()
			you.text = "▼ BẠN ▼"
			you.font_size = 44
			you.pixel_size = 0.005
			you.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			you.modulate = Color("#ffd54f")
			you.outline_size = 10
			you.position = Vector3(x, 2.55, 0.4)
			_row.add_child(you)
	_update_char_text()


# ---------------------------------------------------------------- giao diện

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 17
	root.theme = th
	_ui.add_child(root)

	# Nút cài đặt góc phải
	var settings := _button("Cài đặt", _open_settings)
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left = -130
	settings.offset_right = -12
	settings.offset_top = 12
	settings.offset_bottom = 54
	root.add_child(settings)

	# Bảng dưới cùng
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff8e1", 0.96)
	sb.set_corner_radius_all(16)
	sb.border_color = Color("#ffca28")
	sb.set_border_width_all(3)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -12
	panel.offset_bottom = -12
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	# Chọn nhân vật
	var pick := HBoxContainer.new()
	pick.alignment = BoxContainer.ALIGNMENT_CENTER
	pick.add_theme_constant_override("separation", 12)
	v.add_child(pick)
	var prev := _button("  ◀  ", func(): _cycle_character(-1))
	prev.add_theme_font_size_override("font_size", 22)
	pick.add_child(prev)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(560, 0)
	pick.add_child(mid)
	_char_title = Label.new()
	_char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_title.add_theme_font_size_override("font_size", 24)
	_char_title.add_theme_color_override("font_color", Color("#b71c1c"))
	mid.add_child(_char_title)
	_char_desc = Label.new()
	_char_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_desc.add_theme_color_override("font_color", Color("#3e2723"))
	mid.add_child(_char_desc)
	var nxt := _button("  ▶  ", func(): _cycle_character(1))
	nxt.add_theme_font_size_override("font_size", 22)
	pick.add_child(nxt)

	# Tuỳ chọn
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 10)
	v.add_child(opts)
	opts.add_child(_label("Tên:"))
	_name_edit = LineEdit.new()
	_name_edit.text = Global.player_name
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(150, 0)
	_name_edit.text_changed.connect(func(t):
		Global.player_name = t.strip_edges() if t.strip_edges() != "" else "Bạn"
		_rebuild_row())
	opts.add_child(_name_edit)
	opts.add_child(_label("Đối thủ:"))
	_bots = OptionButton.new()
	for k in [3, 4, 5]:
		_bots.add_item("%d máy (%d người)" % [k, k + 1])
	_bots.select(Global.bot_count - 3)
	_bots.item_selected.connect(func(i):
		Global.bot_count = i + 3
		Global.fix_bots()
		Audio.play("click")
		_rebuild_row())
	opts.add_child(_bots)
	opts.add_child(_button("Đổi đối thủ", func():
		Global.reroll_bots()
		_rebuild_row()))
	opts.add_child(_label("Độ khó:"))
	_diff = OptionButton.new()
	for d in ["Dễ", "Thường", "Khó"]:
		_diff.add_item(d)
	_diff.select(Global.difficulty)
	_diff.item_selected.connect(func(i): Global.difficulty = i)
	opts.add_child(_diff)
	opts.add_child(_label("Số vòng:"))
	_rounds = OptionButton.new()
	for r in ROUND_CHOICES:
		_rounds.add_item(str(r))
	_rounds.select(maxi(0, ROUND_CHOICES.find(Global.max_rounds)))
	_rounds.item_selected.connect(func(i): Global.max_rounds = ROUND_CHOICES[i])
	opts.add_child(_rounds)

	# Nút chơi
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 10)
	v.add_child(play_row)
	var start := _button("CHƠI VỚI MÁY", _on_start)
	start.custom_minimum_size = Vector2(300, 54)
	start.add_theme_font_size_override("font_size", 24)
	play_row.add_child(start)
	for t in ["Tạo phòng", "Nhập mã phòng", "Ghép trận", "Leo hạng"]:
		var b := Button.new()
		b.text = t + "\n(sắp có)"
		b.disabled = true
		b.custom_minimum_size = Vector2(118, 54)
		b.add_theme_font_size_override("font_size", 13)
		play_row.add_child(b)


func _cycle_character(dir: int) -> void:
	var ids: Array = []
	for c in CardsData.CHARACTERS:
		ids.append(c["id"])
	var i := ids.find(Global.character)
	Global.character = ids[posmod(i + dir, ids.size())]
	# Nếu trùng nhân vật của máy thì đổi máy sang nhân vật khác
	Global.fix_bots()
	Audio.play("click")
	_rebuild_row()
	if _player_char:
		_player_char.cheer.call_deferred()


func _update_char_text() -> void:
	var c := CardsData.character(Global.character)
	_char_title.text = c["name"]
	_char_desc.text = "Kỹ năng: " + String(c["desc"])


func _open_settings() -> void:
	var p := SettingsPanel.new()
	_ui.add_child(p)


func _on_start() -> void:
	Global.save_settings()
	Audio.play("turn")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _shot(path: String) -> void:
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


# ---------------------------------------------------------------- tiện ích

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func():
		Audio.play("click")
		cb.call())
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#3e2723"))
	return l


var _mats := {}


func _mat(col: String, glow: bool = false) -> StandardMaterial3D:
	var key := col + str(glow)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col)
	m.roughness = 0.7
	if glow:
		m.emission_enabled = true
		m.emission = Color(col)
		m.emission_energy_multiplier = 1.2
	_mats[key] = m
	return m


func _box(size: Vector3, col: String, pos: Vector3, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(col, glow)
	return mi


func _cyl(r: float, h: float, col: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(col)
	return mi


func _process(_delta: float) -> void:
	if _cam:
		_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
