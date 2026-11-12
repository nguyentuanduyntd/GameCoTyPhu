class_name BoardView
extends Node3D
## Dựng bàn cờ 3D bằng code (low-poly), hiển thị chủ sở hữu, nhà, lễ hội, mùa.

const W := 1.2   # bề ngang ô cạnh
const C := 2.0   # cạnh ô góc
const D := 2.0   # chiều sâu ô cạnh
const TILE_Y := 0.1
const H := (2.0 * C + 12.0 * W) / 2.0

const CORNER_COLORS := {0: "#ffe082", 13: "#ef9a9a", 26: "#f48fb1", 39: "#90caf9"}
const SEASON_GROUND := ["#9ccc65", "#7cb342", "#c0ca33", "#90a4ae"]

var tile_xforms: Array = []
var tile_sizes: Array = []
var building_roots: Array = []
var owner_strips: Array = []
var info_labels: Array = []
var highlight_nodes: Array = []
var festival_marker: Node3D
var center_ground: MeshInstance3D
var map: VietnamMap
var season_label: Label3D
var season_event_label: Label3D
var pot_label: Label3D
var player_colors: Array = []
var _mat_cache := {}

## Phát ra khi công trình mọc xong chạm đất (để rung camera, phát tiếng búa).
signal building_landed(tile: int, strength: float)
## Hệ số tốc độ game (x1/x2/x4) — mọi hoạt ảnh xây dựng chia theo hệ số này.
var anim_speed := 1.0
## Hàm trả về loại công trình của ô (Phase 3 gắn vào engine); mặc định "generic".
var kind_of: Callable = func(_t: int) -> String: return "generic"
var flag_roots: Array = []
var _shown_owner: Array = []
var _shown_level: Array = []
var _shown_kind: Array = []
var _dust: Array = []
var _dust_i := 0
var _t := 0.0


func build(colors: Array) -> void:
	player_colors = colors
	_build_base()
	for i in BoardData.TILE_COUNT:
		_build_tile(i)
	_build_center()
	for i in BoardData.TILE_COUNT:
		_shown_owner.append(-1)
		_shown_level.append(0)
		_shown_kind.append("")
	for k in 3:
		var d := _make_dust()
		add_child(d)
		_dust.append(d)
	festival_marker = _make_festival_marker()
	festival_marker.visible = false
	add_child(festival_marker)


# ---------------------------------------------------------------- vị trí

