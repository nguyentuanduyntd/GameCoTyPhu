class_name CameraController
extends Node3D
## Bộ điều khiển camera độc lập, có các chế độ:
##   OVERVIEW — toàn cảnh bàn cờ (mặc định), xoay/zoom tay, có thể tự xoay theo cạnh của người đang đi
##   FOLLOW   — góc nhìn thứ nhất (POV) bám sau quân cờ, nhìn về phía trước theo hướng đi, rung nhẹ theo bước
##   FOCUS    — dừng lại, zoom vào ô vừa đáp xuống
## Mọi chuyển động tính theo delta time: khi đổi chế độ, camera hoà trộn từ vị trí cũ sang mục tiêu mới bằng
## đường cong easing (sine in-out), sau đó bám mục tiêu bằng giảm chấn mũ — không giật, không phụ thuộc FPS.

enum Mode { OVERVIEW, FOLLOW, FOCUS, PUNCH }

const OVERVIEW_FOV := 42.0
const FOLLOW_FOV := 58.0
const FOCUS_FOV := 50.0

var camera: Camera3D
var board: BoardView
var mode: int = Mode.OVERVIEW

# Toàn cảnh
var yaw := 0.0
var dist := 27.0
var look_z := 1.4
var auto_side := true

# Bám quân cờ
var target: Node3D
var _fwd := Vector3.FORWARD
var _focus_tile := -1
var follow_back := 2.3
var follow_height := 1.55
var follow_ahead := 3.2

var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _blend := 1.0
var _blend_time := 0.8
var _damp := 5.0
var _shake := 0.0
var _shake_t := 0.0
var _yaw_target := 0.0
var _fov_target := OVERVIEW_FOV

# Zoom nhẹ khi mua đất ("punch"): toàn cảnh thì tiến gần ô một chút rồi lùi lại; đang điện ảnh thì chỉ thu FOV.
const PUNCH_BLEND := 0.42
var _punch_until := 0.0
var _fov_punch := 0.0


func setup(p_board: BoardView) -> void:
	board = p_board
	camera = Camera3D.new()
	camera.fov = OVERVIEW_FOV
	add_child(camera)
	_yaw_target = yaw
	var d := _desired()
	_pos = d[0]
	_look = d[1]
	_apply(Vector3.ZERO)


func _process(delta: float) -> void:
	if camera == null:
		return
	# Xoay toàn cảnh mượt về cạnh mục tiêu
	yaw = lerp_angle(yaw, _yaw_target, 1.0 - exp(-4.0 * delta))
	var d := _desired()
	var want_pos: Vector3 = d[0]
	var want_look: Vector3 = d[1]
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / _blend_time)
		var e := 0.5 - 0.5 * cos(PI * _blend)   # easing sine in-out
		_pos = _from_pos.lerp(want_pos, e)
		_look = _from_look.lerp(want_look, e)
	else:
		var k := 1.0 - exp(-_damp * delta)
		_pos = _pos.lerp(want_pos, k)
		_look = _look.lerp(want_look, k)
	if mode == Mode.PUNCH and Time.get_ticks_msec() / 1000.0 >= _punch_until:
		_switch(Mode.OVERVIEW, 0.9, OVERVIEW_FOV, 5.0)
	_fov_punch = lerpf(_fov_punch, 0.0, 1.0 - exp(-3.5 * delta))
	camera.fov = lerpf(camera.fov, _fov_target + _fov_punch, 1.0 - exp(-5.0 * delta))
	# Rung nhẹ theo nhịp bước
	var offset := Vector3.ZERO
	if _shake > 0.0005:
		_shake_t += delta
		_shake *= exp(-9.0 * delta)
		offset = Vector3(sin(_shake_t * 47.0), cos(_shake_t * 39.0), 0.0) * _shake
	_apply(offset)


# ---------------------------------------------------------------- điều khiển chế độ

## Zoom nhẹ vào ô t trong `hold` giây rồi tự trở lại. Gọi liên tục (bấm nhanh) chỉ kéo dài thời gian giữ,
## không giật. Đang ở góc nhìn điện ảnh (POV/zoom ô) thì không đổi chế độ, chỉ "nhói" FOV một chút.
func punch(t: int, hold: float) -> void:
	_punch_until = Time.get_ticks_msec() / 1000.0 + hold
	if mode == Mode.OVERVIEW:
		_focus_tile = t
		_fwd = _path_dir(t)
		_switch(Mode.PUNCH, 0.45, OVERVIEW_FOV - 3.0, 4.0)
	elif mode == Mode.PUNCH:
		_focus_tile = t
	else:
		_fov_punch = -6.0


func overview(duration: float = 1.1) -> void:
	_switch(Mode.OVERVIEW, duration, OVERVIEW_FOV, 5.0)
	target = null


