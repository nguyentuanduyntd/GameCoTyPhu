class_name BoardView
extends Node3D
## Dựng bàn cờ 3D bằng code (low-poly), hiển thị chủ sở hữu, nhà, lễ hội, mùa.

const W := 1.2   # bề ngang ô cạnh
const C := 2.0   # cạnh ô góc
const D := 2.0   # chiều sâu ô cạnh
const TILE_Y := 0.1
const H := (2.0 * C + 11.0 * W) / 2.0

const CORNER_COLORS := {0: "#ffe082", 12: "#ef9a9a", 24: "#f48fb1", 36: "#90caf9"}
const SEASON_GROUND := ["#9ccc65", "#7cb342", "#c0ca33", "#90a4ae"]

var tile_xforms: Array = []
var tile_sizes: Array = []
var building_roots: Array = []
var owner_strips: Array = []
var info_labels: Array = []
var highlight_nodes: Array = []
var festival_marker: Node3D
var center_ground: MeshInstance3D
var season_label: Label3D
var season_event_label: Label3D
var player_colors: Array = []
var _mat_cache := {}


func build(colors: Array) -> void:
	player_colors = colors
	_build_base()
	for i in BoardData.TILE_COUNT:
		_build_tile(i)
	_build_center()
	festival_marker = _make_festival_marker()
	festival_marker.visible = false
	add_child(festival_marker)


# ---------------------------------------------------------------- vị trí

func tile_transform(i: int) -> Transform3D:
	var pos := Vector3.ZERO
	var yaw := 0.0
	if i == 0:
		pos = Vector3(H - C / 2, 0, H - C / 2)
	elif i < 12:
		pos = Vector3(H - C - W * (i - 0.5), 0, H - D / 2)
	elif i == 12:
		pos = Vector3(-H + C / 2, 0, H - C / 2)
		yaw = -PI / 2
	elif i < 24:
		pos = Vector3(-H + D / 2, 0, H - C - W * (i - 12 - 0.5))
		yaw = -PI / 2
	elif i == 24:
		pos = Vector3(-H + C / 2, 0, -H + C / 2)
		yaw = PI
	elif i < 36:
		pos = Vector3(-H + C + W * (i - 24 - 0.5), 0, -H + D / 2)
		yaw = PI
	elif i == 36:
		pos = Vector3(H - C / 2, 0, -H + C / 2)
		yaw = PI / 2
	else:
		pos = Vector3(H - D / 2, 0, -H + C + W * (i - 36 - 0.5))
		yaw = PI / 2
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func is_corner(i: int) -> bool:
	return i % 12 == 0


func tile_center(i: int) -> Vector3:
	return tile_xforms[i].origin + Vector3(0, TILE_Y, 0)


## Vị trí đứng của quân thứ `slot` trong `count` quân cùng ô.
func slot_position(i: int, slot: int, count: int) -> Vector3:
	var local := Vector3.ZERO
	if count > 1:
		var cols := 3
		var col := slot % cols
		var row := slot / cols
		var spread := 0.6 if is_corner(i) else 0.34
		local.x = (col - 1) * spread
		local.z = 0.05 + row * 0.45 if not is_corner(i) else -0.3 + row * 0.6
	else:
		local.z = 0.15 if not is_corner(i) else 0.0
	return tile_xforms[i] * local + Vector3(0, TILE_Y, 0)


## Tìm ô tại điểm trên mặt bàn (dùng để chọn ô bằng chuột/chạm).
func tile_at(world: Vector3) -> int:
	for i in BoardData.TILE_COUNT:
		var local: Vector3 = tile_xforms[i].affine_inverse() * world
		var sz: Vector2 = tile_sizes[i]
		if absf(local.x) <= sz.x / 2 and absf(local.z) <= sz.y / 2:
			return i
	return -1


# ---------------------------------------------------------------- dựng

