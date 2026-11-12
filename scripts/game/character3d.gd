class_name Character3D
extends Node3D
## Nhân vật chibi low-poly dựng bằng code, mỗi nghề một bộ trang phục riêng.
## Đế tròn dưới chân mang màu người chơi để phân biệt.

const SKIN := "#f5c99b"
const HAIR := "#2b1d16"

## Dáng đi riêng từng nghề: swing = nhịp vung chân (rad/s), amp = biên độ, bob = nhún thân,
## hop = hệ số độ cao cú nhảy, sway = lắc ngang (đi lạch bạch), lean = nghiêng người khi đi.
const GAITS := {
	"xe_om": {"swing": 17.0, "amp": 0.8, "bob": 0.045, "hop": 1.0, "sway": 0.0, "lean": 0.16},
	"tieu_thuong": {"swing": 13.0, "amp": 0.55, "bob": 0.03, "hop": 0.8, "sway": 0.07, "lean": 0.08},
	"tho_ho": {"swing": 13.0, "amp": 0.7, "bob": 0.05, "hop": 0.9, "sway": 0.03, "lean": 0.1},
	"ngu_dan": {"swing": 12.0, "amp": 0.7, "bob": 0.04, "hop": 0.9, "sway": 0.08, "lean": 0.08},
	"doanh_nhan": {"swing": 15.0, "amp": 0.5, "bob": 0.025, "hop": 0.85, "sway": 0.0, "lean": 0.05},
	"hoc_sinh": {"swing": 18.0, "amp": 0.9, "bob": 0.06, "hop": 1.25, "sway": 0.02, "lean": 0.14},
	"nong_dan": {"swing": 12.0, "amp": 0.75, "bob": 0.05, "hop": 0.9, "sway": 0.04, "lean": 0.1},
	"nghe_si": {"swing": 15.0, "amp": 0.7, "bob": 0.04, "hop": 1.1, "sway": 0.1, "lean": 0.1},
}
const DEFAULT_GAIT := {"swing": 15.0, "amp": 0.75, "bob": 0.04, "hop": 1.0, "sway": 0.0, "lean": 0.12}

var character_id: String = ""
var player_color: Color = Color.WHITE
var body_root: Node3D
var head: Node3D
var legs: Array = []
var arms: Array = []
var walking := false
var gait: Dictionary = DEFAULT_GAIT
## Nghiêng người theo chuyển động (PawnMotion đặt), cộng thêm vào dáng đi.
var lean := 0.0
## Độ cao mặt ô dưới chân (để bóng luôn nằm trên mặt bàn khi đang nhảy).
var ground_y := 0.1
## Tốc độ hoạt cảnh phản ứng (theo tốc độ ván x1–x4).
var anim_speed := 1.0
var _walk_k := 0.0
var _jump_y := 0.0
var _tilt := 0.0
var _arms_up := 0.0
var _head_down := 0.0
var _slump := 0.0
var _t := 0.0
var _phase := 0.0
var _mats := {}
var _eyes: Array = []
var _blink_t := 2.0
var _look_t := 1.5
var _look_target := 0.0
var _shadow: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _active := false
var _react_tw: Tween
var _sq_tw: Tween
var _blink_tw: Tween


func setup(id: String, col: Color) -> Character3D:
	character_id = id
	player_color = col
	gait = GAITS.get(id, DEFAULT_GAIT)
	_phase = randf() * TAU
	_blink_t = randf_range(1.0, 4.0)
	_build()
	return self


