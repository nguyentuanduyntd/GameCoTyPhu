class_name RollButton
extends Control
## Nút "TUNG" hình tròn lớn, vẽ bằng code: viền vàng ánh kim nổi khối, lòng nút màu người chơi, bóng loáng,
## biểu tượng hai viên xúc xắc 3D, quầng sáng nhịp nhẹ. Rê chuột → phóng to, sáng hơn; nhấn → lún xuống,
## loé sáng và vòng sóng lan toả; nhấn xong tự khoá để không tung 2 lần trong 1 lượt.

signal pressed

const R := 70.0
const GOLD := Color("#ffca28")
const GOLD_DARK := Color("#a0700a")

enum State { ACTIVE, WAITING, BUSY }

var state: int = State.WAITING
var base_color := Color("#e53935")
var _hover := false
var _down := false
var _hover_k := 0.0
var _press_k := 0.0
var _flash := 0.0
var _t := 0.0
var _ripple := 1.0
var _consumed := false


func _ready() -> void:
	custom_minimum_size = Vector2(R * 2 + 70, R * 2 + 70)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func():
		_hover = false
		_down = false)


func activate(col: Color) -> void:
	base_color = col
	state = State.ACTIVE
	_consumed = false
	_down = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func set_waiting() -> void:
	state = State.WAITING
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func set_busy() -> void:
	state = State.BUSY
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func is_ready() -> bool:
	return state == State.ACTIVE and not _consumed


## Dùng cho kiểm thử tự động.
func press() -> void:
	if is_ready():
		_fire()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= R + 8.0


func _gui_input(ev: InputEvent) -> void:
	if not is_ready():
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			accept_event()
		elif _down:
			_down = false
			accept_event()
			if _has_point((ev as InputEventMouseButton).position):
				_fire()


func _fire() -> void:
	_consumed = true
	_ripple = 0.0
	_flash = 1.0
	Audio.play("click")
	pressed.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var active := is_ready()
	_hover_k = lerpf(_hover_k, 1.0 if (_hover and active) else 0.0, 1.0 - exp(-12.0 * delta))
	_press_k = lerpf(_press_k, 1.0 if (_down and active) else 0.0, 1.0 - exp(-20.0 * delta))
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _ripple < 1.0:
		_ripple = minf(1.0, _ripple + delta * 1.6)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var active := is_ready()
	var pulse := (sin(_t * 3.2) * 0.5 + 0.5) if active else 0.0
	var s := 1.0 + pulse * 0.025 + _hover_k * 0.08 - _press_k * 0.08
	var fill := base_color if state == State.ACTIVE else Color("#7d7d7d")
	var gold := GOLD if state == State.ACTIVE else Color("#bdbdbd")
	var gold_dark := GOLD_DARK if state == State.ACTIVE else Color("#5f5f5f")
	draw_set_transform(c, 0.0, Vector2(s, s))

	# Quầng sáng
	if active or _flash > 0.0:
		var glow := 0.16 + pulse * 0.1 + _hover_k * 0.18 + _flash * 0.5
		for k in 4:
			draw_circle(Vector2.ZERO, R + 10.0 + k * 7.0, Color(1.0, 0.82, 0.25, glow * (0.55 - k * 0.12)))
	# Bóng đổ
	draw_circle(Vector2(0, 9.0 - _press_k * 6.0), R + 6.0, Color(0, 0, 0, 0.38))
	# Viền vàng nổi khối
	draw_circle(Vector2(0, 3), R + 6.0, gold_dark)
	draw_circle(Vector2.ZERO, R + 5.0, gold)
	draw_circle(Vector2(0, -2), R + 1.0, gold.lightened(0.35))
	draw_circle(Vector2.ZERO, R - 1.0, gold)
	# Lòng nút: mặt dưới tối, mặt trên sáng → cảm giác vòm
	draw_circle(Vector2(0, 4.0 - _press_k * 3.0), R - 7.0, fill.darkened(0.35))
	draw_circle(Vector2(0, -1.0 + _press_k * 2.0), R - 10.0, fill.lightened(0.08 + _hover_k * 0.12))
	# Vệt bóng loáng phía trên
	_ellipse(Vector2(0, -R * 0.5), Vector2(R * 0.62, R * 0.24), Color(1, 1, 1, 0.28 + _hover_k * 0.1))
	# Hai viên xúc xắc 3D
	_die(Vector2(-19, -12), -0.28, 5, active)
	_die(Vector2(21, -18), 0.22, 3, active)
	# Chữ
	var font := ThemeDB.fallback_font
	var txt := "TUNG" if state == State.ACTIVE else ("CHỜ" if state == State.WAITING else "ĐANG ĐI")
	var fs := 30 if state == State.ACTIVE else 22
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var tp := Vector2(-ts.x / 2.0, 42.0)
	draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.25, 0.08, 0.0, 0.85))
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff8e1"))
	# Loé sáng khi nhấn
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, R - 8.0, Color(1, 1, 0.85, _flash * 0.45))
	# Vòng sóng lan toả
	if _ripple < 1.0:
		var e := 1.0 - pow(1.0 - _ripple, 3.0)
		var a := 1.0 - _ripple
		draw_arc(Vector2.ZERO, R + 6.0 + e * 80.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.3, a), 8.0 * a + 1.0, true)
		draw_arc(Vector2.ZERO, R + e * 50.0, 0.0, TAU, 64, Color(1, 1, 1, a * 0.8), 4.0 * a + 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _die(at: Vector2, ang: float, value: int, active: bool) -> void:
	var h := 17.0
	var face := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var depth := Vector2(6, 6)
	var rot := Transform2D(ang, at)
	# Mặt bên (tạo khối 3D)
	var side := PackedVector2Array([face[1], face[1] + depth, face[2] + depth, face[3] + depth, face[3], face[2]])
	draw_colored_polygon(rot * side, Color("#bdbdbd") if active else Color("#8a8a8a"))
	draw_colored_polygon(rot * face, Color("#fffdf7") if active else Color("#d6d6d6"))
	draw_polyline(rot * PackedVector2Array([face[0], face[1], face[2], face[3], face[0]]), Color(0, 0, 0, 0.25), 1.5, true)
	var pips := {3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)], 5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]}
	for p in pips[value]:
		var col := Color("#d32f2f") if (value == 5 and p == Vector2(0, 0)) else Color("#212121")
		draw_circle(rot * (p * 9.0), 3.4, col)


func _ellipse(center: Vector2, radius: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, col)
