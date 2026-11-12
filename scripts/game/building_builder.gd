class_name BuildingBuilder
extends RefCounted
## Mô hình công trình trên ô đất, ghép từ mesh nguyên thủy (dùng chung qua MeshCache), mảng màu theo chủ sở hữu.
##   Loại: generic (chưa chọn loại), restaurant (Nhà hàng), homestay, market (Chợ), workshop (Xưởng đặc sản)
##   Cấp 1 nhà nhỏ, cấp 2 lớn hơn/thêm tầng, cấp 3 = Danh Thắng của tỉnh (LandmarkBuilder) + biển màu chủ.
##   Hạ tầng (Bến Xe, Ga, Cảng, Sân Bay, Trạm BOT): mô hình cố định khi có chủ.
## Khung đặt: dải màu mép trong của ô, rộng ~1,05 × sâu ~0,42.

const WALL := Color("#fff3e0")
const ROOF := Color("#b23a2a")
const WOOD := Color("#8d6e63")
const GLASS := Color("#90caf9")
const DARK := Color("#3e2723")
const W := 1.0


static func build(kind: String, level: int, owner: Color, province: int = -1) -> Node3D:
	var n := Node3D.new()
	if level >= GameEngine.LANDMARK and province >= 0:
		n.add_child(LandmarkBuilder.build(String(BoardData.tile(province)["landmark"]), owner))
		_pennant(n, Vector3(0.44, 0.0, 0.14), owner)
		return n
	match kind:
		"restaurant":
			_restaurant(n, level, owner)
		"homestay":
			_homestay(n, level, owner)
		"market":
			_market(n, level, owner)
		"workshop":
			_workshop(n, level, owner)
		_:
			_generic(n, level, owner)
	return n


## Mô hình hạ tầng khi có chủ.
static func infra(name: String, owner: Color) -> Node3D:
	var n := Node3D.new()
	match name:
		"Bến Xe Khách":
			# xe khách + biển trạm
			n.add_child(_b(Vector3(0.5, 0.2, 0.2), Color("#fdd835"), Vector3(-0.1, 0.13, 0)))
			n.add_child(_b(Vector3(0.5, 0.05, 0.205), owner, Vector3(-0.1, 0.1, 0)))
			n.add_child(_b(Vector3(0.42, 0.07, 0.21), GLASS, Vector3(-0.1, 0.19, 0)))
			for x in [-0.28, 0.08]:
				n.add_child(_cy(0.045, 0.045, 0.21, DARK, Vector3(x, 0.04, 0), Vector3(PI / 2, 0, 0)))
			n.add_child(_b(Vector3(0.025, 0.4, 0.025), Color("#9e9e9e"), Vector3(0.3, 0.2, 0)))
			n.add_child(_b(Vector3(0.16, 0.12, 0.02), owner, Vector3(0.3, 0.4, 0)))
		"Ga Đường Sắt":
			n.add_child(_b(Vector3(0.95, 0.02, 0.06), Color("#6d4c41"), Vector3(0, 0.01, 0.15)))
			n.add_child(_b(Vector3(0.95, 0.02, 0.02), Color("#9e9e9e"), Vector3(0, 0.025, 0.13)))
			n.add_child(_b(Vector3(0.95, 0.02, 0.02), Color("#9e9e9e"), Vector3(0, 0.025, 0.17)))
			n.add_child(_b(Vector3(0.55, 0.22, 0.2), WALL, Vector3(0, 0.11, -0.05)))
			n.add_child(_p(Vector3(0.62, 0.12, 0.26), owner, Vector3(0, 0.28, -0.05)))
			n.add_child(_cy(0.05, 0.05, 0.02, Color.WHITE, Vector3(0, 0.17, 0.051), Vector3(PI / 2, 0, 0)))
		"Cảng Biển":
			n.add_child(_b(Vector3(0.06, 0.55, 0.06), Color("#ffb300"), Vector3(-0.3, 0.27, 0)))
			n.add_child(_b(Vector3(0.6, 0.05, 0.05), Color("#ffb300"), Vector3(-0.05, 0.53, 0)))
			n.add_child(_b(Vector3(0.012, 0.25, 0.012), DARK, Vector3(0.18, 0.4, 0)))
			var cols := [owner, Color("#1e88e5"), owner.darkened(0.3)]
			for k in 3:
				n.add_child(_b(Vector3(0.22, 0.12, 0.13), cols[k], Vector3(0.05 + (k % 2) * 0.24, 0.06 + (k / 2) * 0.12, 0.05)))
		"Sân Bay":
			n.add_child(_cy(0.06, 0.07, 0.42, Color("#eceff1"), Vector3(-0.32, 0.21, 0)))
			n.add_child(_cy(0.11, 0.09, 0.1, GLASS, Vector3(-0.32, 0.46, 0)))
			n.add_child(_cy(0.12, 0.12, 0.02, owner, Vector3(-0.32, 0.52, 0)))
			var plane := Node3D.new()
			plane.position = Vector3(0.15, 0.1, 0)
			plane.rotation.y = 0.3
			var body := MeshCache.mi(MeshCache.capsule(0.05, 0.5), Color.WHITE)
			body.rotation.z = PI / 2
			plane.add_child(body)
			plane.add_child(_b(Vector3(0.12, 0.012, 0.46), Color.WHITE, Vector3(0.0, 0.0, 0)))
			plane.add_child(_b(Vector3(0.05, 0.12, 0.012), owner, Vector3(-0.22, 0.06, 0)))
			n.add_child(plane)
		_:
			# Trạm BOT: chòi thu phí mái màu chủ
			n.add_child(_b(Vector3(0.2, 0.22, 0.18), WALL, Vector3(0.3, 0.11, 0)))
			n.add_child(_b(Vector3(0.26, 0.04, 0.24), owner, Vector3(0.3, 0.24, 0)))
			n.add_child(_b(Vector3(0.15, 0.08, 0.01), GLASS, Vector3(0.3, 0.14, 0.091)))
	return n