func _build_base() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2 * H + 0.6, 0.5, 2 * H + 0.6)
	base.mesh = bm
	base.position.y = -0.25
	base.material_override = _mat("#6d4c41")
	add_child(base)
	center_ground = MeshInstance3D.new()
	var cm := BoxMesh.new()
	var inner := 2 * H - 2 * D - 0.1
	cm.size = Vector3(inner, 0.08, inner)
	center_ground.mesh = cm
	center_ground.position.y = 0.04
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(SEASON_GROUND[0])
	gm.roughness = 0.95
	center_ground.material_override = gm
	add_child(center_ground)


func _build_tile(i: int) -> void:
	var td := BoardData.tile(i)
	var ty: int = td["type"]
	var xf := tile_transform(i)
	tile_xforms.append(xf)
	var corner := is_corner(i)
	var size := Vector2(C, C) if corner else Vector2(W, D)
	tile_sizes.append(size)

	var root := Node3D.new()
	root.transform = xf
	add_child(root)

	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(size.x - 0.04, 0.2, size.y - 0.04)
	face.mesh = fm
	var face_color := "#fbf3e0"
	if corner:
		face_color = CORNER_COLORS[i]
	elif ty == BoardData.T.CHANCE:
		face_color = "#fff3c4"
	elif ty == BoardData.T.INFRA:
		face_color = "#e3e7ea"
	elif ty == BoardData.T.TAX or ty == BoardData.T.MARKET or ty == BoardData.T.LOTTERY:
		face_color = "#f1e4ff"
	face.material_override = _mat(face_color)
	root.add_child(face)

	if ty == BoardData.T.PROVINCE:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x - 0.04, 0.06, 0.42)
		band.mesh = bm
		band.position = Vector3(0, 0.12, -D / 2 + 0.23)
		band.material_override = _mat(BoardData.GROUPS[td["group"]]["color"])
		root.add_child(band)

	# Tên ô
	var name_lbl := _flat_label(String(td["name"]), 46 if not corner else 64, size.x - 0.08)
	name_lbl.position = Vector3(0, 0.111, -0.15 if not corner else 0.35)
	root.add_child(name_lbl)

	# Dòng thông tin: giá / tiền thuê
	var info := _flat_label("", 40, size.x - 0.08)
	info.position = Vector3(0, 0.111, 0.6)
	info.modulate = Color("#5d4037")
	root.add_child(info)
	info_labels.append(info)
	if BoardData.is_property(i):
		info.text = BoardData.money(td["price"])
	elif ty == BoardData.T.CHANCE:
		info.text = "?"
		info.font_size = 60
		info.position.z = 0.45
	elif ty == BoardData.T.TAX:
		info.text = "10% tài sản"

	# Dải màu chủ sở hữu (mép ngoài)
	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(size.x - 0.04, 0.03, 0.18)
	strip.mesh = sm
	strip.position = Vector3(0, 0.115, size.y / 2 - 0.12)
	strip.visible = false
	root.add_child(strip)
	owner_strips.append(strip)

	# Chỗ đặt nhà (trên dải màu nhóm, mép trong)
	var broot := Node3D.new()
	broot.position = Vector3(0, 0.15, -D / 2 + 0.23)
	root.add_child(broot)
	building_roots.append(broot)

	# Viền sáng khi được chọn
	var hl := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(size.x, 0.05, size.y)
	hl.mesh = hm
	hl.position.y = 0.13
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(1.0, 0.85, 0.1, 0.45)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hl.material_override = hmat
	hl.visible = false
	root.add_child(hl)
	highlight_nodes.append(hl)

	if corner:
		_decorate_corner(i, root)


