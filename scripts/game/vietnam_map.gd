class_name VietnamMap
extends Node3D
## Bản đồ Việt Nam cách điệu ở giữa bàn cờ (đường viền giản lược tự vẽ từ toạ độ kinh/vĩ độ).
## Mỗi tỉnh có 1 chấm; khi có chủ sẽ cắm cờ màu người chơi, nhà càng cao cờ càng cao.
## Có quần đảo Hoàng Sa, Trường Sa và đảo Phú Quốc.

const SCALE := 0.82          # đơn vị bàn cờ trên 1 độ
const LON0 := 106.4          # kinh độ ở tâm bàn cờ
const LAT0 := 15.9           # vĩ độ ở tâm bàn cờ
const LAND_COLORS := ["#8bc34a", "#689f38", "#c0ca33", "#90a4ae"]

## Đường viền đất liền (kinh độ, vĩ độ), giản lược.
const OUTLINE := [
	Vector2(102.15, 22.40), Vector2(102.60, 22.75), Vector2(103.05, 22.55), Vector2(103.50, 22.75),
	Vector2(103.95, 22.50), Vector2(104.40, 22.80), Vector2(104.90, 23.15), Vector2(105.35, 23.35),
	Vector2(105.90, 22.95), Vector2(106.50, 22.90), Vector2(106.75, 22.75), Vector2(106.65, 22.30),
	Vector2(107.00, 21.95), Vector2(107.40, 21.65), Vector2(108.00, 21.55), Vector2(107.40, 21.10),
	Vector2(106.80, 20.70), Vector2(106.55, 20.30), Vector2(106.00, 19.95), Vector2(105.85, 19.40),
	Vector2(105.70, 18.90), Vector2(106.15, 18.30), Vector2(106.50, 17.80), Vector2(106.90, 17.20),
	Vector2(107.30, 16.80), Vector2(107.90, 16.35), Vector2(108.25, 16.10), Vector2(108.70, 15.40),
	Vector2(108.90, 14.80), Vector2(109.20, 14.00), Vector2(109.30, 13.30), Vector2(109.45, 12.80),
	Vector2(109.20, 12.20), Vector2(109.20, 11.60), Vector2(108.85, 11.15), Vector2(108.30, 10.90),
	Vector2(107.60, 10.50), Vector2(107.10, 10.40), Vector2(106.75, 10.20), Vector2(106.60, 9.90),
	Vector2(106.20, 9.60), Vector2(105.90, 9.25), Vector2(105.40, 8.80), Vector2(104.85, 8.60),
	Vector2(104.80, 9.10), Vector2(104.85, 9.70), Vector2(104.55, 10.40), Vector2(105.05, 10.90),
	Vector2(105.80, 11.00), Vector2(106.20, 11.70), Vector2(106.50, 11.95), Vector2(107.50, 12.30),
	Vector2(107.55, 12.80), Vector2(107.50, 13.60), Vector2(107.35, 14.40), Vector2(107.55, 14.70),
	Vector2(107.50, 15.40), Vector2(107.20, 15.80), Vector2(106.90, 16.40), Vector2(106.55, 17.00),
	Vector2(106.20, 17.50), Vector2(105.70, 18.10), Vector2(105.10, 18.70), Vector2(104.50, 19.10),
	Vector2(104.00, 19.40), Vector2(104.30, 19.75), Vector2(104.70, 20.00), Vector2(104.40, 20.55),
	Vector2(103.90, 20.80), Vector2(103.40, 20.85), Vector2(103.00, 21.10), Vector2(102.80, 21.45),
	Vector2(102.55, 21.90),
]

## Toạ độ gần đúng của trung tâm hành chính từng tỉnh/thành (kinh độ, vĩ độ).
const PROVINCE_POS := {
	"Lai Châu": Vector2(103.46, 22.39), "Điện Biên": Vector2(103.02, 21.39), "Sơn La": Vector2(103.91, 21.33),
	"Cao Bằng": Vector2(106.26, 22.67), "Lạng Sơn": Vector2(106.76, 21.85), "Tuyên Quang": Vector2(105.21, 22.15),
	"Lào Cai": Vector2(104.20, 22.10), "Thái Nguyên": Vector2(105.85, 21.59), "Phú Thọ": Vector2(105.30, 21.30),
	"Bắc Ninh": Vector2(106.15, 21.25), "Hưng Yên": Vector2(106.15, 20.60), "Ninh Bình": Vector2(105.97, 20.25),
	"Hải Phòng": Vector2(106.68, 20.86), "Quảng Ninh": Vector2(107.08, 21.10), "Thanh Hóa": Vector2(105.60, 19.80),
	"Nghệ An": Vector2(105.20, 19.00), "Hà Tĩnh": Vector2(105.90, 18.34), "Quảng Trị": Vector2(106.55, 17.30),
	"Huế": Vector2(107.59, 16.46), "Đà Nẵng": Vector2(108.10, 15.75), "Quảng Ngãi": Vector2(108.60, 14.90),
	"Gia Lai": Vector2(108.50, 13.90), "Đắk Lắk": Vector2(108.50, 12.80), "Lâm Đồng": Vector2(107.90, 11.80),
	"Khánh Hòa": Vector2(109.05, 12.10), "Tây Ninh": Vector2(106.20, 11.10), "Đồng Nai": Vector2(107.00, 11.40),
	"Cà Mau": Vector2(105.15, 9.18), "An Giang": Vector2(105.20, 10.30), "Đồng Tháp": Vector2(106.00, 10.45),
	"Vĩnh Long": Vector2(106.20, 9.95), "Cần Thơ": Vector2(105.75, 9.75), "Hà Nội": Vector2(105.75, 21.00),
	"TP. Hồ Chí Minh": Vector2(106.70, 10.78),
}

