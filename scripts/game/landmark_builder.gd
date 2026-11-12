class_name LandmarkBuilder
extends RefCounted
## Mô hình Danh Thắng low-poly cho từng tỉnh, dựng bằng khối cơ bản.
## Mỗi danh thắng thuộc 1 kiểu dáng; màu chủ sở hữu được dùng làm điểm nhấn.

const STYLE := {
	"Cầu kính Rồng Mây": "bridge", "Đồi A1": "flag", "Cao nguyên Mộc Châu": "hills",
	"Thác Bản Giốc": "waterfall", "Động Tam Thanh": "cave", "Cột cờ Lũng Cú": "flag",
	"Đỉnh Fansipan": "peak", "Hồ Núi Cốc": "lake", "Đền Hùng": "gate", "Chùa Dâu": "pagoda",
	"Phố Hiến": "oldtown", "Tràng An": "karst", "Đảo Cát Bà": "karst", "Vịnh Hạ Long": "karst",
	"Thành nhà Hồ": "citadel", "Làng Sen": "village", "Ngã ba Đồng Lộc": "memorial",
	"Động Phong Nha": "cave", "Đại Nội": "citadel", "Phố cổ Hội An": "oldtown", "Đảo Lý Sơn": "island",
	"Biển Hồ": "lake", "Gành Đá Đĩa": "island", "Hồ Xuân Hương": "lake", "Tháp Bà Ponagar": "tower",
	"Núi Bà Đen": "peak", "Vườn quốc gia Cát Tiên": "forest", "Mũi Cà Mau": "cape",
	"Đảo Phú Quốc": "island", "Tràm Chim": "forest", "Văn Thánh Miếu": "gate",
	"Chợ nổi Cái Răng": "boats", "Hồ Gươm": "turtle_tower", "Chợ Bến Thành": "market",
}

const GOLD := "#ffca28"
const STONE := "#bcaaa4"
const ROCK := "#8d8d8d"
const WATER := "#4fc3f7"
const GREEN := "#558b2f"
const ROOF := "#b71c1c"

static var _mats := {}


