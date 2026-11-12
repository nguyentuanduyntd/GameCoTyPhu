class_name BuyJuice
extends CanvasLayer
## "Game juice" cho khoảnh khắc mua đất / thắng đấu giá / xây / Danh Thắng / gom đủ vùng:
##  - xu bay theo vòng cung từ khung người chơi ra ô đất (2D, pool tái sử dụng — không tạo mới liên tục)
##  - camera zoom nhẹ vào ô rồi trả về (CameraController.punch, tôn trọng góc nhìn đang dùng)
##  - pháo giấy 3D trên ô (thắng đấu giá, Danh Thắng, gom đủ vùng)
## Mức hiệu ứng theo Cài đặt: Global.buy_fx = 0 Tắt, 1 Giảm, 2 Bật. Mọi thời lượng chia cho hệ số tốc độ.

const POOL := 14

var board: BoardView
var cam_ctl: CameraController
var hud: Hud
var speed := 1.0
var _coins: Array = []
var _next := 0
var _confetti: Array = []
var _conf_i := 0


func setup(p_board: BoardView, p_cam: CameraController, p_hud: Hud) -> void:
	board = p_board
	cam_ctl = p_cam
	hud = p_hud
	layer = 8
	for i in POOL:
		var c := CoinFx.new()
		c.visible = false
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_coins.append(c)
	for i in 2:
		var p := _make_confetti()
		board.add_child(p)
		_confetti.append(p)


func level() -> int:
	return Global.buy_fx


## Mua đất thường: keng + xu bay ra ô + zoom nhẹ.
func purchase(pid: int, t: int) -> void:
	if level() == 0:
		return
	coins_to_tile(pid, t, 10 if level() == 2 else 4)
	if level() == 2:
		cam_ctl.punch(t, 0.9 / speed)


## Xây / nâng cấp công trình: ít xu hơn, zoom ngắn.
func build(pid: int, t: int) -> void:
	if level() == 0:
		return
	coins_to_tile(pid, t, 6 if level() == 2 else 3)
	if level() == 2:
		cam_ctl.punch(t, 0.7 / speed)


## Thắng đấu giá: xu + pháo giấy + zoom.
func auction_win(pid: int, t: int) -> void:
	if level() == 0:
		return
	coins_to_tile(pid, t, 12 if level() == 2 else 5)
	if level() == 2:
		confetti(t)
		cam_ctl.punch(t, 1.1 / speed)


## Danh Thắng / gom đủ vùng: pháo giấy (cả ở mức Giảm).
func celebrate(t: int) -> void:
	if level() == 0:
		return
	confetti(t)
	if level() == 2:
		cam_ctl.punch(t, 1.0 / speed)


func coins_to_tile(pid: int, t: int, count: int) -> void:
	var cam := cam_ctl.camera
	var world := board.tile_center(t) + Vector3(0, 0.3, 0)
	if cam.is_position_behind(world):
		return
	var end := cam.unproject_position(world)
	var vp := get_viewport().get_visible_rect().size
	if end.x < -50 or end.y < -50 or end.x > vp.x + 50 or end.y > vp.y + 50:
		return
	var box: Control = hud.player_boxes[pid]["panel"]
	var r := box.get_global_rect()
	var start := r.position + Vector2(r.size.x * 0.75, r.size.y * 0.55)
	var dur := 0.55 / speed
	for k in count:
		var c: CoinFx = _coins[_next]
		_next = (_next + 1) % POOL
		c.fly(start + Vector2(randf_range(-10, 10), randf_range(-6, 6)), end + Vector2(randf_range(-14, 14), randf_range(-8, 8)), dur, k * 0.045 / speed, k == count - 1)


func confetti(t: int) -> void:
	var p: CPUParticles3D = _confetti[_conf_i]
	_conf_i = (_conf_i + 1) % _confetti.size()
	p.global_position = board.tile_center(t) + Vector3(0, 0.6, 0)
	p.amount = 60 if level() == 2 else 30
	p.speed_scale = clampf(speed, 1.0, 3.0)
	p.restart()


func _make_confetti() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.17)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = mat
	p.mesh = qm
	p.amount = 60
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 4.6
	p.gravity = Vector3(0, -4.5, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angular_velocity_min = -540
	p.angular_velocity_max = 540
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0])
	grad.colors = PackedColorArray([Color("#ff5252")])
	var cols := ["#ffd740", "#69f0ae", "#40c4ff", "#e040fb", "#ffffff"]
	for i in cols.size():
		grad.add_point(float(i + 1) / (cols.size() + 1), Color(cols[i]))
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


## Đồng xu 2D bay theo đường cong bậc hai, xoay lật, tới nơi thì loé nhẹ.
class CoinFx extends Control:
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO
	var _ctrl := Vector2.ZERO
	var _t := 0.0
	var _dur := 0.5
	var _delay := 0.0
	var _ting := false
	var _flash := 0.0

	func fly(from: Vector2, to: Vector2, dur: float, delay: float, ting: bool) -> void:
		_from = from
		_to = to
		_ctrl = (from + to) / 2.0 + Vector2(0, -minf(220.0, from.distance_to(to) * 0.45))
		_t = 0.0
		_dur = maxf(dur, 0.12)
		_delay = delay
		_ting = ting
		_flash = 0.0
		size = Vector2(28, 28)
		position = from - size / 2.0
		visible = true
		modulate.a = 0.0

	func _process(delta: float) -> void:
		if not visible:
			return
		if _delay > 0.0:
			_delay -= delta
			return
		modulate.a = 1.0
		if _t < 1.0:
			_t = minf(1.0, _t + delta / _dur)
			var e := _t * _t * (3.0 - 2.0 * _t)
			var p := _from.lerp(_ctrl, e).lerp(_ctrl.lerp(_to, e), e)
			position = p - size / 2.0
			if _t >= 1.0:
				_flash = 1.0
				if _ting:
					Audio.play("coin", 0.1, -8.0)
		else:
			_flash -= delta * 4.0
			if _flash <= 0.0:
				visible = false
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var squash := absf(cos(_t * TAU * 1.5)) * 0.7 + 0.3
		draw_set_transform(c, 0.0, Vector2(squash, 1.0))
		draw_circle(Vector2.ZERO, 12.0, Color("#b8860b"))
		draw_circle(Vector2.ZERO, 10.0, Color("#ffca28"))
		draw_rect(Rect2(-3, -3, 6, 6), Color("#b8860b"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _flash > 0.0:
			draw_circle(c, 16.0 * (1.5 - _flash * 0.5), Color(1, 0.95, 0.6, _flash * 0.6))