func _process(delta: float) -> void:
	_t += delta
	if body_root == null:
		return
	# Hoà dần giữa đứng yên và bước đi (theo delta time)
	_walk_k = lerpf(_walk_k, 1.0 if walking else 0.0, 1.0 - exp(-10.0 * delta))
	var ph := _t * float(gait["swing"])
	var swing := sin(ph) * float(gait["amp"]) * _walk_k
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = swing * (1.0 if i == 0 else -1.0)
	for i in arms.size():
		var sx := 1.0 if i == 0 else -1.0
		var arm := arms[i] as Node3D
		arm.rotation.x = -swing * 0.8 * sx - _arms_up * 2.7
		arm.rotation.z = (-1.0 if i == 0 else 1.0) * (0.25 - _slump * 0.2 + _arms_up * 0.35)
	# Thở nhẹ khi đứng yên; nhún theo bước khi đi
	var idle := (sin(_t * 2.2 + _phase) * 0.5 + 0.5) * 0.018
	var step_bob := absf(sin(ph)) * float(gait["bob"])
	body_root.position.y = lerpf(idle, step_bob, _walk_k) + _jump_y - _slump * 0.04
	var want_x := float(gait["lean"]) * _walk_k + lean + _tilt + _slump * 0.18
	body_root.rotation.x = lerpf(body_root.rotation.x, want_x, 1.0 - exp(-12.0 * delta))
	body_root.rotation.z = sin(ph * 0.5) * float(gait["sway"]) * _walk_k
	_update_head(delta)
	_update_shadow()
	if _ring and _ring.visible:
		var k := 0.5 + 0.5 * sin(_t * 4.0)
		_ring.scale = Vector3.ONE * (1.0 + 0.1 * k)
		_ring_mat.albedo_color.a = 0.45 + 0.4 * k


func _update_head(delta: float) -> void:
	if head == null:
		return
	# Chớp mắt ngẫu nhiên
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.2, 5.0)
		if _blink_tw and _blink_tw.is_valid():
			_blink_tw.kill()
		_blink_tw = create_tween()
		for e in _eyes:
			_blink_tw.parallel().tween_property(e, "scale:y", 0.15, 0.06)
		_blink_tw.chain()
		for e in _eyes:
			_blink_tw.parallel().tween_property(e, "scale:y", 1.0, 0.08)
	# Ngó nghiêng khi đứng yên, nhìn thẳng khi đi
	if walking:
		_look_target = 0.0
		_look_t = randf_range(0.8, 2.0)
	else:
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = randf_range(1.6, 4.0)
			_look_target = randf_range(-0.55, 0.55) if randf() < 0.65 else 0.0
	head.rotation.y = lerp_angle(head.rotation.y, _look_target, 1.0 - exp(-4.0 * delta))
	var nod := sin(_t * 2.2 + _phase) * 0.02 * (1.0 - _walk_k)
	head.rotation.x = lerpf(head.rotation.x, _head_down + nod, 1.0 - exp(-8.0 * delta))


func _update_shadow() -> void:
	if _shadow == null:
		return
	var sy := maxf(scale.y, 0.001)
	var h := maxf(0.0, position.y - ground_y)
	_shadow.position.y = (ground_y - position.y) / sy + 0.012
	var k := clampf(h / 0.8, 0.0, 1.0)
	_shadow.scale = Vector3.ONE * lerpf(1.0, 0.6, k)
	_shadow_mat.albedo_color.a = lerpf(0.32, 0.12, k)


func set_walking(on: bool) -> void:
	walking = on


## Hệ số độ cao cú nhảy theo dáng đi của nghề.
func hop_scale() -> float:
	return float(gait["hop"])


## Vòng sáng màu người chơi dưới chân khi đến lượt.
func set_active(on: bool) -> void:
	if _ring == null or on == _active:
		_active = on
		return
	_active = on
	_ring.visible = on


## Dừng mọi hiệu ứng phản ứng / nhún đang chạy (trước khi bắt đầu di chuyển, tránh chồng tween).
func stop_reaction() -> void:
	if _react_tw and _react_tw.is_valid():
		_react_tw.kill()
	if _sq_tw and _sq_tw.is_valid():
		_sq_tw.kill()
	_jump_y = 0.0
	_tilt = 0.0
	_arms_up = 0.0
	_head_down = 0.0
	_slump = 0.0
	body_root.rotation.y = 0.0
	body_root.scale = Vector3.ONE


