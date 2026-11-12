class_name CardOverlay
extends CanvasLayer
## Giao diện rút bài Khí Vận / Cơ Hội.
## Luồng: mở bộ bài (phóng to, lơ lửng, nghiêng 3D) → "RÚT BÀI" → xáo trộn, chia bài → 1 lá bay ra, phóng lớn, lật mặt
## → hoạt ảnh theo nội dung + biểu cảm Chú Ba → "XÁC NHẬN" (lúc này game mới áp dụng hiệu ứng) → đóng mượt.
## Dựng trong SubViewport 3D riêng (nền trong suốt, ánh sáng riêng) để luôn nằm giữa màn hình, đè lên HUD.

signal draw_pressed
signal confirm_pressed(index: int)

const CARD_W := 1.0
const CARD_H := 1.45
const STACK := 10
const DIST := 3.4

var deck := "khi_van"
var speed := 1.0
var is_open := false

var _dim: ColorRect
var _flash: ColorRect
var _container: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _deck_root: Node3D
var _rays: MeshInstance3D
var _sparkles: CPUParticles3D
var _chu_ba: ChuBa
var _carriers: Array = []
var _revealed: Array = []
var _title: Label
var _subtitle: Label
var _draw_btn: Button
var _confirm_btn: Button
var _pick_row: HBoxContainer
var _t := 0.0
var _steady := 0.0
var _pressed := false
var _mats := {}


func _ready() -> void:
	layer = 20
	_build()
	visible = false


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	# Bộ bài lơ lửng, nghiêng theo phối cảnh 3D; khi đã lật bài thì dần đứng yên cho dễ đọc
	var k := 1.0 - _steady
	_stage.position.y = 0.06 + sin(_t * 1.7) * 0.05 * k + sin(_t * 1.1) * 0.012
	_stage.rotation.x = (-0.22 + sin(_t * 0.9) * 0.06) * k
	_stage.rotation.y = sin(_t * 0.7) * 0.28 * k
	_stage.rotation.z = sin(_t * 1.3) * 0.03 * k
	if _rays.visible:
		_rays.rotation.z += delta * 0.6
	for carrier in _revealed:
		if is_instance_valid(carrier):
			var card: Node3D = carrier.get_child(1)
			var shadow: Node3D = carrier.get_child(0)
			shadow.scale.x = maxf(0.05, absf(cos(card.rotation.y)))


# ---------------------------------------------------------------- dựng khung