func tile_transform(i: int) -> Transform3D:
	var side: int = i / BoardData.SIDE
	var k: int = i % BoardData.SIDE
	var pos := Vector3.ZERO
	var yaw := 0.0
	match side:
		0:
			pos = Vector3(H - C / 2, 0, H - C / 2) if k == 0 else Vector3(H - C - W * (k - 0.5), 0, H - D / 2)
		1:
			pos = Vector3(-H + C / 2, 0, H - C / 2) if k == 0 else Vector3(-H + D / 2, 0, H - C - W * (k - 0.5))
			yaw = -PI / 2
		2:
			pos = Vector3(-H + C / 2, 0, -H + C / 2) if k == 0 else Vector3(-H + C + W * (k - 0.5), 0, -H + D / 2)
			yaw = PI
		_:
			pos = Vector3(H - C / 2, 0, -H + C / 2) if k == 0 else Vector3(H - D / 2, 0, -H + C + W * (k - 0.5))
			yaw = PI / 2
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func is_corner(i: int) -> bool:
	return i % BoardData.SIDE == 0


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
	gm.albedo_color = Color("#4fa3d9")
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
	elif ty == BoardData.T.CO_HOI:
		face_color = "#fff3c4"
	elif ty == BoardData.T.KHI_VAN:
		face_color = "#d6ecff"
	elif ty == BoardData.T.TOLL:
		face_color = "#ffe0b2"
	elif ty == BoardData.T.CHARITY:
		face_color = "#ffd6dc"
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
	elif ty == BoardData.T.CO_HOI or ty == BoardData.T.KHI_VAN:
		info.text = "?" if ty == BoardData.T.CO_HOI else "!"
		info.font_size = 70
		info.position.z = 0.45
		info.modulate = Color("#e65100") if ty == BoardData.T.CO_HOI else Color("#1565c0")
	elif ty == BoardData.T.CHARITY:
		info.text = "Quỹ: 0"
		pot_label = info
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

	# Chỗ cắm cờ chủ sở hữu (góc ngoài bên trái của ô)
	var froot := Node3D.new()
	froot.position = Vector3(-size.x / 2 + 0.1, 0.1, size.y / 2 - 0.15) if not corner else Vector3(-0.7, 0.1, 0.7)
	root.add_child(froot)
	flag_roots.append(froot)

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
	elif ty == BoardData.T.TOLL:
		var post := _box(Vector3(0.12, 0.35, 0.12), "#424242")
		post.position = Vector3(-0.42, 0.27, -0.55)
		root.add_child(post)
		for k in 4:
			var seg := _box(Vector3(0.2, 0.06, 0.06), "#e53935" if k % 2 == 0 else "#fafafa")
			seg.position = Vector3(-0.28 + k * 0.2, 0.4, -0.55)
			root.add_child(seg)
	elif ty == BoardData.T.CHARITY:
		var jar := MeshInstance3D.new()
		var jm := CylinderMesh.new()
		jm.top_radius = 0.16
		jm.bottom_radius = 0.22
		jm.height = 0.38
		jar.mesh = jm
		jar.position = Vector3(0, 0.3, -0.55)
		jar.material_override = _mat("#8d6e63")
		root.add_child(jar)
		var coin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.14
		cm.bottom_radius = 0.14
		cm.height = 0.05
		coin.mesh = cm
		coin.position = Vector3(0, 0.52, -0.55)
		coin.material_override = _mat("#ffca28", true)
		root.add_child(coin)


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
		13:
			# Mấy chiếc xe kẹt cứng
			var cols := ["#1e88e5", "#fdd835", "#43a047", "#8e24aa"]
			for k in 4:
				var car := _box(Vector3(0.22, 0.14, 0.42), cols[k])
				car.position = Vector3(-0.6 + k * 0.4, 0.2, -0.55 + (k % 2) * 0.15)
				root.add_child(car)
		26:
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
		39:
			# Đoàn tàu
			for k in 3:
				var car := _box(Vector3(0.5, 0.25, 0.28), "#1565c0" if k == 0 else "#90a4ae")
				car.position = Vector3(-0.6 + k * 0.55, 0.25, -0.55)
				root.add_child(car)