## Cờ chủ sở hữu cắm trên ô.
static func flag(owner: Color) -> Node3D:
	var n := Node3D.new()
	n.add_child(_cy(0.012, 0.012, 0.55, Color("#eeeeee"), Vector3(0, 0.275, 0)))
	n.add_child(_sp(0.022, Color("#ffd54f"), Vector3(0, 0.56, 0), true))
	var cloth := Node3D.new()
	cloth.name = "Cloth"
	cloth.position = Vector3(0, 0.47, 0)
	cloth.add_child(_b(Vector3(0.2, 0.13, 0.008), owner, Vector3(0.1, 0, 0)))
	n.add_child(cloth)
	return n


# ---------------------------------------------------------------- các loại công trình

static func _generic(n: Node3D, level: int, c: Color) -> void:
	if level <= 1:
		n.add_child(_b(Vector3(0.3, 0.2, 0.28), WALL, Vector3(0, 0.1, 0)))
		n.add_child(_p(Vector3(0.38, 0.16, 0.32), c, Vector3(0, 0.28, 0)))
		n.add_child(_b(Vector3(0.07, 0.12, 0.01), DARK, Vector3(0, 0.06, 0.141)))
		n.add_child(_b(Vector3(0.05, 0.12, 0.05), ROOF, Vector3(0.1, 0.36, -0.05)))
	else:
		n.add_child(_b(Vector3(0.5, 0.42, 0.32), WALL, Vector3(-0.08, 0.21, 0)))
		n.add_child(_b(Vector3(0.52, 0.05, 0.34), c, Vector3(-0.08, 0.22, 0)))
		n.add_child(_p(Vector3(0.58, 0.16, 0.36), ROOF, Vector3(-0.08, 0.5, 0)))
		for x in [-0.22, -0.08, 0.06]:
			for y in [0.1, 0.32]:
				n.add_child(_b(Vector3(0.07, 0.07, 0.01), GLASS, Vector3(x, y, 0.161)))
		_tree(n, Vector3(0.33, 0, 0.02), 0.9)