func _decorate_corner(i: int, root: Node3D) -> void:
	match i:
		0:
			# Cột mốc Km 0
			var post := _box(Vector3(0.35, 0.7, 0.2), "#eeeeee")
			post.position = Vector3(-0.55, 0.45, -0.45)
			root.add_child(post)
			var cap := _box(Vector3(0.37, 0.2, 0.22), "#e53935")
			cap.position = Vector3(-0.55, 0.85, -0.45)
			root.add_child(cap)
		12:
			# Mấy chiếc xe kẹt cứng
			var cols := ["#1e88e5", "#fdd835", "#43a047", "#8e24aa"]
			for k in 4:
				var car := _box(Vector3(0.22, 0.14, 0.42), cols[k])
				car.position = Vector3(-0.6 + k * 0.4, 0.2, -0.55 + (k % 2) * 0.15)
				root.add_child(car)
		24:
			# Đèn lồng
			for k in 3:
				var l := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.14
				sp.height = 0.3
				l.mesh = sp
				l.material_override = _mat("#e53935", true)
				l.position = Vector3(-0.5 + k * 0.5, 0.6, -0.55)
				root.add_child(l)
		36:
			# Đoàn tàu
			for k in 3:
				var car := _box(Vector3(0.5, 0.25, 0.28), "#1565c0" if k == 0 else "#90a4ae")
				car.position = Vector3(-0.6 + k * 0.55, 0.25, -0.55)
				root.add_child(car)


func _build_center() -> void:
	var title := _flat_label("TỶ PHÚ ĐẤT VIỆT", 110, 12.0, 0.011)
	title.position = Vector3(0, 0.12, -3.0)
	title.modulate = Color("#b71c1c")
	title.outline_size = 18
	title.outline_modulate = Color("#fff8e1")
	add_child(title)
	season_label = _flat_label("", 64, 12.0, 0.01)
	season_label.position = Vector3(0, 0.12, -1.6)
	season_label.modulate = Color("#1b5e20")
	season_label.outline_size = 12
	season_label.outline_modulate = Color("#ffffff")
	add_child(season_label)
	season_event_label = _flat_label("", 48, 12.0, 0.009)
	season_event_label.position = Vector3(0, 0.12, -0.7)
	season_event_label.modulate = Color("#bf360c")
	season_event_label.outline_size = 10
	season_event_label.outline_modulate = Color("#ffffff")
	add_child(season_event_label)
	# Cây trang trí
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.2, 5.4)
		var p := Vector3(cos(a) * r, 0.08, sin(a) * r)
		if absf(p.z) < 1.2 and absf(p.x) < 5.5:
			continue
		add_child(_tree(p, rng.randf_range(0.7, 1.2)))


func _tree(p: Vector3, s: float) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.scale = Vector3.ONE * s
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.05
	tm.bottom_radius = 0.07
	tm.height = 0.3
	trunk.mesh = tm
	trunk.position.y = 0.15
	trunk.material_override = _mat("#795548")
	n.add_child(trunk)
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.3
	cm.height = 0.6
	cm.radial_segments = 7
	crown.mesh = cm
	crown.position.y = 0.55
	crown.material_override = _mat("#2e7d32")
	n.add_child(crown)
	return n


# ---------------------------------------------------------------- cập nhật trạng thái