## Nhún lấy đà trước cú nhảy đầu tiên.
func anticipate(duration: float) -> void:
	_squash(Vector3(1.1, 0.84, 1.1), duration, 0.0)
	await get_tree().create_timer(duration).timeout


## Đáp xuống ô: nhún xuống rồi bật lại (strength 1 = cú đáp cuối, 0.5 = đáp nhẹ).
func land(strength: float = 1.0) -> void:
	walking = false
	lean = 0.0
	var s := clampf(strength, 0.2, 1.5)
	_squash(Vector3(1.0 + 0.16 * s, 1.0 - 0.24 * s, 1.0 + 0.16 * s), 0.06, 0.32)


func _squash(v: Vector3, t_in: float, t_out: float) -> void:
	if _sq_tw and _sq_tw.is_valid():
		_sq_tw.kill()
	_sq_tw = create_tween()
	_sq_tw.set_speed_scale(anim_speed)
	_sq_tw.tween_property(body_root, "scale", v, maxf(t_in, 0.01)).set_ease(Tween.EASE_OUT)
	if t_out > 0.0:
		_sq_tw.tween_property(body_root, "scale", Vector3.ONE, t_out).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Phản ứng: "cheer" (mừng: nhảy xoay + giơ tay), "slump" (trả tiền: xụi vai cúi đầu),
## "sigh" (vào Kẹt Xe: thở dài, người xẹp xuống), "lucky" (may: nhảy cẫng 2 lần),
## "jolt" (xui: giật mình ngả ra sau), "sad" (buồn: gục đầu).
func react(kind: String) -> void:
	if body_root == null:
		return
	stop_reaction()
	var tw := create_tween()
	_react_tw = tw
	tw.set_speed_scale(anim_speed)
	match kind:
		"cheer":
			tw.tween_property(self, "_arms_up", 1.0, 0.1)
			tw.parallel().tween_property(self, "_jump_y", 0.35, 0.15).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(body_root, "rotation:y", TAU, 0.3)
			tw.tween_property(self, "_jump_y", 0.0, 0.15).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): body_root.rotation.y = 0.0)
			tw.tween_property(self, "_arms_up", 0.0, 0.25)
		"lucky":
			tw.tween_property(self, "_arms_up", 1.0, 0.08)
			for hgt in [0.22, 0.38]:
				tw.tween_property(self, "_jump_y", hgt, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(self, "_jump_y", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(body_root, "rotation:y", TAU, 0.26)
			tw.tween_callback(func(): body_root.rotation.y = 0.0)
			tw.tween_property(self, "_arms_up", 0.0, 0.2)
		"slump":
			tw.tween_property(self, "_slump", 1.0, 0.22).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "_head_down", 0.4, 0.22)
			tw.tween_interval(0.6)
			tw.tween_property(self, "_slump", 0.0, 0.3)
			tw.parallel().tween_property(self, "_head_down", 0.0, 0.3)
		"sigh":
			tw.tween_property(body_root, "scale", Vector3(1.04, 1.06, 1.04), 0.25).set_ease(Tween.EASE_OUT)   # hít vào
			tw.tween_property(body_root, "scale", Vector3(1.06, 0.88, 1.06), 0.35).set_ease(Tween.EASE_IN_OUT)  # thở ra
			tw.parallel().tween_property(self, "_slump", 1.0, 0.35)
			tw.parallel().tween_property(self, "_head_down", 0.45, 0.35)
			tw.tween_interval(0.5)
			tw.tween_property(body_root, "scale", Vector3.ONE, 0.3)
			tw.parallel().tween_property(self, "_slump", 0.0, 0.35)
			tw.parallel().tween_property(self, "_head_down", 0.0, 0.35)
		"jolt":
			tw.tween_property(self, "_tilt", -0.35, 0.05).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "_jump_y", 0.08, 0.05)
			for k in 4:
				tw.tween_property(body_root, "rotation:y", 0.18 * (1 if k % 2 == 0 else -1), 0.045)
			tw.tween_property(body_root, "rotation:y", 0.0, 0.05)
			tw.parallel().tween_property(self, "_jump_y", 0.0, 0.1)
			tw.tween_property(self, "_tilt", 0.0, 0.25)
		_:
			tw.tween_property(self, "_tilt", 0.35, 0.2)
			tw.parallel().tween_property(self, "_head_down", 0.3, 0.2)
			tw.tween_interval(0.5)
			tw.tween_property(self, "_tilt", 0.0, 0.25)
			tw.parallel().tween_property(self, "_head_down", 0.0, 0.25)