## Bắt đầu bám quân cờ: chuyển cảnh điện ảnh từ toàn cảnh xuống POV.
func follow(token: Node3D, tile: int, duration: float = 0.9) -> void:
	target = token
	_fwd = _path_dir(tile)
	_switch(Mode.FOLLOW, duration, FOLLOW_FOV, 6.0)


## Cập nhật hướng nhìn khi quân cờ đi qua ô (hướng mới được làm mượt, không quay ngoắt).
func step_to(tile: int) -> void:
	if mode != Mode.FOLLOW:
		return
	_shake = maxf(_shake, 0.035)
	_shake_t = 0.0
	var d := _path_dir(tile)
	_fwd = _fwd.slerp(d, 0.55).normalized() if _fwd.dot(d) > -0.9 else d


## Zoom vào ô vừa đáp xuống.
func focus(tile: int, duration: float = 0.7) -> void:
	_focus_tile = tile
	_fwd = _path_dir(tile)
	_switch(Mode.FOCUS, duration, FOCUS_FOV, 4.0)


func impact(strength: float = 0.06) -> void:
	_shake = maxf(_shake, strength)
	_shake_t = 0.0


## Chế độ toàn cảnh: xoay về cạnh chứa ô t (để chữ đọc xuôi).
func face_side_of(t: int) -> void:
	if not auto_side:
		return
	var side: int = t / BoardData.SIDE
	_yaw_target = yaw + wrapf([0.0, -PI / 2, PI, PI / 2][side] - yaw, -PI, PI)


func orbit(dx: float) -> void:
	yaw -= dx
	_yaw_target = yaw


func zoom(factor: float) -> void:
	dist = clampf(dist * factor, 11.0, 34.0)


func set_look_z(z: float) -> void:
	look_z = z


func snap() -> void:
	var d := _desired()
	_pos = d[0]
	_look = d[1]
	_blend = 1.0
	yaw = _yaw_target
	_apply(Vector3.ZERO)


# ---------------------------------------------------------------- tính toán

func _switch(m: int, duration: float, fov: float, damp: float) -> void:
	_from_pos = _pos
	_from_look = _look
	mode = m
	_blend = 0.0 if duration > 0.01 else 1.0
	_blend_time = maxf(duration, 0.01)
	_fov_target = fov
	_damp = damp


## Trả về [vị trí camera, điểm nhìn] mong muốn của chế độ hiện tại.
func _desired() -> Array:
	match mode:
		Mode.FOLLOW:
			if target and is_instance_valid(target):
				var p := target.global_position
				var side := _fwd.cross(Vector3.UP).normalized()
				# lùi sau quân cờ, cao vừa phải, lệch nhẹ ra mép ngoài để không che các ô phía trước
				var cam := p - _fwd * follow_back + Vector3.UP * follow_height - side * 0.35
				var look := p + _fwd * follow_ahead + Vector3.UP * 0.15
				return [cam, look]
		Mode.PUNCH:
			if _focus_tile >= 0:
				var ov := _overview_desired()
				var fc := _focus_desired()
				return [(ov[0] as Vector3).lerp(fc[0], PUNCH_BLEND), (ov[1] as Vector3).lerp(fc[1], PUNCH_BLEND * 1.3)]
		Mode.FOCUS:
			if _focus_tile >= 0:
				var c := board.tile_center(_focus_tile)
				var outward := (c * Vector3(1, 0, 1)).normalized()
				var cam := c - _fwd * 1.6 + outward * 1.4 + Vector3.UP * 2.6
				return [cam, c + Vector3.UP * 0.2]
	return _overview_desired()


func _overview_desired() -> Array:
	var basis := Basis(Vector3.UP, yaw)
	var cam_local := Vector3(0, dist * 0.88, dist * 0.47 + (look_z - 1.4))
	return [basis * cam_local, basis * Vector3(0, 0, look_z)]


func _focus_desired() -> Array:
	var c := board.tile_center(_focus_tile)
	var outward := (c * Vector3(1, 0, 1)).normalized()
	return [c - _fwd * 1.6 + outward * 1.4 + Vector3.UP * 2.6, c + Vector3.UP * 0.2]


## Hướng đi của bàn cờ tại ô t (từ ô t sang ô kế tiếp).
func _path_dir(t: int) -> Vector3:
	var a := board.tile_center(t)
	var b := board.tile_center((t + 1) % BoardData.TILE_COUNT)
	var d := (b - a) * Vector3(1, 0, 1)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func _apply(offset: Vector3) -> void:
	var up := Vector3.UP
	var dir := _look - _pos
	if dir.length() < 0.01:
		return
	var basis := Basis.looking_at(dir, up)
	camera.global_transform = Transform3D(basis, _pos + basis * offset)
