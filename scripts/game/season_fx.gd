class_name SeasonFx
extends Node3D
## Hiệu ứng mùa và thời tiết: ánh sáng, sương mù, hoa rơi, lá rơi, mưa, bão, pháo hoa Tết, cúp điện.

const SUN := [
	{"color": "#fff1e6", "energy": 1.15, "sky_top": "#5b9be0", "sky_hz": "#f8d7e3", "fog": 0.0},   # Xuân
	{"color": "#fff4d6", "energy": 1.4, "sky_top": "#3d8fe0", "sky_hz": "#d6efff", "fog": 0.0},    # Hạ
	{"color": "#ffd8a8", "energy": 1.05, "sky_top": "#6d93c4", "sky_hz": "#f6dfb8", "fog": 0.0},   # Thu
	{"color": "#d7e4ff", "energy": 0.8, "sky_top": "#7d8fa3", "sky_hz": "#c9d3dc", "fog": 0.012},  # Đông
]

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var area: float = 9.0

var _petals: CPUParticles3D
var _leaves: CPUParticles3D
var _rain: CPUParticles3D
var _fireworks: Array = []
var _season := 0
var _storm := false
var _blackout := false
var _lightning_t := 0.0


func setup(p_sun: DirectionalLight3D, p_env: Environment, p_sky: ProceduralSkyMaterial, half_size: float) -> void:
	sun = p_sun
	env = p_env
	sky_mat = p_sky
	area = half_size
	_petals = _make_particles(["#ff80ab", "#ffd740", "#f50057"], Vector3(0.11, 0.11, 0.01), 140, 6.0, 0.6)
	_leaves = _make_particles(["#ff9800", "#e65100", "#ffca28", "#a1887f"], Vector3(0.12, 0.08, 0.01), 100, 5.0, 0.8)
	_rain = _make_particles(["#b3d4ff"], Vector3(0.015, 0.35, 0.015), 600, 0.9, 9.0)
	_rain.angular_velocity_max = 0.0
	_rain.angular_velocity_min = 0.0
	_rain.particle_flag_align_y = true
	for i in 3:
		var fw := _make_firework()
		add_child(fw)
		_fireworks.append(fw)


func _process(delta: float) -> void:
	if _storm and not _blackout:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(1.5, 4.0)
			var base: float = SUN[_season]["energy"] * 0.45
			var tw := create_tween()
			tw.tween_property(sun, "light_energy", 2.6, 0.05)
			tw.tween_property(sun, "light_energy", base, 0.25)


func set_season(s: int, ev: Dictionary) -> void:
	_season = s
	var cfg: Dictionary = SUN[s]
	var et: String = ev.get("type", "")
	_storm = et == "storm"
	var energy: float = cfg["energy"] * (0.45 if _storm else 1.0)
	if _blackout:
		energy *= 0.35
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "light_color", Color(cfg["color"]), 1.2)
	tw.tween_property(sun, "light_energy", energy, 1.2)
	tw.tween_property(sky_mat, "sky_top_color", Color(cfg["sky_top"]).darkened(0.35 if _storm else 0.0), 1.2)
	tw.tween_property(sky_mat, "sky_horizon_color", Color(cfg["sky_hz"]).darkened(0.3 if _storm else 0.0), 1.2)
	var fog: float = cfg["fog"] + (0.01 if _storm else 0.0)
	env.fog_enabled = fog > 0.0
	env.fog_density = fog
	env.fog_light_color = Color("#c9d3dc")
	_petals.emitting = s == 0 and not _storm
	_leaves.emitting = s == 2 and not _storm
	_rain.emitting = s == 3 or _storm
	_rain.amount = 900 if _storm else 350
	if s == 0:
		fireworks()


func set_blackout(on: bool) -> void:
	if _blackout == on:
		return
	_blackout = on
	var target: float = SUN[_season]["energy"] * (0.45 if _storm else 1.0) * (0.35 if on else 1.0)
	create_tween().tween_property(sun, "light_energy", target, 0.6)


## Pháo hoa Tết
func fireworks() -> void:
	for i in _fireworks.size():
		var fw: CPUParticles3D = _fireworks[i]
		fw.position = Vector3(randf_range(-area * 0.6, area * 0.6), randf_range(5.0, 7.0), randf_range(-area * 0.6, area * 0.2))
		fw.color = Color.from_hsv(randf(), 0.7, 1.0)
		get_tree().create_timer(i * 0.45).timeout.connect(func(): fw.restart())


func _make_particles(colors: Array, size: Vector3, amount: int, lifetime: float, fall_speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area, 0.5, area)
	p.position.y = 7.0
	p.direction = Vector3(0.2, -1, 0.1)
	p.spread = 15.0
	p.gravity = Vector3(0, -fall_speed, 0)
	p.initial_velocity_min = fall_speed * 0.3
	p.initial_velocity_max = fall_speed * 0.6
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.damping_min = fall_speed * 0.4
	p.damping_max = fall_speed * 0.6
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0])
	grad.colors = PackedColorArray([Color(colors[0])])
	for i in range(1, colors.size()):
		grad.add_point(float(i) / colors.size(), Color(colors[i]))
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = grad
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_firework() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.amount = 60
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -2.0, 0)
	p.damping_min = 1.0
	p.damping_max = 1.5
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.emitting = false
	return p