## Nhảy mừng (khi mua đất, thắng đụng độ...)
func cheer() -> void:
	react("cheer")


## Gục đầu buồn (khi phá sản, thua đụng độ)
func sad() -> void:
	react("sad")


# ---------------------------------------------------------------- dựng hình

func _build() -> void:
	# Đế màu người chơi
	var base := _cyl(0.2, 0.22, 0.05, player_color)
	base.position.y = 0.025
	add_child(base)
	var ring := _cyl(0.23, 0.23, 0.02, player_color.lightened(0.4))
	ring.position.y = 0.01
	add_child(ring)

	body_root = Node3D.new()
	add_child(body_root)
	var outfit := _outfit()
	# Chân
	for sx in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.06, 0.27, 0)
		body_root.add_child(hip)
		var leg := _capsule(0.05, 0.22, outfit["pants"])
		leg.position = Vector3(0, -0.11, 0)
		hip.add_child(leg)
		legs.append(hip)
	# Thân
	if outfit.get("long", false):
		var tunic := _cyl(0.1, 0.16, 0.34, outfit["shirt"])
		tunic.position.y = 0.38
		body_root.add_child(tunic)
	else:
		var torso := _capsule(0.12, 0.3, outfit["shirt"])
		torso.position.y = 0.4
		body_root.add_child(torso)
	# Tay
	for sx in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(sx * 0.13, 0.51, 0)
		shoulder.rotation.z = sx * 0.25
		body_root.add_child(shoulder)
		var arm := _capsule(0.04, 0.2, outfit["shirt"])
		arm.position = Vector3(0, -0.09, 0)
		shoulder.add_child(arm)
		var hand := _sphere(0.04, SKIN)
		hand.position = Vector3(0, -0.19, 0)
		shoulder.add_child(hand)
		arms.append(shoulder)
	# Đầu
	var head := _sphere(0.15, SKIN)
	head.position.y = 0.68
	body_root.add_child(head)
	var hair := _sphere(0.155, outfit.get("hair", HAIR))
	hair.position = Vector3(0, 0.71, -0.03)
	hair.scale = Vector3(1, 0.9, 0.95)
	body_root.add_child(hair)
	for sx in [-1, 1]:
		var eye := _sphere(0.02, "#1a1a1a")
		eye.position = Vector3(sx * 0.055, 0.69, 0.135)
		body_root.add_child(eye)
		_eyes.append(eye)
	var cheek_l := _sphere(0.022, "#ff8a80")
	cheek_l.position = Vector3(-0.09, 0.65, 0.12)
	body_root.add_child(cheek_l)
	var cheek_r := _sphere(0.022, "#ff8a80")
	cheek_r.position = Vector3(0.09, 0.65, 0.12)
	body_root.add_child(cheek_r)
	_accessories()
	_make_head_pivot()
	_make_shadow_and_ring()


## Gom đầu + tóc + mắt + mũ (mọi thứ nằm quanh đầu) vào một pivot ở cổ để đầu xoay/gật được.
func _make_head_pivot() -> void:
	head = Node3D.new()
	head.position = Vector3(0, 0.58, 0)
	var moving: Array = []
	for c in body_root.get_children():
		var n := c as Node3D
		if n and not arms.has(n) and not legs.has(n) and n.position.y > 0.6 and absf(n.position.x) <= 0.145:
			moving.append(n)
	body_root.add_child(head)
	for n in moving:
		var pos: Vector3 = n.position
		body_root.remove_child(n)
		head.add_child(n)
		n.position = pos - head.position