static func _restaurant(n: Node3D, level: int, c: Color) -> void:
	var w := 0.48 if level <= 1 else 0.8
	var h := 0.24 if level <= 1 else 0.44
	n.add_child(_b(Vector3(w, h, 0.3), Color("#ffe0b2"), Vector3(0, h / 2, 0)))
	# mái hiên sọc màu chủ – trắng
	var stripes := 6 if level <= 1 else 10
	for k in stripes:
		var x := -w / 2 + (k + 0.5) * w / stripes
		var s := _b(Vector3(w / stripes, 0.012, 0.16), c if k % 2 == 0 else Color.WHITE, Vector3(x, h * 0.62, 0.21))
		s.rotation.x = 0.45
		n.add_child(s)
	n.add_child(_b(Vector3(w * 0.5, 0.1, 0.02), c.darkened(0.25), Vector3(0, h + 0.07, 0.1)))
	n.add_child(_b(Vector3(w * 0.42, 0.05, 0.022), Color("#ffd54f"), Vector3(0, h + 0.07, 0.1), true))
	n.add_child(_sp(0.035, Color("#e53935"), Vector3(-w / 2 + 0.05, h * 0.5, 0.17), true))
	n.add_child(_sp(0.035, Color("#e53935"), Vector3(w / 2 - 0.05, h * 0.5, 0.17), true))
	n.add_child(_b(Vector3(w * 0.85, 0.06, 0.01), GLASS, Vector3(0, h * 0.3, 0.151)))
	if level >= 2:
		# sân thượng có ô dù
		for x in [-0.22, 0.05, 0.28]:
			n.add_child(_cy(0.008, 0.008, 0.14, DARK, Vector3(x, h + 0.07, -0.05)))
			n.add_child(_cy(0.0, 0.1, 0.05, c, Vector3(x, h + 0.15, -0.05)))


static func _homestay(n: Node3D, level: int, c: Color) -> void:
	var count := 1 if level <= 1 else 2
	for k in count:
		var ox := 0.0 if count == 1 else (-0.24 if k == 0 else 0.24)
		# nhà sàn: cột, sàn, thân gỗ, mái dốc
		for sx in [-0.12, 0.12]:
			for sz in [-0.1, 0.1]:
				n.add_child(_b(Vector3(0.025, 0.12, 0.025), WOOD.darkened(0.3), Vector3(ox + sx, 0.06, sz)))
		n.add_child(_b(Vector3(0.32, 0.03, 0.26), WOOD, Vector3(ox, 0.13, 0)))
		n.add_child(_b(Vector3(0.28, 0.15, 0.22), Color("#bcaaa4"), Vector3(ox, 0.22, 0)))
		n.add_child(_p(Vector3(0.38, 0.2, 0.3), Color("#c8a165"), Vector3(ox, 0.39, 0)))
		n.add_child(_b(Vector3(0.39, 0.025, 0.04), c, Vector3(ox, 0.49, 0)))
		n.add_child(_b(Vector3(0.06, 0.06, 0.01), Color("#ffe082"), Vector3(ox, 0.22, 0.111), true))
	if level >= 2:
		n.add_child(MeshCache.mi(MeshCache.cyl(0.13, 0.13, 0.02, 16), GLASS.darkened(0.1), Vector3(0, 0.01, 0.15)))
		_tree(n, Vector3(0.45, 0, -0.08), 0.8)


