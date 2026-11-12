class_name UiTheme
extends RefCounted
## Dựng Theme gốc của toàn game từ UiPalette (data/ui/palette.tres). Áp vào cửa sổ gốc nên mọi Control
## (kể cả trong CanvasLayer) đều dùng chung. Các kiểu dùng lại qua theme_type_variation:
##   Panel:  PanelContainer (giấy kem, mặc định) · WoodPanel (gỗ đậm, HUD) · SubPanel (lõm nhẹ) · ChipPanel
##   Nút:    Button (gỗ sáng) · PrimaryButton (đỏ son) · AccentButton (xanh ngọc) · GhostButton
##   Chữ:    Label (mực nâu) · LightLabel (chữ kem trên gỗ) · TitleLabel · CaptionLabel · MoneyLabel
## Panel/nút là StyleBoxTexture 9 mảnh vẽ bằng code: gradient dọc, viền ngoài đậm + viền sáng bên trong,
## bóng mềm phía dưới, hoa văn góc kiểu Việt; nút có "độ dày" nổi lên và lún xuống khi nhấn.

static var _theme: Theme
static var _bold: Font
static var _tex := {}


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build(UiPalette.get_default())
	return _theme


static func bold_font() -> Font:
	if _bold == null:
		var custom := "res://assets/fonts/BeVietnamPro-Bold.ttf"
		if ResourceLoader.exists(custom):
			_bold = load(custom)
		else:
			var fv := FontVariation.new()
			fv.base_font = _base_font()
			fv.variation_embolden = 0.7
			_bold = fv
	return _bold


static func _base_font() -> Font:
	var custom := "res://assets/fonts/BeVietnamPro-Medium.ttf"
	if ResourceLoader.exists(custom):
		return load(custom)
	return ThemeDB.fallback_font