func _make_shadow_and_ring() -> void:
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.albedo_color = Color(0, 0, 0, 0.32)
	var sm := CylinderMesh.new()
	sm.top_radius = 0.3
	sm.bottom_radius = 0.3
	sm.height = 0.002
	sm.radial_segments = 20
	sm.rings = 1
	_shadow = MeshInstance3D.new()
	_shadow.mesh = sm
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(player_color.lightened(0.45), 0.8)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.33
	tm.rings = 24
	tm.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = tm
	_ring.material_override = _ring_mat
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func _outfit() -> Dictionary:
	match character_id:
		"xe_om":
			return {"shirt": "#2e7d32", "pants": "#37474f"}
		"tieu_thuong":
			return {"shirt": "#f48fb1", "pants": "#212121", "long": true}
		"tho_ho":
			return {"shirt": "#ff9800", "pants": "#455a64"}
		"ngu_dan":
			return {"shirt": "#1e88e5", "pants": "#5d4037"}
		"doanh_nhan":
			return {"shirt": "#37474f", "pants": "#263238"}
		"hoc_sinh":
			return {"shirt": "#fafafa", "pants": "#1a237e"}
		"nong_dan":
			return {"shirt": "#8d6e63", "pants": "#4e342e"}
		"nghe_si":
			return {"shirt": "#c62828", "pants": "#212121", "long": true}
	return {"shirt": "#9e9e9e", "pants": "#424242"}


