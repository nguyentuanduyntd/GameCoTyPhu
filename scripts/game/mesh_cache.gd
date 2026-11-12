class_name MeshCache
extends RefCounted
## Bộ đệm mesh và material dùng chung cho mọi công trình/danh thắng:
## cùng kích thước → cùng một Mesh, cùng màu → cùng một Material. Tránh tạo mới liên tục khi xây/nâng cấp.

static var _meshes := {}
static var _mats := {}


static func box(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func prism(size: Vector3) -> PrismMesh:
	var key := "p%s" % size
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, seg: int = 12) -> CylinderMesh:
	var key := "c%.3f|%.3f|%.3f|%d" % [top, bottom, h, seg]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func sphere(r: float, seg: int = 12) -> SphereMesh:
	var key := "s%.3f|%d" % [r, seg]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		_meshes[key] = m
	return _meshes[key]


static func capsule(r: float, h: float) -> CapsuleMesh:
	var key := "k%.3f|%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 8
		m.rings = 3
		_meshes[key] = m
	return _meshes[key]


static func mat(col: Color, glow: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [col.to_html(), glow, alpha]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col, alpha)
		m.roughness = 0.75
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 0.4
		_mats[key] = m
	return _mats[key]


## Tạo MeshInstance3D với mesh + material dùng chung.
static func mi(mesh: Mesh, col: Variant, pos: Vector3 = Vector3.ZERO, glow: bool = false, alpha: float = 1.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat(col if col is Color else Color(col), glow, alpha)
	n.position = pos
	return n


static func stats() -> String:
	return "%d mesh, %d material" % [_meshes.size(), _mats.size()]
