class_name DiceTray
extends CanvasLayer
## Mâm xúc xắc ở giữa màn hình (SubViewport 3D riêng, nền trong suốt).
## Xúc xắc được ném vào mâm, xoay quanh cả 3 trục, rơi và nảy theo trọng lực (tính theo delta time),
## va thành mâm, va nhau; cuối cùng xoay khớp đúng mặt kết quả mà engine đã quyết định rồi hiện "3 + 4 = 7".
## Giá trị luôn lấy từ sự kiện "dice" của engine — hoạt ảnh chỉ diễn lại, không tự tạo kết quả.

signal settled

const DIE := 0.55
const FELT_Y := 0.135
const TRAY_R := 1.45
const GRAVITY := -16.0
const BOUNCE := 0.42
const SETTLE_AFTER := 0.95
const SETTLE_TIME := 0.32

var _dim: ColorRect
var _vp: SubViewport
var _cam: Camera3D
var _tray: Node3D
var _dice: Array = []
var _state: Array = []
var _result: Label
var _sub: Label
var _ring: RingFx
var _rolling := false
var _sim_speed := 1.0
var _cam_base := Vector3.ZERO


func _ready() -> void:
	layer = 25
	_build()
	visible = false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff3e0")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62, 28, 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 15.0
	_vp.add_child(key)
	var spark := OmniLight3D.new()
	spark.position = Vector3(-1.2, 2.2, 1.5)
	spark.light_color = Color("#ffe0b2")
	spark.light_energy = 1.0
	spark.omni_range = 5.0
	_vp.add_child(spark)

	_cam = Camera3D.new()
	_cam.fov = 38
	_cam_base = Vector3(0, 6.2, 5.6)
	_cam.position = _cam_base
	_vp.add_child(_cam)
	_cam.look_at(Vector3(0, 0.1, 0.0), Vector3.UP)

	# Mâm gỗ lót nỉ đỏ, viền vàng
	_tray = Node3D.new()
	_vp.add_child(_tray)
	_tray.add_child(_cyl(1.95, 2.05, 0.26, Color("#6d4c41"), Vector3(0, 0.0, 0)))
	_tray.add_child(_cyl(1.75, 1.75, 0.02, Color("#9c1414"), Vector3(0, FELT_Y - 0.01, 0)))
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.78
	tm.outer_radius = 1.98
	tm.rings = 48
	rim.mesh = tm
	rim.position.y = 0.14
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#ffca28")
	gold.metallic = 0.7
	gold.roughness = 0.3
	rim.material_override = gold
	_tray.add_child(rim)
	for k in 8:
		var a := TAU * k / 8.0
		var stud := _cyl(0.06, 0.06, 0.05, Color("#ffd54f"), Vector3(cos(a) * 1.88, 0.2, sin(a) * 1.88))
		_tray.add_child(stud)

	for i in 2:
		var d := DiceView.make_die(DIE)
		_vp.add_child(d)
		for c in d.get_children():
			if c is MeshInstance3D:
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_dice.append(d)

	# --- Kết quả
	_ring = RingFx.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_result = Label.new()
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.offset_left = -360
	_result.offset_right = 360
	_result.offset_top = -230
	_result.offset_bottom = -140
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 76)
	_result.add_theme_color_override("font_color", Color("#ffd54f"))
	_result.add_theme_constant_override("outline_size", 18)
	_result.add_theme_color_override("font_outline_color", Color("#4e1a00"))
	_result.add_theme_constant_override("shadow_offset_y", 6)
	_result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	add_child(_result)
	_sub = Label.new()
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.offset_left = -300
	_sub.offset_right = 300
	_sub.offset_top = -140
	_sub.offset_bottom = -95
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 32)
	_sub.add_theme_color_override("font_color", Color.WHITE)
	_sub.add_theme_constant_override("outline_size", 10)
	_sub.add_theme_color_override("font_outline_color", Color("#b71c1c"))
	add_child(_sub)
	_result.resized.connect(func(): _result.pivot_offset = _result.size / 2.0)
	_sub.resized.connect(func(): _sub.pivot_offset = _sub.size / 2.0)