static func build(landmark_name: String, accent: Color) -> Node3D:
	var root := Node3D.new()
	var style: String = STYLE.get(landmark_name, "pagoda")
	# Bệ vàng chung cho mọi danh thắng
	var plinth := _box(Vector3(1.0, 0.06, 0.46), GOLD, true)
	plinth.position.y = 0.03
	root.add_child(plinth)
	var n := Node3D.new()
	n.position.y = 0.06
	root.add_child(n)
	match style:
		"pagoda":
			_pagoda(n, accent, 4)
		"tower":
			for k in 3:
				var t := _box(Vector3(0.24 - k * 0.03, 0.55 - k * 0.12, 0.24 - k * 0.03), "#a1503a")
				t.position = Vector3(-0.3 + k * 0.3, (0.55 - k * 0.12) / 2, 0)
				n.add_child(t)
				var cap := _cone(0.12 - k * 0.015, 0.18, "#8d3a2a")
				cap.position = Vector3(-0.3 + k * 0.3, 0.55 - k * 0.12 + 0.09, 0)
				n.add_child(cap)
		"bridge":
			for sx in [-1, 1]:
				var pier := _box(Vector3(0.08, 0.5, 0.08), STONE)
				pier.position = Vector3(sx * 0.35, 0.25, 0)
				n.add_child(pier)
			var deck := _box(Vector3(0.95, 0.04, 0.16), "#90caf9", false, 0.6)
			deck.position.y = 0.5
			n.add_child(deck)
			for k in 7:
				var x := -0.42 + k * 0.14
				var arch := _box(Vector3(0.1, 0.03, 0.03), accent)
				arch.position = Vector3(x, 0.6 + sin(k / 6.0 * PI) * 0.15, -0.09)
				n.add_child(arch)
		"flag":
			var hill := _cone(0.4, 0.3, GREEN)
			hill.position.y = 0.15
			n.add_child(hill)
			var tower := _box(Vector3(0.14, 0.4, 0.14), STONE)
			tower.position.y = 0.45
			n.add_child(tower)
			var pole := _box(Vector3(0.02, 0.4, 0.02), "#eeeeee")
			pole.position.y = 0.85
			n.add_child(pole)
			var flag := _box(Vector3(0.24, 0.16, 0.01), "#da251d")
			flag.position = Vector3(0.13, 0.96, 0)
			n.add_child(flag)
			var star := _box(Vector3(0.05, 0.05, 0.012), "#ffeb3b")
			star.position = Vector3(0.13, 0.96, 0.003)
			star.rotation.z = PI / 4
			n.add_child(star)
		"hills":
			for k in 3:
				var h := _sphere(0.22 - k * 0.03, "#7cb342")
				h.position = Vector3(-0.3 + k * 0.3, 0.08, 0)
				h.scale = Vector3(1.2, 0.7, 1)
				n.add_child(h)
			for k in 4:
				var tea := _box(Vector3(0.8, 0.04, 0.04), "#33691e")
				tea.position = Vector3(0, 0.1 + k * 0.05, -0.15 + k * 0.08)
				n.add_child(tea)
			_flag_pin(n, Vector3(0.35, 0.25, 0.1), accent)
		"waterfall":
			var cliff := _box(Vector3(0.9, 0.55, 0.18), ROCK)
			cliff.position = Vector3(0, 0.275, -0.12)
			n.add_child(cliff)
			for k in 3:
				var fall := _box(Vector3(0.18, 0.5, 0.03), "#e1f5fe", false, 0.85)
				fall.position = Vector3(-0.28 + k * 0.28, 0.26, -0.02)
				n.add_child(fall)
			var pool := _box(Vector3(0.95, 0.03, 0.18), WATER, false, 0.8)
			pool.position = Vector3(0, 0.02, 0.12)
			n.add_child(pool)
			_flag_pin(n, Vector3(0.4, 0.6, -0.12), accent)
		"cave":
			var mount := _cone(0.45, 0.65, ROCK)
			mount.position.y = 0.32
			n.add_child(mount)
			var mouth := _sphere(0.14, "#212121")
			mouth.position = Vector3(0, 0.1, 0.2)
			mouth.scale = Vector3(1, 1, 0.4)
			n.add_child(mouth)
			_flag_pin(n, Vector3(0.0, 0.66, 0.0), accent)
		"peak":
			var m1 := _cone(0.38, 0.8, "#6d7b6a")
			m1.position = Vector3(0.05, 0.4, 0)
			n.add_child(m1)
			var m2 := _cone(0.25, 0.5, "#7d8b7a")
			m2.position = Vector3(-0.3, 0.25, 0.05)
			n.add_child(m2)
			var snow := _cone(0.1, 0.2, "#fafafa")
			snow.position = Vector3(0.05, 0.72, 0)
			n.add_child(snow)
			var cable := _box(Vector3(0.6, 0.01, 0.01), "#212121")
			cable.position = Vector3(0.2, 0.45, 0.12)
			cable.rotation.z = 0.5
			n.add_child(cable)
			_flag_pin(n, Vector3(0.05, 0.82, 0), accent)
		"lake", "turtle_tower":
			var lake := _cyl(0.42, 0.42, 0.04, WATER, 0.85)
			lake.position.y = 0.02
			lake.scale = Vector3(1.1, 1, 0.5)
			n.add_child(lake)
			if style == "turtle_tower":
				var isle := _cyl(0.08, 0.1, 0.05, "#689f38")
				isle.position = Vector3(0.1, 0.05, 0)
				n.add_child(isle)
				for k in 3:
					var tier := _box(Vector3(0.13 - k * 0.025, 0.09, 0.13 - k * 0.025), "#d7ccc8")
					tier.position = Vector3(0.1, 0.12 + k * 0.09, 0)
					n.add_child(tier)
				var roof := _cone(0.08, 0.1, ROOF)
				roof.position = Vector3(0.1, 0.43, 0)
				n.add_child(roof)
				var bridge := _box(Vector3(0.35, 0.04, 0.05), "#e53935")
				bridge.position = Vector3(-0.28, 0.08, 0.05)
				bridge.rotation.z = 0.2
				n.add_child(bridge)
			else:
				var gazebo := _pagoda_small(accent)
				gazebo.position = Vector3(-0.25, 0.04, 0)
				n.add_child(gazebo)
				for k in 4:
					var pine := _cone(0.07, 0.35, "#2e7d32")
					pine.position = Vector3(0.15 + k * 0.08, 0.2, -0.12 + (k % 2) * 0.08)
					n.add_child(pine)
		"karst":
			var sea := _box(Vector3(0.98, 0.03, 0.44), WATER, false, 0.85)
			sea.position.y = 0.015
			n.add_child(sea)
			var spots := [Vector3(-0.32, 0, -0.08), Vector3(-0.05, 0, 0.08), Vector3(0.22, 0, -0.1), Vector3(0.38, 0, 0.1)]
			var heights := [0.45, 0.6, 0.4, 0.3]
			for k in spots.size():
				var rock := _capsule(0.08, heights[k], "#78866b")
				rock.position = spots[k] + Vector3(0, heights[k] / 2, 0)
				n.add_child(rock)
			var boat := _box(Vector3(0.16, 0.04, 0.06), "#6d4c41")
			boat.position = Vector3(0.08, 0.05, 0.16)
			n.add_child(boat)
			var sail := _box(Vector3(0.01, 0.14, 0.1), "#d84315")
			sail.position = Vector3(0.08, 0.13, 0.16)
			n.add_child(sail)
			_flag_pin(n, Vector3(-0.05, 0.62, 0.08), accent)
		"island", "cape":
			var sea := _box(Vector3(0.98, 0.03, 0.44), WATER, false, 0.85)
			sea.position.y = 0.015
			n.add_child(sea)
			var land := _sphere(0.3, "#cddc39" if style == "island" else "#33691e")
			land.position = Vector3(0, 0.0, 0)
			land.scale = Vector3(1.3, 0.45, 0.6)
			n.add_child(land)
			for k in 3:
				var palm := _box(Vector3(0.025, 0.3, 0.025), "#795548")
				palm.position = Vector3(-0.2 + k * 0.2, 0.25, 0)
				n.add_child(palm)
				var leaves := _sphere(0.08, "#43a047")
				leaves.position = Vector3(-0.2 + k * 0.2, 0.42, 0)
				leaves.scale = Vector3(1.4, 0.5, 1.4)
				n.add_child(leaves)
			if style == "cape":
				var marker := _box(Vector3(0.1, 0.35, 0.1), STONE)
				marker.position = Vector3(0.38, 0.17, 0.05)
				n.add_child(marker)
			_flag_pin(n, Vector3(0.3, 0.15, -0.05), accent)
		"gate", "citadel":
			var wall := _box(Vector3(0.9, 0.32, 0.16), STONE if style == "citadel" else "#e0c9a6")
			wall.position = Vector3(0, 0.16, -0.05)
			n.add_child(wall)
			var hole := _box(Vector3(0.18, 0.2, 0.17), "#3e2723")
			hole.position = Vector3(0, 0.1, -0.05)
			n.add_child(hole)
			var tower := _box(Vector3(0.36, 0.16, 0.2), accent)
			tower.position = Vector3(0, 0.4, -0.05)
			n.add_child(tower)
			var roof := _roof(Vector3(0.46, 0.14, 0.28), ROOF)
			roof.position = Vector3(0, 0.55, -0.05)
			n.add_child(roof)
			if style == "gate":
				for sx in [-1, 1]:
					var post := _box(Vector3(0.05, 0.4, 0.05), "#d32f2f")
					post.position = Vector3(sx * 0.32, 0.2, 0.15)
					n.add_child(post)
		"oldtown":
			for k in 4:
				var house := _box(Vector3(0.2, 0.22, 0.22), "#fdd835" if k % 2 == 0 else "#ffb74d")
				house.position = Vector3(-0.36 + k * 0.24, 0.11, 0)
				n.add_child(house)
				var roof := _roof(Vector3(0.24, 0.1, 0.26), "#a1503a")
				roof.position = Vector3(-0.36 + k * 0.24, 0.27, 0)
				n.add_child(roof)
				var lantern := _sphere(0.035, "#e53935", true)
				lantern.position = Vector3(-0.36 + k * 0.24, 0.17, 0.14)
				n.add_child(lantern)
		"village":
			var pond := _cyl(0.25, 0.25, 0.03, WATER, 0.85)
			pond.position = Vector3(0.22, 0.015, 0)
			n.add_child(pond)
			for k in 4:
				var lotus := _sphere(0.035, "#f48fb1")
				lotus.position = Vector3(0.12 + (k % 2) * 0.18, 0.04, -0.07 + (k / 2) * 0.14)
				n.add_child(lotus)
			var house := _box(Vector3(0.3, 0.18, 0.22), "#d7ccc8")
			house.position = Vector3(-0.22, 0.09, 0)
			n.add_child(house)
			var thatch := _roof(Vector3(0.36, 0.14, 0.28), "#c8a165")
			thatch.position = Vector3(-0.22, 0.25, 0)
			n.add_child(thatch)
		"memorial":
			var base := _box(Vector3(0.5, 0.08, 0.3), STONE)
			base.position.y = 0.04
			n.add_child(base)
			var stele := _box(Vector3(0.14, 0.6, 0.08), "#eceff1")
			stele.position.y = 0.38
			n.add_child(stele)
			for sx in [-1, 1]:
				var flower := _sphere(0.05, "#e53935")
				flower.position = Vector3(sx * 0.15, 0.12, 0.08)
				n.add_child(flower)
			_flag_pin(n, Vector3(0.0, 0.68, 0), accent)
		"forest":
			for k in 9:
				var x := -0.4 + (k % 5) * 0.2
				var z := -0.1 + (k / 5) * 0.18
				var tree := _cone(0.09, 0.32 + (k % 3) * 0.08, "#2e7d32" if k % 2 == 0 else "#388e3c")
				tree.position = Vector3(x, 0.18, z)
				n.add_child(tree)
			for k in 3:
				var bird := _box(Vector3(0.08, 0.01, 0.03), "#fafafa")
				bird.position = Vector3(-0.2 + k * 0.2, 0.62 + (k % 2) * 0.06, 0)
				n.add_child(bird)
		"boats":
			var river := _box(Vector3(0.98, 0.03, 0.44), "#8d9e5a", false, 0.9)
			river.position.y = 0.015
			n.add_child(river)
			for k in 4:
				var boat := _box(Vector3(0.2, 0.06, 0.08), "#6d4c41")
				boat.position = Vector3(-0.33 + k * 0.22, 0.05, -0.08 + (k % 2) * 0.16)
				n.add_child(boat)
				var goods := _sphere(0.04, ["#e53935", "#fdd835", "#43a047", "#ff9800"][k])
				goods.position = Vector3(-0.33 + k * 0.22, 0.1, -0.08 + (k % 2) * 0.16)
				n.add_child(goods)
				var pole := _box(Vector3(0.01, 0.25, 0.01), "#795548")
				pole.position = Vector3(-0.33 + k * 0.22, 0.2, -0.08 + (k % 2) * 0.16)
				n.add_child(pole)
		"market":
			var hall := _box(Vector3(0.8, 0.22, 0.3), "#ffe0b2")
			hall.position.y = 0.11
			n.add_child(hall)
			var roof := _roof(Vector3(0.86, 0.1, 0.34), "#8d6e63")
			roof.position.y = 0.27
			n.add_child(roof)
			var tower := _box(Vector3(0.16, 0.34, 0.16), "#ffe0b2")
			tower.position.y = 0.39
			n.add_child(tower)
			var clock := _cyl(0.05, 0.05, 0.01, "#fafafa")
			clock.rotation.x = PI / 2
			clock.position = Vector3(0, 0.46, 0.085)
			n.add_child(clock)
			var top := _cone(0.1, 0.12, accent)
			top.position.y = 0.62
			n.add_child(top)
	return root