func set_tile_state(t: int, owner_id: int, lvl: int) -> void:
	var strip: MeshInstance3D = owner_strips[t]
	strip.visible = owner_id >= 0
	if owner_id >= 0:
		strip.material_override = _mat(player_colors[owner_id])
	var broot: Node3D = building_roots[t]
	for c in broot.get_children():
		c.queue_free()
	if owner_id < 0 or lvl <= 0:
		return
	var col: String = player_colors[owner_id]
	var w: float = W - 0.15
	match lvl:
		1:
			broot.add_child(_house(Vector3(0, 0, 0), 0.26, 0.2, col))
		2:
			broot.add_child(_house(Vector3(-w / 4, 0, 0), 0.24, 0.24, col))
			broot.add_child(_house(Vector3(w / 4, 0, 0), 0.24, 0.32, col))
		3:
			var hotel := _box(Vector3(w * 0.8, 0.6, 0.32), col)
			hotel.position.y = 0.3
			broot.add_child(hotel)
			var roof := _box(Vector3(w * 0.85, 0.06, 0.36), "#37474f")
			roof.position.y = 0.63
			broot.add_child(roof)
		4:
			broot.add_child(_landmark(col))
	var tw := create_tween()
	broot.scale = Vector3(1, 0.05, 1)
	tw.tween_property(broot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_info(engine: GameEngine) -> void:
	for t in BoardData.TILE_COUNT:
		if not BoardData.is_property(t):
			continue
		var lbl: Label3D = info_labels[t]
		if engine.owner[t] >= 0:
			lbl.text = "Thuê " + BoardData.money(engine.rent(t))
			lbl.modulate = Color("#b71c1c")
		else:
			lbl.text = BoardData.money(BoardData.tile(t)["price"])
			lbl.modulate = Color("#5d4037")


func set_festival(t: int) -> void:
	festival_marker.visible = t >= 0
	if t >= 0:
		festival_marker.position = tile_center(t) + Vector3(0, 0.0, 0)


func set_season(s: int, ev: Dictionary) -> void:
	season_label.text = "Mùa " + GameEngine.SEASON_NAMES[s]
	season_event_label.text = String(ev.get("name", ""))
	var tw := create_tween()
	var mat: StandardMaterial3D = center_ground.material_override
	tw.tween_property(mat, "albedo_color", Color(SEASON_GROUND[s]), 1.0)


func highlight(tiles: Array) -> void:
	for i in BoardData.TILE_COUNT:
		highlight_nodes[i].visible = tiles.has(i)


# ---------------------------------------------------------------- tiện ích hình khối

func _house(p: Vector3, size: float, h: float, col: String) -> Node3D:
	var n := Node3D.new()
	n.position = p
	var body := _box(Vector3(size, h, size), col)
	body.position.y = h / 2
	n.add_child(body)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size * 1.2, size * 0.6, size * 1.1)
	roof.mesh = pm
	roof.position.y = h + size * 0.3
	roof.material_override = _mat("#c62828")
	n.add_child(roof)
	return n


func _landmark(col: String) -> Node3D:
	var n := Node3D.new()
	var widths := [0.9, 0.7, 0.5]
	var y := 0.0
	for k in 3:
		var tier := _box(Vector3(widths[k], 0.18, 0.34 - k * 0.06), "#ffca28" if k % 2 == 0 else col, k % 2 == 0)
		tier.position.y = y + 0.09
		n.add_child(tier)
		y += 0.2
	var spire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.14
	cm.height = 0.4
	spire.mesh = cm
	spire.position.y = y + 0.2
	spire.material_override = _mat("#ffd54f", true)
	n.add_child(spire)
	return n


func _make_festival_marker() -> Node3D:
	var n := Node3D.new()
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.025
	pm.height = 1.6
	pole.mesh = pm
	pole.position.y = 0.8
	pole.material_override = _mat("#5d4037")
	n.add_child(pole)
	var flag := _box(Vector3(0.5, 0.32, 0.03), "#e53935", true)
	flag.position = Vector3(0.27, 1.42, 0)
	n.add_child(flag)
	var star := Label3D.new()
	star.text = "★"
	star.font_size = 48
	star.pixel_size = 0.005
	star.modulate = Color("#ffeb3b")
	star.position = Vector3(0.27, 1.42, 0.02)
	n.add_child(star)
	var lbl := Label3D.new()
	lbl.text = "LỄ HỘI"
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 10
	lbl.modulate = Color("#e53935")
	lbl.position.y = 1.85
	n.add_child(lbl)
	return n


func _box(size: Vector3, col: String, glow: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(col, glow)
	return m


func _flat_label(text: String, font_size: int, width: float, px: float = 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = px
	l.width = width / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.rotation.x = -PI / 2
	l.modulate = Color("#212121")
	l.outline_size = 0
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return l


func _mat(col: String, glow: bool = false) -> StandardMaterial3D:
	var key := col + ("g" if glow else "")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col)
	m.roughness = 0.85
	if glow:
		m.emission_enabled = true
		m.emission = Color(col)
		m.emission_energy_multiplier = 0.4
	_mat_cache[key] = m
	return m