func _process(delta: float) -> void:
	if not _rolling:
		return
	var dt := delta * _sim_speed
	var floor_y := FELT_Y + DIE / 2.0
	var all_done := true
	for i in _state.size():
		var s: Dictionary = _state[i]
		var die: Node3D = _dice[i]
		s["t"] += dt
		if s["settle"] < 0.0 and s["t"] >= SETTLE_AFTER:
			s["settle"] = 0.0
			s["q0"] = s["q"]
			s["p0"] = s["p"]
		if s["settle"] >= 0.0:
			# Khớp dần về đúng mặt kết quả, trượt nhẹ rồi dừng hẳn
			s["settle"] = minf(1.0, s["settle"] + dt / SETTLE_TIME)
			var e: float = 1.0 - pow(1.0 - s["settle"], 3.0)
			s["q"] = (s["q0"] as Quaternion).slerp(s["qt"], e)
			var p0: Vector3 = s["p0"]
			var rest: Vector3 = s["rest"]
			s["p"] = Vector3(lerpf(p0.x, rest.x, e), lerpf(p0.y, floor_y, e) + sin(e * PI) * 0.08, lerpf(p0.z, rest.z, e))
			if s["settle"] < 1.0:
				all_done = false
		else:
			all_done = false
			var v: Vector3 = s["v"]
			var p: Vector3 = s["p"]
			v.y += GRAVITY * dt
			p += v * dt
			# Chạm mặt nỉ: nảy lên, mất dần năng lượng
			if p.y < floor_y and v.y < 0.0:
				p.y = floor_y
				var hit := -v.y
				v.y = hit * BOUNCE
				v.x *= 0.72
				v.z *= 0.72
				s["w"] = (s["w"] as Vector3) * 0.62
				if hit > 1.2:
					Audio.play("step", 0.25, linear_to_db(clampf(hit / 7.0, 0.15, 1.0)) - 2.0)
					_cam_kick(clampf(hit * 0.006, 0.0, 0.04))
			# Va thành mâm
			var flat := Vector2(p.x, p.z)
			var n := flat.normalized()
			var vf := Vector2(v.x, v.z)
			# chỉ bật lại khi đang lao ra ngoài (lúc mới ném từ mép vào thì cho bay qua)
			if flat.length() > TRAY_R and vf.dot(n) > 0.0:
				flat = n * TRAY_R
				vf = vf - 2.0 * vf.dot(n) * n
				v.x = vf.x * 0.6
				v.z = vf.y * 0.6
				p.x = flat.x
				p.z = flat.y
				Audio.play("step", 0.3, -8.0)
			# Xoay theo vận tốc góc
			var w: Vector3 = s["w"]
			if w.length() > 0.001:
				s["q"] = (Quaternion(w.normalized(), w.length() * dt) * (s["q"] as Quaternion)).normalized()
			s["v"] = v
			s["p"] = p
		die.position = s["p"]
		die.quaternion = s["q"]
	# Hai viên không chồng lên nhau
	if _state.size() == 2:
		var a: Vector3 = _state[0]["p"]
		var b: Vector3 = _state[1]["p"]
		var d := Vector2(b.x - a.x, b.z - a.z)
		if d.length() < DIE * 1.1 and _state[0]["settle"] < 0.0:
			var push := d.normalized() * (DIE * 1.1 - d.length()) * 0.5 if d.length() > 0.001 else Vector2(0.3, 0)
			_state[0]["p"] = a - Vector3(push.x, 0, push.y)
			_state[1]["p"] = b + Vector3(push.x, 0, push.y)
	if all_done:
		_rolling = false
		settled.emit()


