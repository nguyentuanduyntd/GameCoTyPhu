class_name ChuBa
extends Node3D
## Chú Ba — người dẫn trò miền Tây: áo bà ba, khăn rằn, ria mép.
## Biểu cảm theo kết quả lá bài: happy (vui mừng), surprised (bất ngờ), sad (buồn bã), confused (hoang mang).

const SKIN := "#f2c18e"
const DARK := "#2b1d16"

var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var eye_l: MeshInstance3D
var eye_r: MeshInstance3D
var brow_l: MeshInstance3D
var brow_r: MeshInstance3D
var mouth: Node3D
var fx: Node3D
var mood := "idle"
var _t := 0.0
var _tw: Tween
var _mats := {}


func _ready() -> void:
	_build()
	set_mood("idle")


func _process(delta: float) -> void:
	_t += delta
	if mood == "idle":
		body.position.y = sin(_t * 2.2) * 0.015
		head.rotation.z = sin(_t * 1.3) * 0.05
	elif mood == "sad":
		body.rotation.z = sin(_t * 1.2) * 0.04


func set_mood(m: String) -> void:
	mood = m
	if _tw and _tw.is_valid():
		_tw.kill()
	_reset_pose()
	for c in fx.get_children():
		c.queue_free()
	for c in mouth.get_children():
		c.queue_free()
	match m:
		"happy":
			_face(0.35, Vector3(0, 0.02, 0), 0.0, 0.0, 0.03)
			_mouth_open(Color("#b71c1c"), false)
			_tw = create_tween()
			for k in 2:
				_tw.tween_property(body, "position:y", 0.28, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				_tw.parallel().tween_property(arm_l, "rotation:z", 2.6, 0.16)
				_tw.parallel().tween_property(arm_r, "rotation:z", -2.6, 0.16)
				_tw.tween_property(body, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			_tw.tween_property(arm_l, "rotation:z", 2.2, 0.2)
			_tw.parallel().tween_property(arm_r, "rotation:z", -2.2, 0.2)
			for k in 5:
				var s := _sphere(0.03, "#ffd54f", true)
				s.position = Vector3(randf_range(-0.35, 0.35), randf_range(0.7, 1.1), 0.1)
				fx.add_child(s)
				var tw := s.create_tween().set_loops(4)
				tw.tween_property(s, "scale", Vector3.ONE * 1.8, 0.25)
				tw.tween_property(s, "scale", Vector3.ONE * 0.6, 0.25)
		"surprised":
			_face(1.6, Vector3(0, 0.0, 0), 0.06, 0.0, 0.06)
			var o := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.022
			tm.outer_radius = 0.038
			o.mesh = tm
			o.rotation.x = PI / 2
			o.material_override = _mat("#5d1010")
			mouth.add_child(o)
			var bang := _label("!", Color("#ff1744"), 120)
			bang.position = Vector3(0.22, 1.05, 0.05)
			fx.add_child(bang)
			bang.scale = Vector3.ZERO
			_tw = create_tween()
			_tw.tween_property(bang, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tw.parallel().tween_property(body, "position:z", -0.12, 0.15)
			_tw.parallel().tween_property(body, "rotation:x", -0.25, 0.15)
			_tw.parallel().tween_property(arm_l, "rotation:z", 2.0, 0.15)
			_tw.parallel().tween_property(arm_r, "rotation:z", -2.0, 0.15)
			_tw.tween_interval(0.35)
			_tw.tween_property(body, "rotation:x", 0.0, 0.3)
			_tw.parallel().tween_property(arm_l, "rotation:z", 0.9, 0.3)
			_tw.parallel().tween_property(arm_r, "rotation:z", -0.9, 0.3)
		"sad":
			_face(0.45, Vector3(0, -0.012, 0), -0.35, 0.0, 0.0)
			_mouth_open(Color("#5d1010"), true)
			var tear := _sphere(0.022, "#4fc3f7", true)
			tear.position = Vector3(-0.07, 0.72, 0.16)
			fx.add_child(tear)
			var tt := tear.create_tween().set_loops(3)
			tt.tween_property(tear, "position:y", 0.55, 0.7)
			tt.tween_callback(func(): tear.position.y = 0.72)
			_tw = create_tween()
			_tw.tween_property(head, "rotation:x", 0.38, 0.4)
			_tw.parallel().tween_property(arm_l, "rotation:z", 0.05, 0.4)
			_tw.parallel().tween_property(arm_r, "rotation:z", -0.05, 0.4)
			_tw.parallel().tween_property(body, "position:y", -0.04, 0.4)
		"confused":
			_face(1.0, Vector3.ZERO, 0.0, 0.3, 0.0)
			eye_l.scale = Vector3.ONE * 1.4
			eye_r.scale = Vector3.ONE * 0.7
			for k in 3:
				var seg := _box(Vector3(0.035, 0.012, 0.01), "#5d1010")
				seg.position = Vector3(-0.035 + k * 0.035, 0, 0)
				seg.rotation.z = 0.5 if k % 2 == 0 else -0.5
				mouth.add_child(seg)
			var q := _label("?", Color("#ffeb3b"), 110)
			q.position = Vector3(0.25, 1.05, 0.05)
			fx.add_child(q)
			var q2 := _label("?", Color("#ffffff"), 70)
			q2.position = Vector3(-0.22, 1.0, 0.05)
			fx.add_child(q2)
			var sweat := _sphere(0.03, "#81d4fa", true)
			sweat.scale = Vector3(0.8, 1.3, 0.8)
			sweat.position = Vector3(0.17, 0.85, 0.08)
			fx.add_child(sweat)
			_tw = create_tween()
			for k in 3:
				_tw.tween_property(head, "rotation:z", 0.28, 0.14)
				_tw.tween_property(head, "rotation:z", -0.28, 0.14)
			_tw.tween_property(head, "rotation:z", 0.15, 0.14)
			_tw.parallel().tween_property(arm_r, "rotation:z", -2.7, 0.2)
			var qt := q.create_tween().set_loops(4)
			qt.tween_property(q, "position:y", 1.12, 0.3)
			qt.tween_property(q, "position:y", 1.02, 0.3)
		_:
			_face(1.0, Vector3.ZERO, 0.0, 0.0, 0.0)
			for k in 5:
				var dot := _sphere(0.011, "#5d1010")
				var a := lerpf(-0.9, 0.9, k / 4.0)
				dot.position = Vector3(sin(a) * 0.045, -cos(a) * 0.02 + 0.01, 0)
				mouth.add_child(dot)


# ---------------------------------------------------------------- dựng hình

func _build() -> void:
	body = Node3D.new()
	add_child(body)
	for sx in [-1, 1]:
		var leg := _capsule(0.055, 0.26, "#3e2723")
		leg.position = Vector3(sx * 0.065, 0.15, 0)
		body.add_child(leg)
		var foot := _box(Vector3(0.08, 0.04, 0.12), "#5d4037")
		foot.position = Vector3(sx * 0.065, 0.02, 0.02)
		body.add_child(foot)
	# Áo bà ba nâu
	var shirt := _cyl(0.14, 0.17, 0.34, "#8d5a3b")
	shirt.position.y = 0.43
	body.add_child(shirt)
	for k in 3:
		var btn := _sphere(0.012, "#efebe9")
		btn.position = Vector3(0, 0.36 + k * 0.07, 0.155)
		body.add_child(btn)
	# Khăn rằn caro đen trắng
	for k in 12:
		var a := TAU * k / 12.0
		var sq := _box(Vector3(0.05, 0.05, 0.03), "#212121" if k % 2 == 0 else "#fafafa")
		sq.position = Vector3(sin(a) * 0.12, 0.62, cos(a) * 0.12)
		sq.rotation.y = a
		body.add_child(sq)
	var tail := _box(Vector3(0.05, 0.14, 0.02), "#212121")
	tail.position = Vector3(0.08, 0.53, 0.13)
	tail.rotation.z = 0.3
	body.add_child(tail)
	# Tay (xoay quanh vai)
	arm_l = _arm(-1)
	arm_r = _arm(1)
	# Đầu
	head = Node3D.new()
	head.position.y = 0.66
	body.add_child(head)
	var skull := _sphere(0.18, SKIN)
	skull.position.y = 0.12
	head.add_child(skull)
	var hair := _sphere(0.182, DARK)
	hair.position = Vector3(0, 0.17, -0.03)
	hair.scale = Vector3(1, 0.65, 0.95)
	head.add_child(hair)
	for sx in [-1, 1]:
		var ear := _sphere(0.04, SKIN)
		ear.position = Vector3(sx * 0.175, 0.11, 0)
		head.add_child(ear)
	eye_l = _sphere(0.026, "#1a1a1a")
	eye_r = _sphere(0.026, "#1a1a1a")
	eye_l.position = Vector3(-0.065, 0.14, 0.16)
	eye_r.position = Vector3(0.065, 0.14, 0.16)
	head.add_child(eye_l)
	head.add_child(eye_r)
	brow_l = _box(Vector3(0.06, 0.014, 0.01), DARK)
	brow_r = _box(Vector3(0.06, 0.014, 0.01), DARK)
	head.add_child(brow_l)
	head.add_child(brow_r)
	# Ria mép
	for sx in [-1, 1]:
		var stache := _capsule(0.014, 0.07, DARK)
		stache.rotation.z = sx * 1.25
		stache.position = Vector3(sx * 0.032, 0.06, 0.168)
		head.add_child(stache)
	for sx in [-1, 1]:
		var cheek := _sphere(0.025, "#ff8a80")
		cheek.position = Vector3(sx * 0.11, 0.08, 0.14)
		head.add_child(cheek)
	mouth = Node3D.new()
	mouth.position = Vector3(0, 0.025, 0.172)
	head.add_child(mouth)
	fx = Node3D.new()
	add_child(fx)


func _arm(side: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.16, 0.57, 0)
	body.add_child(pivot)
	var arm := _capsule(0.045, 0.24, "#8d5a3b")
	arm.position.y = -0.11
	pivot.add_child(arm)
	var hand := _sphere(0.045, SKIN)
	hand.position.y = -0.24
	pivot.add_child(hand)
	return pivot


func _reset_pose() -> void:
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	arm_l.rotation.z = 0.25
	arm_r.rotation.z = -0.25
	eye_l.scale = Vector3.ONE
	eye_r.scale = Vector3.ONE


## eye_scale_y: <1 nheo/buồn, >1 mở to; brow_tilt: + lông mày nhướng trong (buồn), brow_mismatch: lệch (hoang mang)
func _face(eye_scale: float, eye_offset: Vector3, brow_tilt: float, brow_mismatch: float, brow_lift: float) -> void:
	if eye_scale < 1.0:
		eye_l.scale = Vector3(1.2, eye_scale, 1.0)
		eye_r.scale = Vector3(1.2, eye_scale, 1.0)
	else:
		eye_l.scale = Vector3.ONE * eye_scale
		eye_r.scale = Vector3.ONE * eye_scale
	eye_l.position = Vector3(-0.065, 0.14, 0.16) + eye_offset
	eye_r.position = Vector3(0.065, 0.14, 0.16) + eye_offset
	brow_l.position = Vector3(-0.065, 0.195 + brow_lift + brow_mismatch * 0.05, 0.165)
	brow_r.position = Vector3(0.065, 0.195 + brow_lift - brow_mismatch * 0.03, 0.165)
	brow_l.rotation.z = -brow_tilt + brow_mismatch
	brow_r.rotation.z = brow_tilt + brow_mismatch * 0.5


func _mouth_open(col: Color, flipped: bool) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.05
	sm.is_hemisphere = true
	m.mesh = sm
	m.scale = Vector3(1.0, 0.9, 0.4)
	m.rotation.x = 0.0 if flipped else PI
	m.position.y = -0.015 if flipped else 0.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	mouth.add_child(m)
	if not flipped:
		var tongue := _sphere(0.02, "#ff8a80")
		tongue.position = Vector3(0, -0.03, 0.005)
		tongue.scale = Vector3(1.2, 0.6, 0.5)
		mouth.add_child(tongue)


# ---------------------------------------------------------------- khối cơ bản

func _label(text: String, col: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 16
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l


func _mat(col: String, glow: bool = false) -> StandardMaterial3D:
	var key := col + str(glow)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col)
	m.roughness = 0.65
	if glow:
		m.emission_enabled = true
		m.emission = Color(col)
		m.emission_energy_multiplier = 0.8
	_mats[key] = m
	return m


func _mi(mesh: Mesh, col: String, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, glow)
	return mi


func _sphere(r: float, col: String, glow: bool = false) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 16
	sm.rings = 8
	return _mi(sm, col, glow)


func _capsule(r: float, h: float, col: String) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0)
	return _mi(cm, col)


func _cyl(top: float, bottom: float, h: float, col: String) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	return _mi(cm, col)


func _box(size: Vector3, col: String) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mi(bm, col)
