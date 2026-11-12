class_name UiIcons
extends RefCounted
## Bộ icon 64×64 vẽ bằng code, có viền tối để nổi trên mọi nền. Dùng: UiIcons.get_icon("coin").
## Tên: coin, house, land, specialty, fund, spring, summer, autumn, winter, clock, turn, speed, camera,
##      gear, menu, log, dice, star, alert, gavel, card, jail

const S := 64
static var _cache := {}


static func get_icon(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var p := UiPalette.get_default()
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(32, 32)
	var dark := p.wood_dark
	match name:
		"coin":
			_disc(img, c, 25, dark)
			_disc(img, c, 22, Color("#e0a106"))
			_disc(img, c - Vector2(1, 2), 18, p.gold)
			_rect(img, Rect2(26, 26, 12, 12), Color("#b07a00"))
			_rect(img, Rect2(28, 28, 8, 8), Color(0, 0, 0, 0), true)
		"house":
			_tri(img, Vector2(6, 32), Vector2(58, 32), Vector2(32, 8), dark)
			_tri(img, Vector2(11, 30), Vector2(53, 30), Vector2(32, 12), p.primary)
			_rect(img, Rect2(13, 30, 38, 26), dark)
			_rect(img, Rect2(16, 31, 32, 22), p.paper)
			_rect(img, Rect2(27, 38, 10, 15), p.wood)
		"land":
			_rect(img, Rect2(14, 8, 5, 50), dark)
			_tri(img, Vector2(19, 10), Vector2(19, 34), Vector2(54, 22), dark)
			_tri(img, Vector2(21, 13), Vector2(21, 31), Vector2(48, 22), p.primary)
			_disc(img, Vector2(16, 56), 6, dark)
		"specialty":
			_disc(img, Vector2(32, 40), 22, dark)
			_disc(img, Vector2(32, 40), 19, Color("#d7a86e"))
			_rect(img, Rect2(10, 20, 44, 18), Color(0, 0, 0, 0), true)
			_disc(img, Vector2(24, 26), 8, Color("#e53935"))
			_disc(img, Vector2(38, 25), 8, Color("#fdd835"))
			_disc(img, Vector2(31, 18), 7, Color("#43a047"))
			_rect(img, Rect2(10, 32, 44, 4), dark)
		"fund":
			_disc(img, Vector2(32, 38), 22, dark)
			_disc(img, Vector2(32, 38), 19, Color("#8d6e63"))
			_rect(img, Rect2(20, 10, 24, 12), dark)
			_rect(img, Rect2(23, 12, 18, 9), Color("#a1887f"))
			_disc(img, Vector2(32, 40), 9, p.gold)
		"spring":
			for k in 5:
				var a := TAU * k / 5.0 - PI / 2
				_disc(img, c + Vector2(cos(a), sin(a)) * 14, 11, dark)
			for k in 5:
				var a := TAU * k / 5.0 - PI / 2
				_disc(img, c + Vector2(cos(a), sin(a)) * 14, 9, Color("#ffd54f"))
			_disc(img, c, 7, Color("#e65100"))
		"summer":
			for k in 8:
				var a := TAU * k / 8.0
				_line(img, c + Vector2(cos(a), sin(a)) * 18, c + Vector2(cos(a), sin(a)) * 28, 5, dark)
				_line(img, c + Vector2(cos(a), sin(a)) * 19, c + Vector2(cos(a), sin(a)) * 27, 3, Color("#ffb300"))
			_disc(img, c, 16, dark)
			_disc(img, c, 13, Color("#ffca28"))
		"autumn":
			_ellipse(img, c, 24, 14, -0.7, dark)
			_ellipse(img, c, 21, 11, -0.7, Color("#e67e22"))
			_line(img, Vector2(14, 50), Vector2(48, 14), 2, dark)
		"winter":
			for o in [Vector2(-12, 2), Vector2(0, -8), Vector2(12, 2), Vector2(0, 6)]:
				_disc(img, c + o, 14, dark)
			for o in [Vector2(-12, 2), Vector2(0, -8), Vector2(12, 2), Vector2(0, 6)]:
				_disc(img, c + o, 11, Color("#cfd8dc"))
			for x in [20, 32, 44]:
				_line(img, Vector2(x, 46), Vector2(x - 4, 58), 3, Color("#4fc3f7"))
		"clock":
			_disc(img, c, 26, dark)
			_disc(img, c, 22, p.paper)
			_line(img, c, c + Vector2(0, -15), 4, dark)
			_line(img, c, c + Vector2(11, 4), 4, p.primary)
		"turn":
			_disc(img, c, 26, dark)
			_disc(img, c, 22, p.jade)
			_tri(img, Vector2(24, 18), Vector2(24, 46), Vector2(46, 32), p.paper)
		"speed":
			_tri(img, Vector2(8, 14), Vector2(8, 50), Vector2(34, 32), dark)
			_tri(img, Vector2(30, 14), Vector2(30, 50), Vector2(56, 32), dark)
			_tri(img, Vector2(11, 20), Vector2(11, 44), Vector2(29, 32), p.paper)
			_tri(img, Vector2(33, 20), Vector2(33, 44), Vector2(51, 32), p.paper)
		"camera":
			_rect(img, Rect2(6, 18, 52, 34), dark)
			_rect(img, Rect2(9, 21, 46, 28), p.paper)
			_rect(img, Rect2(20, 12, 16, 8), dark)
			_disc(img, Vector2(32, 35), 11, dark)
			_disc(img, Vector2(32, 35), 7, p.jade)
		"gear":
			for k in 8:
				var a := TAU * k / 8.0
				_disc(img, c + Vector2(cos(a), sin(a)) * 21, 7, dark)
			_disc(img, c, 22, dark)
			for k in 8:
				var a := TAU * k / 8.0
				_disc(img, c + Vector2(cos(a), sin(a)) * 21, 4.5, p.paper)
			_disc(img, c, 19, p.paper)
			_disc(img, c, 8, dark)
		"menu":
			for y in [16, 30, 44]:
				_rect(img, Rect2(10, y, 44, 8), dark)
				_rect(img, Rect2(12, y + 2, 40, 4), p.paper)
		"log":
			_rect(img, Rect2(12, 8, 40, 48), dark)
			_rect(img, Rect2(15, 11, 34, 42), p.paper)
			for y in [20, 29, 38]:
				_rect(img, Rect2(20, y, 24, 3), p.ink_soft)
		"dice":
			_rect(img, Rect2(10, 10, 44, 44), dark)
			_rect(img, Rect2(13, 13, 38, 38), Color.WHITE)
			for o in [Vector2(22, 22), Vector2(42, 42), Vector2(32, 32)]:
				_disc(img, o, 5, p.primary if o == Vector2(32, 32) else p.ink)
		"star":
			_star(img, c, 28, 5, 0.45, dark)
			_star(img, c, 23, 5, 0.45, p.gold)
		"alert":
			_tri(img, Vector2(32, 6), Vector2(4, 56), Vector2(60, 56), dark)
			_tri(img, Vector2(32, 13), Vector2(10, 52), Vector2(54, 52), p.gold)
			_rect(img, Rect2(29, 24, 6, 16), dark)
			_disc(img, Vector2(32, 46), 3.5, dark)
		"gavel":
			_line(img, Vector2(14, 50), Vector2(40, 24), 7, dark)
			_line(img, Vector2(16, 48), Vector2(38, 26), 4, p.wood_light)
			_line(img, Vector2(30, 14), Vector2(52, 36), 14, dark)
			_line(img, Vector2(31, 16), Vector2(50, 35), 9, p.wood)
			_rect(img, Rect2(6, 54, 30, 6), dark)
		"card":
			_rect(img, Rect2(14, 6, 36, 52), dark)
			_rect(img, Rect2(17, 9, 30, 46), p.primary)
			_star(img, c, 11, 8, 0.4, p.gold)
		"jail":
			_rect(img, Rect2(6, 26, 52, 22), dark)
			_rect(img, Rect2(9, 29, 46, 16), Color("#e53935"))
			_rect(img, Rect2(16, 16, 30, 14), dark)
			_rect(img, Rect2(19, 19, 24, 10), Color("#bbdefb"))
			_disc(img, Vector2(18, 50), 7, dark)
			_disc(img, Vector2(46, 50), 7, dark)
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


static func season_icon(s: int) -> Texture2D:
	return get_icon(["spring", "summer", "autumn", "winter"][clampi(s, 0, 3)])


# ---------------------------------------------------------------- nét vẽ

static func _put(img: Image, x: int, y: int, col: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= S or y >= S or a <= 0.0:
		return
	img.set_pixel(x, y, img.get_pixel(x, y).blend(Color(col, col.a * a)))


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			_put(img, x, y, col, clampf(r - Vector2(x + 0.5, y + 0.5).distance_to(c) + 0.5, 0.0, 1.0))


static func _rect(img: Image, r: Rect2, col: Color, clear: bool = false) -> void:
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if x >= 0 and y >= 0 and x < S and y < S:
				if clear:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	for y in range(int(minf(a.y, minf(b.y, c.y))), int(maxf(a.y, maxf(b.y, c.y))) + 1):
		for x in range(int(minf(a.x, minf(b.x, c.x))), int(maxf(a.x, maxf(b.x, c.x))) + 1):
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				_put(img, x, y, col, 1.0)


static func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		_disc(img, a.lerp(b, float(i) / n), w / 2.0, col)


static func _ellipse(img: Image, c: Vector2, rx: float, ry: float, ang: float, col: Color) -> void:
	var r := maxf(rx, ry)
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			var v := (Vector2(x + 0.5, y + 0.5) - c).rotated(-ang)
			if (v.x * v.x) / (rx * rx) + (v.y * v.y) / (ry * ry) <= 1.0:
				_put(img, x, y, col, 1.0)


static func _star(img: Image, c: Vector2, r: float, points: int, inner: float, col: Color) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			var v := Vector2(x + 0.5, y + 0.5) - c
			var t := fposmod(atan2(v.y, v.x) + PI / 2, TAU / points) / (TAU / points)
			var limit := r * (inner + (1.0 - inner) * pow(absf(t - 0.5) * 2.0, 2.0))
			_put(img, x, y, col, clampf(limit - v.length() + 0.5, 0.0, 1.0))
