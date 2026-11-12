class_name CardArt
extends RefCounted
## Vẽ hoạ tiết lá bài bằng code (không dùng ảnh ngoài):
##  - Lưng Khí Vận: đỏ – vàng, mặt trống đồng (ngôi sao 14 cánh, vòng hoa văn), mây cuộn ở góc.
##  - Lưng Cơ Hội: xanh lá – vàng, đồng xu lỗ vuông, bông lúa hai bên.
##  - Mặt trước, biểu tượng minh hoạ, bóng đổ mềm, tia sáng.

const W := 256
const H := 372
const RADIUS := 22

const THEME := {
	"khi_van": {"dark": "#7f0000", "main": "#d32f2f", "light": "#ff7961", "gold": "#ffca28", "pale": "#fff3e0", "title": "KHÍ VẬN"},
	"co_hoi": {"dark": "#0d4f12", "main": "#2e7d32", "light": "#66bb6a", "gold": "#ffd54f", "pale": "#f1f8e9", "title": "CƠ HỘI"},
}

static var _cache := {}


static func theme(deck: String) -> Dictionary:
	return THEME[deck]


# ---------------------------------------------------------------- lưng bài

static func back(deck: String) -> Texture2D:
	var key := "back_" + deck
	if _cache.has(key):
		return _cache[key]
	var th: Dictionary = THEME[deck]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var dark := Color(th["dark"])
	var main := Color(th["main"])
	var gold := Color(th["gold"])
	# Nền chuyển màu toả từ tâm
	for y in H:
		for x in W:
			var d := Vector2(x - W / 2.0, (y - H / 2.0) * 0.75).length() / (W * 0.6)
			img.set_pixel(x, y, main.lerp(dark, clampf(d, 0.0, 1.0)))
	# Viền vàng đôi
	_frame(img, 9, 6, gold)
	_frame(img, 21, 2, gold)
	var c := Vector2(W / 2.0, H / 2.0 - 8)
	if deck == "khi_van":
		# Mặt trống đồng
		_ring(img, c, 100, 104, gold)
		_ring(img, c, 86, 89, gold)
		for k in 28:
			var a := TAU * k / 28.0
			_disc(img, c + Vector2(cos(a), sin(a)) * 95.0, 3.0, gold)
		_ring(img, c, 66, 69, gold)
		for k in 16:
			# Chim Lạc cách điệu: các vạch chéo giữa 2 vòng
			var a := TAU * k / 16.0
			var p0 := c + Vector2(cos(a), sin(a)) * 72.0
			var p1 := c + Vector2(cos(a + 0.18), sin(a + 0.18)) * 83.0
			_line(img, p0, p1, 2.5, gold)
		_ring(img, c, 48, 50, gold)
		_star(img, c, 40.0, 14, 0.32, gold)
		_disc(img, c, 9.0, main)
		_ring(img, c, 9, 11, gold)
		# Mây cuộn ở 4 góc
		for corner in [Vector2(42, 42), Vector2(W - 42, 42), Vector2(42, H - 42), Vector2(W - 42, H - 42)]:
			_ring(img, corner, 9, 12, gold)
			_ring(img, corner + Vector2(10, 4).rotated(corner.angle_to_point(c)), 4, 6, gold)
	else:
		# Đồng xu lỗ vuông
		_disc(img, c, 82.0, gold)
		_ring(img, c, 74, 77, Color(th["dark"]))
		_ring(img, c, 82, 85, Color(th["dark"]).lerp(gold, 0.3))
		img.fill_rect(Rect2i(int(c.x) - 22, int(c.y) - 22, 44, 44), main)
		_frame_rect(img, Rect2i(int(c.x) - 26, int(c.y) - 26, 52, 52), 3, Color(th["dark"]))
		for k in 4:
			var a := PI / 4 + k * PI / 2
			_disc(img, c + Vector2(cos(a), sin(a)) * 50.0, 7.0, Color(th["dark"]))
		# Bông lúa hai bên
		for side in [-1, 1]:
			for k in 11:
				var a := deg_to_rad(110 + k * 14) if side < 0 else deg_to_rad(70 - k * 14)
				var p := c + Vector2(cos(a), sin(a)) * 112.0
				_ellipse(img, p, 4.0, 8.0, a + PI / 2, gold)
				_line(img, p, c + Vector2(cos(a), sin(a)) * 100.0, 1.5, gold)
		for corner in [Vector2(42, 42), Vector2(W - 42, 42), Vector2(42, H - 42), Vector2(W - 42, H - 42)]:
			_star(img, corner, 11.0, 4, 0.35, gold)
	_round_corners(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# ---------------------------------------------------------------- mặt trước (khung, chữ là Label3D riêng)

static func front(deck: String) -> Texture2D:
	var key := "front_" + deck
	if _cache.has(key):
		return _cache[key]
	var th: Dictionary = THEME[deck]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var pale := Color(th["pale"])
	var paper := Color("#fffdf5")
	for y in H:
		for x in W:
			var d := Vector2(x - W / 2.0, y - H / 2.0).length() / (H * 0.7)
			img.set_pixel(x, y, paper.lerp(pale, clampf(d, 0.0, 1.0)))
	var main := Color(th["main"])
	var gold := Color(th["gold"])
	_frame(img, 0, 9, main)
	_frame(img, 9, 3, gold)
	# Dải tiêu đề
	img.fill_rect(Rect2i(9, 9, W - 18, 46), main)
	img.fill_rect(Rect2i(9, 55, W - 18, 4), gold)
	# Vòng nền biểu tượng
	_disc(img, Vector2(W / 2.0, 122), 52.0, Color(gold, 0.35))
	_ring(img, Vector2(W / 2.0, 122), 50, 53, Color(gold, 0.9))
	# Dải tóm tắt hiệu ứng ở chân
	img.fill_rect(Rect2i(9, H - 64, W - 18, 55), Color(main, 0.92))
	img.fill_rect(Rect2i(9, H - 68, W - 18, 4), gold)
	# Hoa văn chấm nhỏ hai bên
	for k in 9:
		_disc(img, Vector2(20, 190 + k * 12), 2.0, Color(main, 0.5))
		_disc(img, Vector2(W - 20, 190 + k * 12), 2.0, Color(main, 0.5))
	_round_corners(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# ---------------------------------------------------------------- biểu tượng 128×128

static func icon(name: String) -> Texture2D:
	var key := "icon_" + name
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold := Color("#ffc107")
	var rim := Color("#b8860b")
	match name:
		"coins":
			for k in 3:
				var p := Vector2(44 + k * 20, 86 - k * 18)
				_disc(img, p, 26.0, rim)
				_disc(img, p, 22.0, gold)
				img.fill_rect(Rect2i(int(p.x) - 6, int(p.y) - 6, 12, 12), rim)
		"loss":
			_disc(img, Vector2(52, 58), 30.0, rim)
			_disc(img, Vector2(52, 58), 26.0, gold.darkened(0.15))
			img.fill_rect(Rect2i(45, 51, 14, 14), rim)
			img.fill_rect(Rect2i(86, 40, 14, 40), Color("#e53935"))
			_tri(img, Vector2(76, 78), Vector2(110, 78), Vector2(93, 106), Color("#e53935"))
		"arrow":
			for k in 5:
				_disc(img, Vector2(14 + k * 16, 92 - k * 6), 5.0, Color("#8d6e63"))
			img.fill_rect(Rect2i(30, 50, 56, 18), Color("#1e88e5"))
			_tri(img, Vector2(84, 34), Vector2(84, 84), Vector2(118, 59), Color("#1e88e5"))
		"star":
			_disc(img, Vector2(64, 64), 50.0, Color(1, 0.92, 0.4, 0.35))
			_star(img, Vector2(64, 64), 48.0, 8, 0.45, gold)
			_disc(img, Vector2(64, 64), 14.0, Color("#fff59d"))
		"cloud":
			var gray := Color("#78909c")
			for p in [Vector2(40, 52), Vector2(64, 40), Vector2(88, 52), Vector2(60, 60)]:
				_disc(img, p, 22.0, gray)
			_tri(img, Vector2(62, 66), Vector2(80, 66), Vector2(56, 100), Color("#ffeb3b"))
			_tri(img, Vector2(56, 84), Vector2(74, 84), Vector2(60, 122), Color("#ffeb3b"))
		"car":
			img.fill_rect(Rect2i(18, 56, 92, 30), Color("#e53935"))
			img.fill_rect(Rect2i(38, 36, 50, 24), Color("#e53935"))
			img.fill_rect(Rect2i(44, 41, 18, 16), Color("#bbdefb"))
			img.fill_rect(Rect2i(66, 41, 18, 16), Color("#bbdefb"))
			_disc(img, Vector2(40, 90), 12.0, Color("#212121"))
			_disc(img, Vector2(88, 90), 12.0, Color("#212121"))
			_disc(img, Vector2(18, 64), 6.0, Color("#ffeb3b"))
		"scroll":
			img.fill_rect(Rect2i(26, 30, 76, 70), Color("#f5deb3"))
			img.fill_rect(Rect2i(20, 24, 88, 12), Color("#a1887f"))
			img.fill_rect(Rect2i(20, 94, 88, 12), Color("#a1887f"))
			_star(img, Vector2(64, 64), 22.0, 5, 0.45, Color("#e53935"))
		"dice":
			img.fill_rect(Rect2i(22, 22, 84, 84), Color("#fafafa"))
			_frame_rect(img, Rect2i(22, 22, 84, 84), 4, Color("#9e9e9e"))
			for p in [Vector2(42, 42), Vector2(86, 42), Vector2(64, 64), Vector2(42, 86), Vector2(86, 86)]:
				_disc(img, p, 8.0, Color("#d32f2f") if p == Vector2(64, 64) else Color("#212121"))
		"house":
			img.fill_rect(Rect2i(30, 62, 68, 46), Color("#ffe0b2"))
			_tri(img, Vector2(20, 66), Vector2(108, 66), Vector2(64, 24), Color("#c62828"))
			img.fill_rect(Rect2i(56, 80, 18, 28), Color("#6d4c41"))
			img.fill_rect(Rect2i(36, 72, 14, 12), Color("#90caf9"))
			img.fill_rect(Rect2i(80, 72, 14, 12), Color("#90caf9"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Bóng đổ mềm (chữ nhật bo góc làm mờ).
static func shadow() -> Texture2D:
	if _cache.has("shadow"):
		return _cache["shadow"]
	var img := Image.create(128, 160, false, Image.FORMAT_RGBA8)
	for y in 160:
		for x in 128:
			var dx := maxf(absf(x - 64.0) - 40.0, 0.0)
			var dy := maxf(absf(y - 80.0) - 58.0, 0.0)
			var d := sqrt(dx * dx + dy * dy)
			img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d / 20.0, 0.0, 1.0) * 0.55))
	var tex := ImageTexture.create_from_image(img)
	_cache["shadow"] = tex
	return tex


## Tia sáng toả tròn (xoay phía sau lá bài khi lật).
static func rays() -> Texture2D:
	if _cache.has("rays"):
		return _cache["rays"]
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var v := Vector2(x - 128.0, y - 128.0)
			var r := v.length() / 128.0
			var a := atan2(v.y, v.x)
			var ray := pow(absf(cos(a * 8.0)), 6.0)
			var alpha := ray * clampf(1.0 - r, 0.0, 1.0) * 0.9 + clampf(0.5 - r, 0.0, 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_cache["rays"] = tex
	return tex


# ---------------------------------------------------------------- nét vẽ cơ bản

static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a > 0.0:
				_blend(img, x, y, Color(col, col.a * a))


static func _ring(img: Image, c: Vector2, r0: float, r1: float, col: Color) -> void:
	for y in range(int(c.y - r1 - 1), int(c.y + r1 + 2)):
		for x in range(int(c.x - r1 - 1), int(c.x + r1 + 2)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(minf(d - r0 + 0.5, r1 - d + 0.5), 0.0, 1.0)
			if a > 0.0:
				_blend(img, x, y, Color(col, col.a * a))


static func _ellipse(img: Image, c: Vector2, rx: float, ry: float, ang: float, col: Color) -> void:
	var r := maxf(rx, ry)
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			var v := (Vector2(x + 0.5, y + 0.5) - c).rotated(-ang)
			if (v.x * v.x) / (rx * rx) + (v.y * v.y) / (ry * ry) <= 1.0:
				_blend(img, x, y, col)


static func _star(img: Image, c: Vector2, r: float, points: int, inner: float, col: Color) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			var v := Vector2(x + 0.5, y + 0.5) - c
			var t := fposmod(atan2(v.y, v.x) + PI / 2, TAU / points) / (TAU / points)
			var tri := absf(t - 0.5) * 2.0
			var limit := r * (inner + (1.0 - inner) * pow(tri, 2.0))
			var a := clampf(limit - v.length() + 0.5, 0.0, 1.0)
			if a > 0.0:
				_blend(img, x, y, Color(col, col.a * a))


static func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		_disc(img, a.lerp(b, float(i) / n), w / 2.0, col)


static func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var minp := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var maxp := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	for y in range(int(minp.y), int(maxp.y) + 1):
		for x in range(int(minp.x), int(maxp.x) + 1):
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				_blend(img, x, y, col)


static func _frame(img: Image, inset: int, w: int, col: Color) -> void:
	_frame_rect(img, Rect2i(inset, inset, img.get_width() - inset * 2, img.get_height() - inset * 2), w, col)


static func _frame_rect(img: Image, r: Rect2i, w: int, col: Color) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, w), col)
	img.fill_rect(Rect2i(r.position.x, r.end.y - w, r.size.x, w), col)
	img.fill_rect(Rect2i(r.position.x, r.position.y, w, r.size.y), col)
	img.fill_rect(Rect2i(r.end.x - w, r.position.y, w, r.size.y), col)


static func _round_corners(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for cy in [RADIUS, h - RADIUS]:
		for cx in [RADIUS, w - RADIUS]:
			for y in range(cy - RADIUS, cy + RADIUS):
				for x in range(cx - RADIUS, cx + RADIUS):
					var outside_x: bool = (cx == RADIUS and x < cx) or (cx != RADIUS and x >= cx)
					var outside_y: bool = (cy == RADIUS and y < cy) or (cy != RADIUS and y >= cy)
					if not (outside_x and outside_y):
						continue
					var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
					if d > RADIUS:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
					elif d > RADIUS - 1.0:
						var px := img.get_pixel(x, y)
						img.set_pixel(x, y, Color(px, px.a * (RADIUS - d)))