func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.02, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_container = SubViewportContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_container.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff3e0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.1
	_vp.add_child(key)
	var warm := OmniLight3D.new()
	warm.position = Vector3(0.9, 1.0, -2.2)
	warm.light_color = Color("#ffd180")
	warm.light_energy = 0.9
	warm.omni_range = 3.5
	_vp.add_child(warm)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, -0.4, -2.6)
	rim.light_color = Color("#80d8ff")
	rim.light_energy = 0.6
	rim.omni_range = 3.0
	_vp.add_child(rim)

	_cam = Camera3D.new()
	_cam.fov = 40
	_vp.add_child(_cam)

	_stage = Node3D.new()
	_stage.position = Vector3(0, 0.06, -DIST)
	_vp.add_child(_stage)

	_rays = MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(3.4, 3.4)
	_rays.mesh = rq
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = CardArt.rays()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rays.material_override = rmat
	_rays.position = Vector3(0, 0.06, -DIST - 0.4)
	_rays.visible = false
	_vp.add_child(_rays)

	_sparkles = _particles(["#ffd54f", "#fff59d", "#ffffff"], 0.022, 45, 1.6)
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_sparkles.emission_sphere_radius = 1.0
	_sparkles.gravity = Vector3(0, 0.25, 0)
	_sparkles.initial_velocity_min = 0.05
	_sparkles.initial_velocity_max = 0.2
	_sparkles.position = Vector3(0, 0.06, -DIST)
	_vp.add_child(_sparkles)

	_chu_ba = ChuBa.new()
	_vp.add_child(_chu_ba)

	# --- Lớp chữ và nút
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.offset_left = -420
	_title.offset_right = 420
	_title.offset_top = 18
	_title.offset_bottom = 70
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_subtitle.offset_left = -420
	_subtitle.offset_right = 420
	_subtitle.offset_top = 66
	_subtitle.offset_bottom = 96
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Color("#fff8e1"))
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_subtitle)

	_draw_btn = _fancy_button("RÚT BÀI")
	_draw_btn.pressed.connect(func():
		if _pressed:
			return
		_pressed = true
		_hide_button(_draw_btn)
		draw_pressed.emit())
	add_child(_draw_btn)
	_confirm_btn = _fancy_button("XÁC NHẬN")
	_confirm_btn.pressed.connect(func():
		if _pressed:
			return
		_pressed = true
		_hide_button(_confirm_btn)
		confirm_pressed.emit(0))
	add_child(_confirm_btn)
	_pick_row = HBoxContainer.new()
	_pick_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pick_row.offset_left = -330
	_pick_row.offset_right = 330
	_pick_row.offset_top = -110
	_pick_row.offset_bottom = -26
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pick_row.add_theme_constant_override("separation", 40)
	add_child(_pick_row)
	for i in 2:
		var b := _fancy_button("CHỌN LÁ NÀY", false)
		b.custom_minimum_size = Vector2(250, 66)
		b.pressed.connect(func():
			if _pressed:
				return
			_pressed = true
			_pick_row.visible = false
			confirm_pressed.emit(i))
		_pick_row.add_child(b)
	_draw_btn.visible = false
	_confirm_btn.visible = false
	_pick_row.visible = false

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


# ---------------------------------------------------------------- mở bộ bài

## Mở giao diện, hiện bộ bài. Gọi xong thì chờ người chơi bấm RÚT BÀI (hoặc máy tự rút).
func open(p_deck: String, player_name: String, p_speed: float) -> void:
	deck = p_deck
	speed = maxf(p_speed, 0.5)
	is_open = true
	visible = true
	_pressed = false
	_steady = 0.0
	_t = 0.0
	_clear_stage()
	var th := CardArt.theme(deck)
	_title.text = "%s — %s" % [player_name, th["title"]]
	_title.add_theme_color_override("font_color", Color(th["gold"]))
	_subtitle.text = "Thử vận may, đón lộc trời!" if deck == "khi_van" else "Cơ hội làm giàu đang chờ bạn!"
	_style_buttons()
	_layout()
	_sparkles.color = Color(th["gold"])
	_sparkles.emitting = true
	_rays.visible = false
	_chu_ba.set_mood("idle")

	_deck_root = Node3D.new()
	_stage.add_child(_deck_root)
	for i in STACK:
		var carrier := _make_card()
		carrier.position = Vector3(randf_range(-0.012, 0.012), i * 0.004, i * 0.012)
		carrier.rotation.z = randf_range(-0.04, 0.04)
		_deck_root.add_child(carrier)
		_carriers.append(carrier)

	_stage.scale = Vector3.ONE * 0.25
	_dim.color.a = 0.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_chu_ba.scale = Vector3.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.62, 0.3 / speed)
	tw.tween_property(_stage, "scale", Vector3.ONE * _deck_scale(), 0.5 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.3 / speed)
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.3 / speed)
	tw.tween_property(_chu_ba, "scale", Vector3.ONE * _chu_scale(), 0.4 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15 / speed)
	Audio.play("card", 0.1)
	await tw.finished


func show_draw_button() -> void:
	_pressed = false
	_show_button(_draw_btn)


func show_confirm(count: int) -> void:
	_pressed = false
	if count > 1:
		_pick_row.visible = true
		_pick_row.modulate.a = 0.0
		create_tween().tween_property(_pick_row, "modulate:a", 1.0, 0.25)
	else:
		_show_button(_confirm_btn)