func _accessories() -> void:
	match character_id:
		"xe_om":
			# Mũ bảo hiểm nửa đầu
			var helmet := _sphere(0.17, "#ef6c00")
			helmet.position.y = 0.74
			helmet.scale = Vector3(1, 0.7, 1)
			body_root.add_child(helmet)
			var visor := _box(Vector3(0.2, 0.02, 0.08), "#212121")
			visor.position = Vector3(0, 0.74, 0.17)
			body_root.add_child(visor)
		"tieu_thuong":
			body_root.add_child(_non_la(0.84))
			# Quang gánh
			var pole := _box(Vector3(0.7, 0.025, 0.025), "#a1887f")
			pole.position = Vector3(0, 0.56, -0.05)
			body_root.add_child(pole)
			for sx in [-1, 1]:
				var rope := _box(Vector3(0.01, 0.2, 0.01), "#795548")
				rope.position = Vector3(sx * 0.33, 0.46, -0.05)
				body_root.add_child(rope)
				var basket := _cyl(0.09, 0.07, 0.1, "#d7a86e")
				basket.position = Vector3(sx * 0.33, 0.33, -0.05)
				body_root.add_child(basket)
				var fruit := _sphere(0.05, "#e53935" if sx < 0 else "#fdd835")
				fruit.position = Vector3(sx * 0.33, 0.39, -0.05)
				body_root.add_child(fruit)
		"tho_ho":
			var hat := _sphere(0.16, "#fdd835")
			hat.position.y = 0.76
			hat.scale = Vector3(1, 0.65, 1)
			body_root.add_child(hat)
			var brim := _cyl(0.2, 0.2, 0.02, "#fbc02d")
			brim.position.y = 0.74
			body_root.add_child(brim)
			var stripe := _box(Vector3(0.25, 0.03, 0.01), "#e0e0e0")
			stripe.position = Vector3(0, 0.45, 0.12)
			body_root.add_child(stripe)
			var trowel := _box(Vector3(0.08, 0.01, 0.12), "#9e9e9e")
			trowel.position = Vector3(0.2, 0.3, 0.08)
			body_root.add_child(trowel)
		"ngu_dan":
			var bucket := _cyl(0.12, 0.14, 0.1, "#fff59d")
			bucket.position.y = 0.82
			body_root.add_child(bucket)
			var brim := _cyl(0.22, 0.22, 0.015, "#fff176")
			brim.position.y = 0.78
			body_root.add_child(brim)
			var rod := _box(Vector3(0.015, 0.75, 0.015), "#6d4c41")
			rod.position = Vector3(0.2, 0.55, 0.05)
			rod.rotation.z = -0.35
			body_root.add_child(rod)
			var fish := _sphere(0.05, "#90caf9")
			fish.position = Vector3(0.36, 0.84, 0.05)
			fish.scale = Vector3(1.6, 0.8, 0.6)
			body_root.add_child(fish)
		"doanh_nhan":
			var tie := _box(Vector3(0.04, 0.16, 0.02), "#d32f2f")
			tie.position = Vector3(0, 0.45, 0.12)
			body_root.add_child(tie)
			var collar := _box(Vector3(0.12, 0.04, 0.02), "#fafafa")
			collar.position = Vector3(0, 0.54, 0.11)
			body_root.add_child(collar)
			var bag := _box(Vector3(0.16, 0.12, 0.05), "#4e342e")
			bag.position = Vector3(0.22, 0.25, 0.02)
			body_root.add_child(bag)
			var bun := _sphere(0.06, HAIR)
			bun.position = Vector3(0, 0.8, -0.1)
			body_root.add_child(bun)
		"hoc_sinh":
			var scarf := _box(Vector3(0.16, 0.06, 0.02), "#e53935")
			scarf.position = Vector3(0, 0.53, 0.11)
			body_root.add_child(scarf)
			var tail := _box(Vector3(0.05, 0.12, 0.02), "#e53935")
			tail.position = Vector3(0.02, 0.45, 0.12)
			tail.rotation.z = 0.3
			body_root.add_child(tail)
			var pack := _box(Vector3(0.2, 0.22, 0.1), "#1e88e5")
			pack.position = Vector3(0, 0.42, -0.15)
			body_root.add_child(pack)
			for sx in [-1, 1]:
				var tuft := _sphere(0.05, HAIR)
				tuft.position = Vector3(sx * 0.14, 0.72, -0.02)
				body_root.add_child(tuft)
		"nong_dan":
			body_root.add_child(_non_la(0.84))
			var handle := _box(Vector3(0.02, 0.6, 0.02), "#a1887f")
			handle.position = Vector3(-0.22, 0.42, 0.04)
			handle.rotation.z = 0.25
			body_root.add_child(handle)
			var blade := _box(Vector3(0.12, 0.03, 0.08), "#9e9e9e")
			blade.position = Vector3(-0.15, 0.71, 0.04)
			body_root.add_child(blade)
		"nghe_si":
			var khan := _cyl(0.16, 0.16, 0.09, "#fdd835")
			khan.position.y = 0.8
			body_root.add_child(khan)
			var band := _cyl(0.165, 0.165, 0.02, "#c62828")
			band.position.y = 0.79
			body_root.add_child(band)
			var mic := _box(Vector3(0.025, 0.14, 0.025), "#212121")
			mic.position = Vector3(0.19, 0.42, 0.1)
			body_root.add_child(mic)
			var mic_head := _sphere(0.04, "#bdbdbd")
			mic_head.position = Vector3(0.19, 0.5, 0.1)
			body_root.add_child(mic_head)


func _non_la(y: float) -> Node3D:
	var n := Node3D.new()
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.27
	cm.height = 0.15
	cm.radial_segments = 16
	cone.mesh = cm
	cone.material_override = _mat("#e8d39a")
	n.position.y = y
	n.add_child(cone)
	return n


func _mat(col: String) -> StandardMaterial3D:
	if _mats.has(col):
		return _mats[col]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col)
	m.roughness = 0.7
	_mats[col] = m
	return m


func _mesh(mesh: Mesh, col) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if col is Color:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.6
		mi.material_override = m
	else:
		mi.material_override = _mat(col)
	return mi


func _sphere(r: float, col) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 16
	sm.rings = 8
	return _mesh(sm, col)


func _capsule(r: float, h: float, col) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 4
	return _mesh(cm, col)


func _cyl(top: float, bottom: float, h: float, col) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 16
	return _mesh(cm, col)


func _box(size: Vector3, col) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(bm, col)