## Tung xúc xắc với kết quả values (lấy từ engine). caption: dòng phụ tuỳ chọn (vd. đụng độ).
func roll(values: Array, speed: float = 1.0, caption: String = "") -> void:
	_sim_speed = clampf(speed, 0.5, 4.0)
	visible = true
	_result.text = ""
	_sub.text = ""
	_result.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var n := values.size()
	_dice[1].visible = n > 1
	_state.clear()
	for i in n:
		var side := -1.0 if i == 0 else 1.0
		if n == 1:
			side = 0.0
		var start := Vector3(side * 1.1 + randf_range(-0.2, 0.2), 1.3 + i * 0.25, 1.9)
		var vel := Vector3(-side * randf_range(1.0, 1.8) + randf_range(-0.4, 0.4), randf_range(3.2, 4.2), randf_range(-3.6, -2.8))
		var w := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(14.0, 22.0)
		var rest := Vector3(0.0 if n == 1 else (-0.42 if i == 0 else 0.42), 0, randf_range(-0.15, 0.15))
		var q0 := Quaternion(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
		_state.append({
			"p": start, "v": vel, "w": w, "q": q0, "t": 0.0, "settle": -1.0, "rest": rest,
			"qt": Quaternion(DiceView.face_up_basis(int(values[i]), randf_range(-0.35, 0.35))),
		})
		_dice[i].position = start
		_dice[i].quaternion = q0
		_dice[i].scale = Vector3.ONE
	_tray.scale = Vector3.ONE * 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.3, 0.2 / _sim_speed)
	tw.tween_property(_tray, "scale", Vector3.ONE, 0.3 / _sim_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("dice", 0.08)
	_rolling = true
	await settled
	# Kết quả bật lên kiểu pop-up, kèm vòng sáng lan toả
	for i in n:
		var bump := create_tween()
		bump.tween_property(_dice[i], "scale", Vector3.ONE * 1.15, 0.08)
		bump.tween_property(_dice[i], "scale", Vector3.ONE, 0.12)
	if n == 1:
		_result.text = str(values[0])
	else:
		_result.text = "%d + %d = %d" % [values[0], values[1], int(values[0]) + int(values[1])]
	if caption != "":
		_sub.text = caption
	elif n == 2 and values[0] == values[1]:
		_sub.text = "ĐÔI! Được tung thêm lượt"
	_result.scale = Vector2.ONE * 0.2
	_sub.scale = Vector2.ONE * 0.5
	var pop := create_tween().set_parallel(true)
	pop.tween_property(_result, "modulate:a", 1.0, 0.12)
	pop.tween_property(_result, "scale", Vector2.ONE * 1.18, 0.22 / _sim_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_result, "scale", Vector2.ONE, 0.15 / _sim_speed).set_delay(0.22 / _sim_speed)
	pop.tween_property(_sub, "modulate:a", 1.0, 0.2).set_delay(0.12 / _sim_speed)
	pop.tween_property(_sub, "scale", Vector2.ONE, 0.25 / _sim_speed).set_delay(0.12 / _sim_speed).set_trans(Tween.TRANS_BACK)
	_ring.burst(_ring.size / 2.0 + Vector2(0, (_result.offset_top + _result.offset_bottom) / 2.0), 1.0 / _sim_speed)
	Audio.play("coin", 0.05, -6.0)
	await get_tree().create_timer(0.85 / _sim_speed).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(_dim, "color:a", 0.0, 0.25 / _sim_speed)
	out.tween_property(_result, "modulate:a", 0.0, 0.2 / _sim_speed)
	out.tween_property(_sub, "modulate:a", 0.0, 0.2 / _sim_speed)
	out.tween_property(_tray, "scale", Vector3.ONE * 0.01, 0.25 / _sim_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for i in n:
		out.tween_property(_dice[i], "scale", Vector3.ONE * 0.01, 0.25 / _sim_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await out.finished
	visible = false


## Huỷ hoạt ảnh (khi rời màn chơi giữa chừng).
func cancel() -> void:
	_rolling = false
	visible = false


func _cam_kick(amount: float) -> void:
	var tw := create_tween()
	tw.tween_property(_cam, "position", _cam_base + Vector3(randf_range(-amount, amount), -amount, 0), 0.03)
	tw.tween_property(_cam, "position", _cam_base, 0.08)


func _cyl(top: float, bottom: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 48
	mi.mesh = cm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	mi.material_override = m
	return mi


## Vòng sáng lan toả phía sau con số kết quả.
class RingFx extends Control:
	var _center := Vector2.ZERO
	var _t := 1.0
	var _dur := 1.0

	func burst(center: Vector2, duration: float) -> void:
		_center = center
		_t = 0.0
		_dur = maxf(duration, 0.2)

	func _process(delta: float) -> void:
		if _t < 1.0:
			_t = minf(1.0, _t + delta / _dur)
			queue_redraw()

	func _draw() -> void:
		if _t >= 1.0:
			return
		var e := 1.0 - pow(1.0 - _t, 3.0)
		var a := 1.0 - _t
		draw_circle(_center, 60.0 + e * 220.0, Color(1.0, 0.85, 0.3, 0.18 * a))
		draw_arc(_center, 60.0 + e * 260.0, 0, TAU, 72, Color(1.0, 0.9, 0.4, 0.9 * a), 10.0 * a + 2.0, true)
		draw_arc(_center, 40.0 + e * 180.0, 0, TAU, 72, Color(1.0, 1.0, 1.0, 0.6 * a), 5.0 * a + 1.0, true)