# ---------------------------------------------------------------- rút bài

## Xáo bài, chia bài, cho 1 (hoặc 2) lá bay ra, phóng lớn và lật mặt.
func play_draw(card_ids: Array) -> void:
	var sp := speed
	_subtitle.text = "Đang xáo bài..."
	# 1) Tách đôi bộ bài
	var tw := create_tween().set_parallel(true)
	for i in _carriers.size():
		var c: Node3D = _carriers[i]
		var left := i % 2 == 0
		tw.tween_property(c, "position", Vector3(-0.5 if left else 0.5, 0.05 + i * 0.004, i * 0.012), 0.2 / sp).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "rotation:z", 0.16 if left else -0.16, 0.2 / sp)
	await tw.finished
	# 2) Xen kẽ hai nửa vào giữa như chia bài thật
	var order: Array = []
	for i in _carriers.size():
		order.append(_carriers[i])
	order.shuffle()
	tw = create_tween().set_parallel(true)
	for j in order.size():
		var c: Node3D = order[j]
		tw.tween_property(c, "position", Vector3(randf_range(-0.015, 0.015), j * 0.004, j * 0.012), 0.12 / sp).set_delay(j * 0.035 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation:z", randf_range(-0.05, 0.05), 0.12 / sp).set_delay(j * 0.035 / sp)
	Audio.play("dice", 0.1, -6.0)
	await tw.finished
	# 3) Xáo nhanh: lá bất kỳ vọt lên rồi chui về đỉnh bộ bài
	for n in 9:
		var c: Node3D = order.pop_at(randi() % order.size())
		order.append(c)
		var lift := Vector3(randf_range(-0.55, 0.55), randf_range(0.25, 0.5), (order.size() + 1) * 0.012)
		var t2 := create_tween()
		t2.tween_property(c, "position", lift, 0.06 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(c, "rotation:z", randf_range(-0.5, 0.5), 0.06 / sp)
		# đẩy z để lá bay luôn nằm trên cùng
		for j in order.size():
			var other: Node3D = order[j]
			if other != c:
				other.position.z = j * 0.012
		t2.tween_property(c, "position", Vector3(0, (order.size() - 1) * 0.004, (order.size() - 1) * 0.012), 0.06 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.parallel().tween_property(c, "rotation:z", randf_range(-0.05, 0.05), 0.06 / sp)
		if n % 3 == 0:
			Audio.play("card", 0.2, -5.0)
		await t2.finished
	# 4) Chọn lá: bay ra khỏi bộ bài, phóng lớn ở giữa
	_subtitle.text = ""
	var n_cards := card_ids.size()
	var scale_rev := _reveal_scale(n_cards)
	tw = create_tween().set_parallel(true)
	# sân khấu về tỉ lệ 1 để kích thước lá bài lật ra tính theo đơn vị thật
	var stage_k: float = _stage.scale.x
	_deck_root.scale = Vector3.ONE * stage_k
	_stage.scale = Vector3.ONE
	_deck_root.position *= stage_k
	for k in n_cards:
		var c: Node3D = order.pop_back()
		_revealed.append(c)
		var x := 0.0 if n_cards == 1 else (-0.62 if k == 0 else 0.62) * scale_rev
		# rời bộ bài sang sân khấu để không nghiêng theo bộ bài
		var gp: Vector3 = c.global_position
		c.reparent(_stage)
		c.global_position = gp
		tw.tween_property(c, "position", Vector3(x, 0.0, 0.3), 0.45 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(k * 0.12 / sp)
		tw.tween_property(c, "scale", Vector3.ONE * scale_rev, 0.45 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(k * 0.12 / sp)
		tw.tween_property(c, "rotation", Vector3.ZERO, 0.45 / sp).set_delay(k * 0.12 / sp)
	# phần còn lại của bộ bài lùi ra sau và mờ dần
	tw.tween_property(_deck_root, "position", Vector3(0, -0.9, -0.8), 0.5 / sp).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_deck_root, "scale", Vector3.ONE * stage_k * 0.5, 0.5 / sp)
	tw.tween_property(self, "_steady", 1.0, 0.5 / sp)
	Audio.play("card", 0.05)
	await tw.finished
	_deck_root.visible = false
	# 5) Lật mặt từ từ
	for k in n_cards:
		_fill_front(_revealed[k], int(card_ids[k]))
	_rays.visible = true
	_rays.scale = Vector3.ZERO
	var rmat: StandardMaterial3D = _rays.material_override
	rmat.albedo_color = Color(CardArt.theme(deck)["gold"])
	tw = create_tween().set_parallel(true)
	for k in n_cards:
		var card: Node3D = _revealed[k].get_child(1)
		tw.tween_property(card, "rotation:y", PI, 0.7 / sp).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(k * 0.15 / sp)
		var carrier: Node3D = _revealed[k]
		var base: Vector3 = carrier.scale
		tw.tween_property(carrier, "scale", base * 1.08, 0.35 / sp).set_delay(k * 0.15 / sp)
		tw.tween_property(carrier, "scale", base, 0.35 / sp).set_delay((0.35 + k * 0.15) / sp)
	tw.tween_property(_rays, "scale", Vector3.ONE * (1.0 if n_cards == 1 else 1.4), 0.6 / sp).set_delay(0.3 / sp)
	tw.tween_callback(_flash_screen).set_delay(0.35 / sp)
	Audio.play("turn")
	await tw.finished
	# 6) Hoạt ảnh theo nội dung + Chú Ba biểu cảm
	if n_cards == 1:
		var c := CardsData.card(deck, int(card_ids[0]))
		_chu_ba.set_mood(CardsData.mood(c))
		await _play_effect(c, _revealed[0])
		_subtitle.text = "Bấm XÁC NHẬN để nhận kết quả"
	else:
		_chu_ba.set_mood("surprised")
		_subtitle.text = "Bé Na được chọn 1 trong 2 lá!"


# ---------------------------------------------------------------- hiệu ứng theo nội dung

func _play_effect(c: Dictionary, carrier: Node3D) -> void:
	var sp := speed
	var cat := CardsData.category(c)
	var amount := CardsData.amount_hint(c)
	var center: Vector3 = carrier.position + Vector3(0, 0, 0.15)
	match cat:
		"gain":
			Audio.play("coin")
			var coins := _coin_burst(center, true)
			_stage.add_child(coins)
			coins.emitting = true
			if amount != 0:
				_big_text("+%s xu" % BoardData.money(amount), Color("#ffd54f"), center + Vector3(0, 0.55, 0.3))
			await get_tree().create_timer(0.9 / sp).timeout
		"loss":
			Audio.play("pay")
			_flash_screen(Color(0.9, 0.1, 0.1, 0.35))
			var drop := _coin_burst(center + Vector3(0, 0.5, 0), false)
			_stage.add_child(drop)
			drop.emitting = true
			if amount != 0:
				_big_text("−%s xu" % BoardData.money(absi(amount)), Color("#ff5252"), center + Vector3(0, 0.55, 0.3))
			await _shake(carrier, 0.07)
			await get_tree().create_timer(0.5 / sp).timeout
		"move":
			await _path_effect(carrier)
		"luck":
			Audio.play("firework", 0.1, -4.0)
			var conf := _confetti(center + Vector3(0, 0.9, 0))
			_stage.add_child(conf)
			conf.emitting = true
			var rtw := create_tween()
			rtw.tween_property(_rays, "scale", Vector3.ONE * 1.35, 0.3 / sp)
			rtw.tween_property(_rays, "scale", Vector3.ONE, 0.5 / sp)
			await get_tree().create_timer(1.0 / sp).timeout
		"bad":
			Audio.play("thunder", 0.1, -6.0)
			var cloud := _storm_cloud(center + Vector3(0, 0.62, 0.25))
			_stage.add_child(cloud)
			_flash_screen(Color(1, 1, 0.8, 0.5))
			await _shake(carrier, 0.05)
			await get_tree().create_timer(0.6 / sp).timeout
		_:
			Audio.play("buy", 0.05, -3.0)
			var glow := create_tween().set_loops(2)
			glow.tween_property(carrier, "scale", carrier.scale * 1.05, 0.25 / sp)
			glow.tween_property(carrier, "scale", carrier.scale, 0.25 / sp)
			await get_tree().create_timer(0.8 / sp).timeout


func _path_effect(carrier: Node3D) -> void:
	var sp := speed
	var root := Node3D.new()
	root.position = carrier.position + Vector3(0, 0.22 * carrier.scale.y, 0.3)
	_stage.add_child(root)
	var steps := 6
	var arrows: Array = []
	for k in steps:
		var a := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.12, 0.1, 0.03)
		a.mesh = pm
		a.rotation.z = -PI / 2
		a.position = Vector3(-0.55 + k * 0.22, 0, 0)
		a.material_override = _mat(Color(CardArt.theme(deck)["gold"]), true)
		a.scale = Vector3.ZERO
		root.add_child(a)
		arrows.append(a)
	var token := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.08
	cm.height = 0.16
	body.mesh = cm
	body.material_override = _mat(Color("#e53935"))
	token.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	head.mesh = sm
	head.position.y = 0.12
	head.material_override = _mat(Color("#ffcc99"))
	token.add_child(head)
	token.position = Vector3(-0.66, 0.06, 0.02)
	root.add_child(token)
	for k in steps:
		var a: MeshInstance3D = arrows[k]
		var tw := create_tween()
		tw.tween_property(a, "scale", Vector3.ONE, 0.08 / sp).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(token, "position", Vector3(a.position.x, 0.2, 0.02), 0.06 / sp)
		tw.tween_property(token, "position", Vector3(a.position.x, 0.06, 0.02), 0.06 / sp)
		Audio.play("step", 0.15, -6.0)
		await tw.finished
	var out := create_tween()
	out.tween_interval(0.3 / sp)
	out.tween_property(root, "scale", Vector3.ZERO, 0.25 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await out.finished
	root.queue_free()


func _coin_burst(at: Vector3, upward: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.055
	cm.height = 0.012
	cm.radial_segments = 14
	cm.material = _mat(Color("#ffc107"), true) if upward else _mat(Color("#8d6e63"))
	p.mesh = cm
	p.amount = 36 if upward else 22
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.85
	p.position = at
	p.direction = Vector3(0, 1, 0.3) if upward else Vector3(0, -1, 0.2)
	p.spread = 70.0 if upward else 25.0
	p.initial_velocity_min = 1.6 if upward else 0.4
	p.initial_velocity_max = 2.6 if upward else 0.9
	p.gravity = Vector3(0, -3.5, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.particle_flag_rotate_y = false
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3
	return p


func _confetti(at: Vector3) -> CPUParticles3D:
	var p := _particles(["#ff5252", "#ffd740", "#69f0ae", "#40c4ff", "#e040fb", "#ffffff"], 0.05, 90, 2.0)
	p.one_shot = true
	p.explosiveness = 0.9
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3(0, 1, 0.2)
	p.spread = 100.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -1.6, 0)
	p.damping_min = 0.5
	p.damping_max = 1.0
	p.angular_velocity_min = -500
	p.angular_velocity_max = 500
	return p


func _storm_cloud(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	for o in [Vector3(-0.22, 0, 0), Vector3(0, 0.08, 0), Vector3(0.22, 0, 0), Vector3(0.05, -0.04, 0.05)]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.3
		s.mesh = sm
		s.position = o
		s.material_override = _mat(Color("#546e7a"))
		n.add_child(s)
	var bolt := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.1, 0.32, 0.02)
	bolt.mesh = pm
	bolt.rotation.z = PI + 0.3
	bolt.position = Vector3(0.02, -0.28, 0.1)
	bolt.material_override = _mat(Color("#ffeb3b"), true)
	n.add_child(bolt)
	var tw := bolt.create_tween().set_loops(4)
	tw.tween_property(bolt, "visible", false, 0.12)
	tw.tween_property(bolt, "visible", true, 0.08)
	n.scale = Vector3.ZERO
	create_tween().tween_property(n, "scale", Vector3.ONE * 0.7, 0.25).set_trans(Tween.TRANS_BACK)
	return n


func _big_text(text: String, col: Color, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 22
	l.outline_modulate = Color(0.1, 0.05, 0.0, 0.95)
	l.no_depth_test = true
	l.render_priority = 10
	l.position = at
	l.scale = Vector3.ZERO
	_stage.add_child(l)
	l.font_size = 80
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.2, 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.15 / speed)
	tw.tween_property(l, "position:y", at.y + 0.45, 1.0 / speed).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5 / speed).set_delay(0.6 / speed)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.5 / speed).set_delay(0.6 / speed)
	tw.tween_callback(l.queue_free)


func _shake(n: Node3D, amp: float) -> void:
	var base := n.position
	var tw := create_tween()
	for k in 6:
		tw.tween_property(n, "position", base + Vector3(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5, 0), 0.04)
	tw.tween_property(n, "position", base, 0.05)
	await tw.finished


func _flash_screen(col: Color = Color(1, 1, 1, 0.55)) -> void:
	_flash.color = col
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


# ---------------------------------------------------------------- đóng

## Đóng giao diện mượt mà. index: lá được chọn (khi có 2 lá).
func close(index: int = 0) -> void:
	_hide_button(_confirm_btn)
	_pick_row.visible = false
	var sp := speed
	var tw := create_tween().set_parallel(true)
	for k in _revealed.size():
		var c: Node3D = _revealed[k]
		if k == index:
			tw.tween_property(c, "position", c.position + Vector3(0, 0.15, 0.25), 0.18 / sp).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", c.scale * 1.08, 0.18 / sp)
			tw.tween_property(c, "position", Vector3(0, 1.6, -0.5), 0.32 / sp).set_delay(0.18 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_property(c, "scale", Vector3.ONE * 0.1, 0.32 / sp).set_delay(0.18 / sp)
			tw.tween_property(c, "rotation:z", 0.6, 0.32 / sp).set_delay(0.18 / sp)
		else:
			tw.tween_property(c, "scale", Vector3.ZERO, 0.25 / sp)
	tw.tween_property(_rays, "scale", Vector3.ZERO, 0.3 / sp)
	tw.tween_property(_chu_ba, "scale", Vector3.ZERO, 0.3 / sp).set_delay(0.15 / sp)
	tw.tween_property(_dim, "color:a", 0.0, 0.3 / sp).set_delay(0.2 / sp)
	tw.tween_property(_title, "modulate:a", 0.0, 0.25 / sp)
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.25 / sp)
	Audio.play("card", 0.1, -3.0)
	await tw.finished
	_sparkles.emitting = false
	_clear_stage()
	is_open = false
	visible = false


# ---------------------------------------------------------------- lá bài

func _make_card() -> Node3D:
	var carrier := Node3D.new()
	var shadow := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(CARD_W * 1.25, CARD_H * 1.2)
	shadow.mesh = sq
	var smat := StandardMaterial3D.new()
	smat.albedo_texture = CardArt.shadow()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = smat
	shadow.position = Vector3(0.07, -0.09, -0.06)
	carrier.add_child(shadow)

	var card := Node3D.new()
	carrier.add_child(card)
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CARD_W, CARD_H)
	back.mesh = q
	back.material_override = _card_mat(CardArt.back(deck))
	back.position.z = 0.006
	card.add_child(back)
	var back_lbl := Label3D.new()
	back_lbl.text = CardArt.theme(deck)["title"]
	back_lbl.font_size = 44
	back_lbl.pixel_size = 0.0026
	back_lbl.modulate = Color(CardArt.theme(deck)["gold"])
	back_lbl.outline_size = 10
	back_lbl.outline_modulate = Color(CardArt.theme(deck)["dark"])
	back_lbl.double_sided = false
	back_lbl.position = Vector3(0, -CARD_H * 0.38, 0.008)
	card.add_child(back_lbl)
	var edge := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CARD_W * 0.92, CARD_H * 0.94, 0.011)
	edge.mesh = bm
	edge.material_override = _mat(Color(CardArt.theme(deck)["gold"]))
	card.add_child(edge)
	var front_pivot := Node3D.new()
	front_pivot.rotation.y = PI
	front_pivot.position.z = -0.006
	card.add_child(front_pivot)
	var front := MeshInstance3D.new()
	front.mesh = q
	front.material_override = _card_mat(CardArt.front(deck))
	front_pivot.add_child(front)
	return carrier


## Điền nội dung mặt trước: tiêu đề bộ, biểu tượng, tên sự kiện, mô tả, dòng hiệu ứng.
func _fill_front(carrier: Node3D, idx: int) -> void:
	var c := CardsData.card(deck, idx)
	var th := CardArt.theme(deck)
	var front_pivot: Node3D = carrier.get_child(1).get_child(carrier.get_child(1).get_child_count() - 1)
	var top := CARD_H / 2.0
	front_pivot.add_child(_card_label(th["title"], 46, 0.0026, Color.WHITE, Vector3(0, top - 0.125, 0.002), 0.9, Color(th["dark"]), 8))
	var icon := MeshInstance3D.new()
	var iq := QuadMesh.new()
	iq.size = Vector2(0.38, 0.38)
	icon.mesh = iq
	var imat := StandardMaterial3D.new()
	imat.albedo_texture = CardArt.icon(CardsData.icon_name(c))
	imat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	icon.material_override = imat
	icon.position = Vector3(0, top - 0.476, 0.002)
	front_pivot.add_child(icon)
	var it := icon.create_tween().set_loops()
	it.tween_property(icon, "scale", Vector3.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
	it.tween_property(icon, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	var long_name := String(c["name"]).length() > 16
	var name_lbl := _card_label(c["name"], 33 if long_name else 40, 0.0026, Color(th["dark"]), Vector3(0, -0.035, 0.002), 0.88)
	front_pivot.add_child(name_lbl)
	var desc_lbl := _card_label(c["text"], 30, 0.0021, Color("#4e342e"), Vector3(0, -0.185, 0.002), 0.86)
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	front_pivot.add_child(desc_lbl)
	front_pivot.add_child(_card_label(CardsData.summary(c), 40, 0.0023, Color("#fff59d"), Vector3(0, -top + 0.165, 0.002), 0.88, Color(0, 0, 0, 0.7), 8))


func _card_label(text: String, size: int, px: float, col: Color, pos: Vector3, width: float, outline: Color = Color(0, 0, 0, 0), osize: int = 0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = osize
	l.outline_modulate = outline
	l.width = width / px
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.double_sided = false
	l.position = pos
	return l


func _card_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _clear_stage() -> void:
	for c in _stage.get_children():
		c.queue_free()
	_carriers.clear()
	_revealed.clear()
	_deck_root = null
	_stage.scale = Vector3.ONE


# ---------------------------------------------------------------- bố cục co giãn

func _aspect() -> float:
	var s := _vp.size
	return float(s.x) / maxf(1.0, float(s.y))


func _half_width() -> float:
	return DIST * tan(deg_to_rad(20.0)) * _aspect()


func _deck_scale() -> float:
	return clampf(_half_width() * 0.55, 0.45, 0.8)


func _reveal_scale(n: int) -> float:
	var need := (CARD_W * 1.15) * n + (0.12 if n > 1 else 0.0)
	return clampf((_half_width() * 2.0 * 0.78) / need, 0.45, 0.9)


func _chu_scale() -> float:
	return 1.0 if _aspect() >= 1.3 else 0.65


func _layout() -> void:
	var hw := _half_width()
	if _aspect() >= 1.3:
		_chu_ba.position = Vector3(-hw * 0.64, -1.0, -DIST + 0.3)
		_chu_ba.rotation.y = 0.45
	else:
		_chu_ba.position = Vector3(-hw * 0.62, -1.1, -DIST + 0.6)
		_chu_ba.rotation.y = 0.3


# ---------------------------------------------------------------- nút bấm nổi bật

func _fancy_button(text: String, anchored: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 76)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color("#fffde7"))
	b.add_theme_color_override("font_pressed_color", Color("#fff59d"))
	b.focus_mode = Control.FOCUS_NONE
	if anchored:
		b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		b.offset_left = -150
		b.offset_right = 150
		b.offset_top = -110
		b.offset_bottom = -30
		b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE * 1.07, 0.12).set_trans(Tween.TRANS_BACK))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.button_down.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE * 0.94, 0.06))
	b.button_up.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.1))
	return b