static func _pagoda(n: Node3D, accent: Color, tiers: int) -> void:
	var y := 0.0
	for k in tiers:
		var w := 0.5 - k * 0.08
		var body := _box(Vector3(w * 0.7, 0.14, w * 0.5), "#fff3e0" if k % 2 == 0 else accent)
		body.position.y = y + 0.07
		n.add_child(body)
		var roof := _roof(Vector3(w, 0.07, w * 0.65), ROOF)
		roof.position.y = y + 0.17
		n.add_child(roof)
		y += 0.19
	var spire := _cone(0.04, 0.16, GOLD, true)
	spire.position.y = y + 0.06
	n.add_child(spire)


static func _pagoda_small(accent: Color) -> Node3D:
	var n := Node3D.new()
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var post := _box(Vector3(0.025, 0.18, 0.025), "#8d6e63")
			post.position = Vector3(sx * 0.08, 0.09, sz * 0.08)
			n.add_child(post)
	var roof := _roof(Vector3(0.26, 0.1, 0.26), accent)
	roof.position.y = 0.22
	n.add_child(roof)
	return n


static func _flag_pin(n: Node3D, at: Vector3, accent: Color) -> void:
	var pole := _box(Vector3(0.015, 0.22, 0.015), "#eeeeee")
	pole.position = at + Vector3(0, 0.11, 0)
	n.add_child(pole)
	var flag := _box(Vector3(0.12, 0.08, 0.01), accent)
	flag.position = at + Vector3(0.065, 0.18, 0)
	n.add_child(flag)


# ---------------------------------------------------------------- khối cơ bản

static func _mat(col: Variant, glow: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var c: Color = col if col is Color else Color(col)
	var key := "%s|%s|%s" % [c.to_html(), glow, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = 0.75
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.35
	_mats[key] = m
	return m


static func _mi(mesh: Mesh, col: Variant, glow: bool = false, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, glow, alpha)
	return mi


static func _box(size: Vector3, col: Variant, glow: bool = false, alpha: float = 1.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mi(bm, col, glow, alpha)


static func _roof(size: Vector3, col: Variant) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = size
	return _mi(pm, col)


static func _cone(r: float, h: float, col: Variant, glow: bool = false) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	return _mi(cm, col, glow)


static func _cyl(top: float, bottom: float, h: float, col: Variant, alpha: float = 1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 20
	return _mi(cm, col, false, alpha)


static func _sphere(r: float, col: Variant, glow: bool = false) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 12
	sm.rings = 6
	return _mi(sm, col, glow)


static func _capsule(r: float, h: float, col: Variant) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2)
	cm.radial_segments = 8
	cm.rings = 3
	return _mi(cm, col)
