class_name Character3D
extends Node3D
## Nhân vật chibi low-poly dựng bằng code, mỗi nghề một bộ trang phục riêng.
## Đế tròn dưới chân mang màu người chơi để phân biệt.

const SKIN := "#f5c99b"
const HAIR := "#2b1d16"

var character_id: String = ""
var player_color: Color = Color.WHITE
var body_root: Node3D
var _t := 0.0
var _phase := 0.0
var _mats := {}


func setup(id: String, col: Color) -> Character3D:
	character_id = id
	player_color = col
	_phase = randf() * TAU
	_build()
	return self


func _process(delta: float) -> void:
	_t += delta
	if body_root:
		body_root.position.y = absf(sin(_t * 2.6 + _phase)) * 0.025


## Nhảy mừng (khi mua đất, thắng đụng độ...)
func cheer() -> void:
	var tw := create_tween()
	tw.tween_property(body_root, "position:y", 0.35, 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body_root, "rotation:y", TAU, 0.3)
	tw.tween_property(body_root, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): body_root.rotation.y = 0.0)


## Gục đầu buồn (khi phá sản, trả tiền lớn)
func sad() -> void:
	var tw := create_tween()
	tw.tween_property(body_root, "rotation:x", 0.35, 0.2)
	tw.tween_interval(0.5)
	tw.tween_property(body_root, "rotation:x", 0.0, 0.25)


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
		var leg := _capsule(0.05, 0.22, outfit["pants"])
		leg.position = Vector3(sx * 0.06, 0.16, 0)
		body_root.add_child(leg)
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
		var arm := _capsule(0.04, 0.2, outfit["shirt"])
		arm.position = Vector3(sx * 0.15, 0.42, 0)
		arm.rotation.z = sx * 0.25
		body_root.add_child(arm)
		var hand := _sphere(0.04, SKIN)
		hand.position = Vector3(sx * 0.18, 0.32, 0)
		body_root.add_child(hand)
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
	var cheek_l := _sphere(0.022, "#ff8a80")
	cheek_l.position = Vector3(-0.09, 0.65, 0.12)
	body_root.add_child(cheek_l)
	var cheek_r := _sphere(0.022, "#ff8a80")
	cheek_r.position = Vector3(0.09, 0.65, 0.12)
	body_root.add_child(cheek_r)
	_accessories()


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
	cone.position.y = y
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