static func _market(n: Node3D, level: int, c: Color) -> void:
	if level >= 2:
		n.add_child(_b(Vector3(0.84, 0.18, 0.26), Color("#ffe0b2"), Vector3(0, 0.09, -0.04)))
		n.add_child(_p(Vector3(0.9, 0.12, 0.3), c, Vector3(0, 0.24, -0.04)))
		n.add_child(_b(Vector3(0.025, 0.4, 0.025), Color("#eeeeee"), Vector3(0.38, 0.38, -0.04)))
		n.add_child(_b(Vector3(0.14, 0.09, 0.01), c, Vector3(0.45, 0.53, -0.04)))
	var stalls := 2 if level <= 1 else 3
	var fruits := [Color("#e53935"), Color("#fdd835"), Color("#43a047"), Color("#ff9800")]
	for k in stalls:
		var x := -0.3 + k * (0.6 / maxf(1.0, stalls - 1.0))
		var z := 0.0 if level <= 1 else 0.14
		for sx in [-0.09, 0.09]:
			n.add_child(_b(Vector3(0.018, 0.2, 0.018), WOOD, Vector3(x + sx, 0.1, z)))
		n.add_child(_p(Vector3(0.24, 0.1, 0.2), c if k % 2 == 0 else Color.WHITE, Vector3(x, 0.25, z)))
		n.add_child(_b(Vector3(0.18, 0.06, 0.12), WOOD.lightened(0.2), Vector3(x, 0.05, z)))
		for f in 3:
			n.add_child(_sp(0.025, fruits[(k + f) % 4], Vector3(x - 0.05 + f * 0.05, 0.1, z)))


static func _workshop(n: Node3D, level: int, c: Color) -> void:
	var w := 0.46 if level <= 1 else 0.76
	n.add_child(_b(Vector3(w, 0.22, 0.28), Color("#b0bec5"), Vector3(-0.05, 0.11, 0)))
	var teeth := 2 if level <= 1 else 4
	for k in teeth:
		var x := -0.05 - w / 2 + (k + 0.5) * w / teeth
		var tooth := _p(Vector3(w / teeth, 0.1, 0.28), c if k % 2 == 0 else c.darkened(0.25), Vector3(x, 0.27, 0))
		n.add_child(tooth)
	var chimneys := 1 if level <= 1 else 2
	for k in chimneys:
		var x := 0.26 + k * 0.12 if level <= 1 else 0.28 + k * 0.1
		n.add_child(_cy(0.035, 0.045, 0.42, Color("#8d6e63"), Vector3(x - 0.1 * k, 0.21, -0.07)))
		n.add_child(_cy(0.047, 0.047, 0.04, c, Vector3(x - 0.1 * k, 0.38, -0.07)))
		n.add_child(_sp(0.05, Color("#cfd8dc"), Vector3(x - 0.1 * k, 0.5, -0.07), false, 0.75))
	n.add_child(_b(Vector3(0.12, 0.13, 0.01), DARK, Vector3(-0.05, 0.065, 0.141)))
	if level >= 2:
		for k in 3:
			n.add_child(_b(Vector3(0.09, 0.09, 0.09), Color("#d7a86e"), Vector3(0.35 - k * 0.1, 0.045, 0.15)))


# ---------------------------------------------------------------- chi tiết phụ

static func _pennant(n: Node3D, at: Vector3, c: Color) -> void:
	n.add_child(_b(Vector3(0.015, 0.4, 0.015), Color("#eeeeee"), at + Vector3(0, 0.2, 0)))
	n.add_child(_b(Vector3(0.14, 0.09, 0.008), c, at + Vector3(0.07, 0.35, 0)))


static func _tree(n: Node3D, at: Vector3, s: float) -> void:
	n.add_child(_cy(0.02 * s, 0.025 * s, 0.12 * s, WOOD, at + Vector3(0, 0.06 * s, 0)))
	n.add_child(_cy(0.0, 0.09 * s, 0.24 * s, Color("#2e7d32"), at + Vector3(0, 0.22 * s, 0)))


static func _b(size: Vector3, c: Color, pos: Vector3, glow: bool = false) -> MeshInstance3D:
	return MeshCache.mi(MeshCache.box(size), c, pos, glow)


static func _p(size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	return MeshCache.mi(MeshCache.prism(size), c, pos)


static func _cy(top: float, bottom: float, h: float, c: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshCache.mi(MeshCache.cyl(top, bottom, h, 10), c, pos)
	m.rotation = rot
	return m


static func _sp(r: float, c: Color, pos: Vector3, glow: bool = false, alpha: float = 1.0) -> MeshInstance3D:
	return MeshCache.mi(MeshCache.sphere(r, 10), c, pos, glow, alpha)