var land: CSGPolygon3D
var land_mat: StandardMaterial3D
var pins := {}       # tile -> Node3D cờ
var player_colors: Array = []


func build(colors: Array) -> void:
	player_colors = colors
	var poly := PackedVector2Array()
	for p in OUTLINE:
		poly.append(_xy(p))
	land = CSGPolygon3D.new()
	land.polygon = poly
	land.depth = 0.12
	land.rotation.x = -PI / 2
	land.position.y = 0.2
	land_mat = StandardMaterial3D.new()
	land_mat.albedo_color = Color(LAND_COLORS[0])
	land_mat.roughness = 0.95
	land.material = land_mat
	add_child(land)

	# Đảo
	_island(Vector2(103.97, 10.22), 0.22, "Phú Quốc")
	_archipelago(Vector2(111.9, 16.5), "QĐ. Hoàng Sa\n(Việt Nam)")
	_archipelago(Vector2(113.6, 10.2), "QĐ. Trường Sa\n(Việt Nam)")

	# Chấm tỉnh
	for t in BoardData.TILE_COUNT:
		if not BoardData.is_province(t):
			continue
		var name := BoardData.plain_name(t)
		var pos := _world(PROVINCE_POS.get(name, Vector2(LON0, LAT0)))
		var dot := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.07
		cm.height = 0.03
		dot.mesh = cm
		dot.material_override = _flat_mat(Color(BoardData.GROUPS[BoardData.tile(t)["group"]]["color"]))
		dot.position = pos + Vector3(0, 0.015, 0)
		add_child(dot)

	# Cây trên đất liền
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var placed := 0
	var tries := 0
	while placed < 22 and tries < 400:
		tries += 1
		var ll := Vector2(rng.randf_range(102.5, 109.3), rng.randf_range(9.0, 23.0))
		if not Geometry2D.is_point_in_polygon(ll, PackedVector2Array(OUTLINE)):
			continue
		add_child(_tree(_world(ll), rng.randf_range(0.5, 0.8)))
		placed += 1


func set_province_owner(t: int, owner_id: int, lvl: int) -> void:
	if pins.has(t):
		pins[t].queue_free()
		pins.erase(t)
	if owner_id < 0:
		return
	var name := BoardData.plain_name(t)
	var pin := Node3D.new()
	pin.position = _world(PROVINCE_POS.get(name, Vector2(LON0, LAT0)))
	var h := 0.35 + lvl * 0.12
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.012
	pm.bottom_radius = 0.012
	pm.height = h
	pole.mesh = pm
	pole.position.y = h / 2
	pole.material_override = _flat_mat(Color("#eeeeee"))
	pin.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.2, 0.13, 0.01)
	flag.mesh = fm
	flag.position = Vector3(0.1, h - 0.07, 0)
	flag.material_override = _flat_mat(Color(player_colors[owner_id]))
	pin.add_child(flag)
	if lvl >= GameEngine.LANDMARK:
		var star := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		star.mesh = sm
		star.position.y = h + 0.04
		var gm := _flat_mat(Color("#ffca28"))
		gm.emission_enabled = true
		gm.emission = Color("#ffca28")
		star.material_override = gm
		pin.add_child(star)
	add_child(pin)
	pins[t] = pin
	pin.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(pin, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_season(s: int) -> void:
	create_tween().tween_property(land_mat, "albedo_color", Color(LAND_COLORS[s]), 1.2)


## Vị trí trên bàn cờ (thế giới) của một tỉnh, dùng cho hiệu ứng.
func province_world(t: int) -> Vector3:
	return global_transform * _world(PROVINCE_POS.get(BoardData.plain_name(t), Vector2(LON0, LAT0)))


# ---------------------------------------------------------------- tiện ích

func _xy(ll: Vector2) -> Vector2:
	return Vector2((ll.x - LON0) * SCALE, (ll.y - LAT0) * SCALE)


func _world(ll: Vector2) -> Vector3:
	return Vector3((ll.x - LON0) * SCALE, 0.2, -(ll.y - LAT0) * SCALE)


func _island(ll: Vector2, r: float, label: String) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.8
	cm.bottom_radius = r
	cm.height = 0.1
	mi.mesh = cm
	mi.material_override = land_mat
	mi.position = _world(ll) + Vector3(0, -0.05, 0)
	add_child(mi)
	if label != "":
		var l := _label(label, 30)
		l.position = _world(ll) + Vector3(0, 0.02, 0.35)
		add_child(l)


func _archipelago(ll: Vector2, label: String) -> void:
	var offsets := [Vector2(0, 0), Vector2(0.35, 0.25), Vector2(-0.3, 0.3), Vector2(0.2, -0.35), Vector2(-0.25, -0.2)]
	for o in offsets:
		_island(ll + o, 0.09, "")
	var l := _label(label, 34)
	l.position = _world(ll) + Vector3(0, 0.02, 0.75)
	add_child(l)


func _label(text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.rotation.x = -PI / 2
	l.modulate = Color("#0d47a1")
	l.outline_size = 8
	l.outline_modulate = Color(1, 1, 1, 0.8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return l


func _tree(p: Vector3, s: float) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.scale = Vector3.ONE * s
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.18
	cm.height = 0.4
	cm.radial_segments = 6
	crown.mesh = cm
	crown.position.y = 0.2
	crown.material_override = _flat_mat(Color("#2e7d32"))
	n.add_child(crown)
	return n


var _mat_cache := {}


func _flat_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	_mat_cache[key] = m
	return m