func _build_center() -> void:
	map = VietnamMap.new()
	add_child(map)
	map.build(player_colors)
	var title := _flat_label("TỶ PHÚ
ĐẤT VIỆT", 110, 5.5, 0.009)
	title.position = Vector3(4.4, 0.12, -5.0)
	title.modulate = Color("#b71c1c")
	title.outline_size = 18
	title.outline_modulate = Color("#fff8e1")
	add_child(title)
	season_label = _flat_label("", 64, 5.5, 0.008)
	season_label.position = Vector3(4.4, 0.12, -3.4)
	season_label.modulate = Color("#ffffff")
	season_label.outline_size = 14
	season_label.outline_modulate = Color("#1b5e20")
	add_child(season_label)
	season_event_label = _flat_label("", 48, 5.5, 0.008)
	season_event_label.position = Vector3(4.4, 0.12, -2.6)
	season_event_label.modulate = Color("#fff59d")
	season_event_label.outline_size = 12
	season_event_label.outline_modulate = Color("#bf360c")
	add_child(season_event_label)


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

## Cập nhật hình ảnh ô: cờ chủ sở hữu + công trình theo loại và cấp.
## animate = false khi dựng lại trạng thái (tải ván, trưng bày) — không có hoạt ảnh.
func set_tile_state(t: int, owner_id: int, lvl: int, animate: bool = true) -> void:
	var province := BoardData.is_province(t)
	var kind := String(kind_of.call(t)) if province else ""
	var prev_owner: int = _shown_owner[t]
	var prev_level: int = _shown_level[t]
	var prev_kind: String = _shown_kind[t]
	_shown_owner[t] = owner_id
	_shown_level[t] = lvl
	_shown_kind[t] = kind
	if province:
		map.set_province_owner(t, owner_id, lvl)
	var strip: MeshInstance3D = owner_strips[t]
	strip.visible = owner_id >= 0
	if owner_id >= 0:
		strip.material_override = MeshCache.mat(Color(player_colors[owner_id]))
	_update_flag(t, owner_id, prev_owner, animate)
	if owner_id == prev_owner and lvl == prev_level and kind == prev_kind:
		return
	var broot: Node3D = building_roots[t]
	var old: Array = broot.get_children()
	var node: Node3D = null
	if owner_id >= 0:
		var col := Color(player_colors[owner_id])
		if not province:
			if BoardData.is_property(t):
				node = BuildingBuilder.infra(BoardData.plain_name(t), col)
		elif lvl > 0:
			node = BuildingBuilder.build(kind, lvl, col, t)
	if not animate:
		for c in old:
			c.queue_free()
		if node:
			broot.add_child(node)
		return
	if old.is_empty() and node == null:
		return
	var sp := maxf(anim_speed, 0.25)
	var tw := create_tween()
	if old.size() > 0:
		tw.set_parallel(true)
		for c in old:
			tw.tween_property(c, "scale", Vector3.ZERO, 0.16 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(_free_nodes.bind(old))
	if node:
		broot.add_child(node)
		node.scale = Vector3.ZERO
		# mua mới / đổi chủ: hiệu ứng mạnh; nâng cấp: vừa; bị hạ cấp: nhẹ
		var strength := 1.0
		if owner_id == prev_owner and prev_level > 0:
			strength = 0.6 if lvl > prev_level else 0.25
		tw.chain().tween_property(node, "scale", Vector3(1.12, 1.28, 1.12), 0.24 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(node, "scale", Vector3(0.96, 0.92, 0.96), 0.07 / sp)
		tw.chain().tween_callback(_land_fx.bind(t, strength))
		tw.chain().tween_property(node, "scale", Vector3.ONE, 0.1 / sp)


## Dựng lại toàn bộ bàn cờ từ trạng thái engine (dùng khi tải ván / khôi phục), không hoạt ảnh.
func rebuild_from(engine: GameEngine) -> void:
	for t in BoardData.TILE_COUNT:
		set_tile_state(t, engine.owner[t], engine.level[t], false)
	set_festival(engine.festival_tile)


func _update_flag(t: int, owner_id: int, prev_owner: int, animate: bool) -> void:
	if owner_id == prev_owner:
		return
	var froot: Node3D = flag_roots[t]
	for c in froot.get_children():
		c.queue_free()
	if owner_id < 0:
		return
	var f := BuildingBuilder.flag(Color(player_colors[owner_id]))
	froot.add_child(f)
	if animate:
		f.scale = Vector3(1, 0.01, 1)
		create_tween().tween_property(f, "scale", Vector3.ONE, 0.3 / maxf(anim_speed, 0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _free_nodes(nodes: Array) -> void:
	for c in nodes:
		if is_instance_valid(c):
			c.queue_free()


## Bụi bay khi công trình chạm đất + báo cho game rung camera, phát tiếng.
func _land_fx(t: int, strength: float) -> void:
	var d: CPUParticles3D = _dust[_dust_i]
	_dust_i = (_dust_i + 1) % _dust.size()
	d.global_position = (building_roots[t] as Node3D).global_position
	d.amount = int(lerpf(8.0, 26.0, strength))
	d.restart()
	building_landed.emit(t, strength)


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.mesh = mesh
	p.amount = 20
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, -1.2, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.85, 0.8, 0.72, 0.9), Color(0.85, 0.8, 0.72, 0.0)])
	p.color_ramp = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


func _process(delta: float) -> void:
	_t += delta
	# cờ phấp phới
	for i in flag_roots.size():
		var froot: Node3D = flag_roots[i]
		if froot.get_child_count() == 0:
			continue
		var cloth := froot.get_child(0).get_node_or_null("Cloth") as Node3D
		if cloth:
			cloth.rotation.y = sin(_t * 3.0 + i * 0.7) * 0.35


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


func set_pot(amount: int) -> void:
	if pot_label != null:
		pot_label.text = "Quỹ: " + BoardData.money(amount)


func set_festival(t: int) -> void:
	festival_marker.visible = t >= 0
	if t >= 0:
		festival_marker.position = tile_center(t) + Vector3(0, 0.0, 0)


func set_season(s: int, ev: Dictionary) -> void:
	season_label.text = "Mùa " + GameEngine.SEASON_NAMES[s]
	season_event_label.text = String(ev.get("name", ""))
	map.set_season(s)


func highlight(tiles: Array) -> void:
	for i in BoardData.TILE_COUNT:
		highlight_nodes[i].visible = tiles.has(i)


# ---------------------------------------------------------------- tiện ích hình khối




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