func _style_buttons() -> void:
	var th := CardArt.theme(deck)
	var buttons: Array = [_draw_btn, _confirm_btn]
	buttons.append_array(_pick_row.get_children())
	for b in buttons:
		_apply_style(b, Color(th["main"]), Color(th["gold"]))


func _apply_style(b: Button, base: Color, gold: Color) -> void:
	var states := {"normal": base, "hover": base.lightened(0.18), "pressed": base.darkened(0.2), "disabled": base.darkened(0.4)}
	for st in states.keys():
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[st]
		sb.set_corner_radius_all(38)
		sb.border_color = gold if st != "hover" else Color("#fff59d")
		sb.set_border_width_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 2 if st == "pressed" else 10
		sb.shadow_offset = Vector2(0, 1 if st == "pressed" else 6)
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		b.add_theme_stylebox_override(st, sb)


func _show_button(b: Button) -> void:
	b.visible = true
	b.disabled = false
	b.scale = Vector2.ONE * 0.6
	b.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate:a", 1.0, 0.2)
	# nhịp sáng nhẹ để gây chú ý
	var pulse := b.create_tween().set_loops()
	pulse.tween_property(b, "self_modulate", Color(1.15, 1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(b, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func _hide_button(b: Button) -> void:
	b.disabled = true
	var tw := create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): b.visible = false)


## Dùng cho kiểm thử tự động: bấm nút đang hiện.
func autopress() -> void:
	if _draw_btn.visible and not _draw_btn.disabled:
		_draw_btn.pressed.emit()
	elif _confirm_btn.visible and not _confirm_btn.disabled:
		_confirm_btn.pressed.emit()
	elif _pick_row.visible:
		(_pick_row.get_child(0) as Button).pressed.emit()


# ---------------------------------------------------------------- tiện ích

func _particles(colors: Array, size: float, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size * 1.4)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = mat
	p.mesh = qm
	p.amount = amount
	p.lifetime = lifetime
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0])
	grad.colors = PackedColorArray([Color(colors[0])])
	for i in range(1, colors.size()):
		grad.add_point(float(i) / colors.size(), Color(colors[i]))
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = grad
	p.emitting = false
	return p


func _mat(col: Color, glow: bool = false) -> StandardMaterial3D:
	var key := col.to_html() + str(glow)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.4
	m.metallic = 0.3 if glow else 0.0
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.6
	_mats[key] = m
	return m