static func build(p: UiPalette) -> Theme:
	var t := Theme.new()
	t.default_font = _base_font()
	t.default_font_size = p.font_body

	# ---------------- Panel
	t.set_stylebox("panel", "PanelContainer", _panel_box(p.paper, p.paper_dark, p.wood_dark, Color(1, 1, 1, 0.75), p.radius_lg, true, true, 14))
	t.set_stylebox("panel", "Panel", _panel_box(p.paper, p.paper_dark, p.wood_dark, Color(1, 1, 1, 0.75), p.radius_lg, true, true, 14))
	_variation(t, "WoodPanel", "PanelContainer")
	t.set_stylebox("panel", "WoodPanel", _panel_box(p.wood.lightened(0.05), p.wood_dark, p.wood_dark.darkened(0.4), Color(p.gold, 0.55), p.radius_md, true, false, 10))
	_variation(t, "SubPanel", "PanelContainer")
	t.set_stylebox("panel", "SubPanel", _flat(p.paper_dark.darkened(0.03), p.radius_md, Color(p.wood, 0.35), 1, 8))
	_variation(t, "ChipPanel", "PanelContainer")
	t.set_stylebox("panel", "ChipPanel", _flat(Color(p.wood_dark, 0.85), 10, Color(p.gold, 0.6), 1, 6))

	# ---------------- Chữ
	t.set_color("font_color", "Label", p.ink)
	_variation(t, "LightLabel", "Label")
	t.set_color("font_color", "LightLabel", p.paper)
	t.set_color("font_outline_color", "LightLabel", Color(p.wood_dark, 0.9))
	t.set_constant("outline_size", "LightLabel", 4)
	_variation(t, "TitleLabel", "Label")
	t.set_font("font", "TitleLabel", bold_font())
	t.set_font_size("font_size", "TitleLabel", p.font_title)
	t.set_color("font_color", "TitleLabel", p.primary.darkened(0.15))
	_variation(t, "LightTitleLabel", "Label")
	t.set_font("font", "LightTitleLabel", bold_font())
	t.set_font_size("font_size", "LightTitleLabel", p.font_title)
	t.set_color("font_color", "LightTitleLabel", p.gold)
	t.set_color("font_outline_color", "LightTitleLabel", p.wood_dark)
	t.set_constant("outline_size", "LightTitleLabel", 8)
	_variation(t, "CaptionLabel", "Label")
	t.set_font_size("font_size", "CaptionLabel", p.font_caption)
	t.set_color("font_color", "CaptionLabel", p.ink_soft)
	_variation(t, "MoneyLabel", "Label")
	t.set_font("font", "MoneyLabel", bold_font())
	t.set_font_size("font_size", "MoneyLabel", p.font_money)
	t.set_color("font_color", "MoneyLabel", p.money)
	t.set_color("font_outline_color", "MoneyLabel", p.wood_dark)
	t.set_constant("outline_size", "MoneyLabel", 6)
	t.set_color("default_color", "RichTextLabel", p.ink)
	t.set_font("bold_font", "RichTextLabel", bold_font())

	# ---------------- Nút
	_button_type(t, "Button", p.paper, p.wood_light, p.wood_dark, p.ink, p)
	_variation(t, "PrimaryButton", "Button")
	_button_type(t, "PrimaryButton", p.primary.lightened(0.12), p.primary.darkened(0.15), p.primary.darkened(0.55), Color("#fff8e7"), p)
	_variation(t, "AccentButton", "Button")
	_button_type(t, "AccentButton", p.jade.lightened(0.12), p.jade.darkened(0.15), p.jade.darkened(0.55), Color("#f2fffb"), p)
	_variation(t, "GhostButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := _flat(Color(1, 1, 1, 0.0 if st == "normal" else (0.12 if st == "hover" else 0.2)), p.radius_sm, Color(0, 0, 0, 0), 0, 8)
		t.set_stylebox(st, "GhostButton", b)
	t.set_color("font_color", "GhostButton", p.paper)
	t.set_color("font_hover_color", "GhostButton", Color.WHITE)
	# OptionButton / CheckBox dùng nền nút gỗ sáng
	for ty in ["OptionButton", "MenuButton"]:
		_button_type(t, ty, p.paper, p.wood_light, p.wood_dark, p.ink, p)
	t.set_color("font_color", "CheckBox", p.ink)
	t.set_color("font_hover_color", "CheckBox", p.primary)
	t.set_color("font_pressed_color", "CheckBox", p.ink)

	# ---------------- Ô nhập, thanh trượt, tiến trình
	t.set_stylebox("normal", "LineEdit", _flat(Color("#fffaf0"), p.radius_sm, p.wood_light, 2, 8))
	t.set_stylebox("focus", "LineEdit", _flat(Color(0, 0, 0, 0), p.radius_sm, p.gold, 2, 8))
	t.set_color("font_color", "LineEdit", p.ink)
	t.set_stylebox("slider", "HSlider", _flat(p.paper_dark.darkened(0.15), 4, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_area", "HSlider", _flat(p.gold, 4, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(p.gold.lightened(0.2), 4, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("background", "ProgressBar", _flat(Color(p.wood_dark, 0.7), 6, Color(p.gold, 0.4), 1, 0))
	t.set_stylebox("fill", "ProgressBar", _flat(p.gold, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("panel", "PopupMenu", _flat(p.paper, p.radius_sm, p.wood, 2, 6))
	t.set_color("font_color", "PopupMenu", p.ink)
	t.set_color("font_hover_color", "PopupMenu", p.primary)
	t.set_stylebox("hover", "PopupMenu", _flat(Color(p.gold, 0.35), 6, Color(0, 0, 0, 0), 0, 4))

	# ---------------- Tooltip
	t.set_stylebox("panel", "TooltipPanel", _flat(Color(p.wood_dark, 0.96), p.radius_sm, p.gold, 1, 8))
	t.set_color("font_color", "TooltipLabel", p.paper)
	t.set_font_size("font_size", "TooltipLabel", p.font_caption + 1)
	return t


# ---------------------------------------------------------------- StyleBox dựng sẵn

static func _variation(t: Theme, name: String, base: String) -> void:
	t.set_type_variation(name, base)


static func _flat(bg: Color, radius: int, border: Color, bw: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func _button_type(t: Theme, ty: String, top: Color, bottom: Color, edge: Color, text: Color, p: UiPalette) -> void:
	t.set_stylebox("normal", ty, _button_box(top, bottom, edge, 5, false))
	t.set_stylebox("hover", ty, _button_box(top.lightened(0.12), bottom.lightened(0.1), edge, 5, false))
	t.set_stylebox("pressed", ty, _button_box(top.darkened(0.06), bottom.darkened(0.08), edge, 1, true))
	t.set_stylebox("disabled", ty, _button_box(Color("#cfc6b8"), Color("#a99f92"), Color("#7d7468"), 3, false))
	t.set_stylebox("focus", ty, StyleBoxEmpty.new())
	t.set_color("font_color", ty, text)
	t.set_color("font_hover_color", ty, text)
	t.set_color("font_pressed_color", ty, text)
	t.set_color("font_focus_color", ty, text)
	t.set_color("font_disabled_color", ty, Color("#6e655a"))
	t.set_font("font", ty, bold_font())
	t.set_constant("h_separation", ty, 8)


## Panel: gradient dọc + viền 2 lớp + bóng mềm + (tuỳ chọn) hoa văn góc. Trả về StyleBoxTexture 9 mảnh.
static func _panel_box(top: Color, bottom: Color, edge: Color, inner: Color, radius: int, shadow: bool, motif: bool, content: int) -> StyleBoxTexture:
	var key := "p%s%s%s%s%d%s%s" % [top.to_html(), bottom.to_html(), edge.to_html(), inner.to_html(), radius, shadow, motif]
	var pad := 8 if shadow else 0
	var size := radius * 2 + 40
	if not _tex.has(key):
		_tex[key] = _render_box(size, pad, radius, top, bottom, edge, inner, 3, 0, motif)
	var s := StyleBoxTexture.new()
	s.texture = _tex[key]
	var m := radius + pad + 4
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m
	s.expand_margin_left = pad
	s.expand_margin_right = pad
	s.expand_margin_top = pad
	s.expand_margin_bottom = pad
	s.set_content_margin_all(content)
	return s


## Nút: mặt trên gradient + phần "thân" dày phía dưới (thickness px). Nhấn: thân mỏng, mặt lún xuống.
static func _button_box(top: Color, bottom: Color, edge: Color, thickness: int, pressed: bool) -> StyleBoxTexture:
	var key := "b%s%s%s%d%s" % [top.to_html(), bottom.to_html(), edge.to_html(), thickness, pressed]
	var radius := 12
	var pad := 4
	var size := radius * 2 + 32
	if not _tex.has(key):
		_tex[key] = _render_box(size, pad, radius, top, bottom, edge, Color(1, 1, 1, 0.55), 2, thickness, false)
	var s := StyleBoxTexture.new()
	s.texture = _tex[key]
	var m := radius + pad + 2
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m + thickness
	s.expand_margin_left = pad
	s.expand_margin_right = pad
	s.expand_margin_top = pad
	s.expand_margin_bottom = pad
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 7 + (3 if pressed else 0)
	s.content_margin_bottom = 7 + thickness - (0 if pressed else 0)
	return s


## Vẽ một ô bo góc: bóng mềm (pad px quanh), thân dày (thickness) màu edge, mặt gradient top→bottom,
## viền ngoài edge (border px), viền sáng bên trong, hoa văn góc.
static func _render_box(size: int, pad: int, radius: int, top: Color, bottom: Color, edge: Color, inner: Color, border: int, thickness: int, motif: bool) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := Vector2(size / 2.0 - pad, size / 2.0 - pad)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var px := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			# bóng mềm lệch xuống
			if pad > 0:
				var ds := _sdf(px - c - Vector2(0, pad * 0.5), half, radius)
				var sa := clampf(1.0 - (ds + 1.0) / float(pad), 0.0, 1.0)
				col = Color(0, 0, 0, 0.32 * sa * sa)
			# thân dày (phần dưới nút)
			if thickness > 0:
				var dt := _sdf(px - c, half, radius)
				if dt <= 0.5:
					col = _over(col, Color(edge.darkened(0.15), clampf(0.5 - dt, 0.0, 1.0)))
			# mặt trên (dịch lên theo độ dày)
			var face_half := half - Vector2(0, thickness / 2.0)
			var face_c := c - Vector2(0, thickness / 2.0)
			var d := _sdf(px - face_c, face_half, radius)
			if d <= 0.5:
				var a := clampf(0.5 - d, 0.0, 1.0)
				var ty := clampf((px.y - (face_c.y - face_half.y)) / (face_half.y * 2.0), 0.0, 1.0)
				var fill := top.lerp(bottom, ty * ty * 0.6 + ty * 0.4)
				var f := fill
				if -d < border:
					f = edge
				elif -d < border + 1.6:
					f = fill.lerp(inner, inner.a)
				col = _over(col, Color(f, a * fill.a if -d >= border else a))
				# hoa văn góc: hai móc vuông lồng nhau (kiểu triện)
				if motif and -d > border + 3:
					var lx := minf(px.x - (face_c.x - face_half.x), (face_c.x + face_half.x) - px.x)
					var ly := minf(px.y - (face_c.y - face_half.y), (face_c.y + face_half.y) - px.y)
					var r0 := float(border + 6)
					if lx < r0 + 12 and ly < r0 + 12:
						var on := (absf(lx - r0) < 0.8 and ly > r0 - 0.5 and ly < r0 + 10) or (absf(ly - r0) < 0.8 and lx > r0 - 0.5 and lx < r0 + 10)
						on = on or (absf(lx - r0 - 4) < 0.7 and ly > r0 + 3.5 and ly < r0 + 7) or (absf(ly - r0 - 4) < 0.7 and lx > r0 + 3.5 and lx < r0 + 7)
						if on:
							col = _over(col, Color(edge, 0.35))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _sdf(p: Vector2, half: Vector2, r: float) -> float:
	var q := p.abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _over(dst: Color, src: Color) -> Color:
	var a := src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(0, 0, 0, 0)
	var rgb := (Color(src.r, src.g, src.b) * src.a + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - src.a)) / a
	return Color(rgb.r, rgb.g, rgb.b, a)
