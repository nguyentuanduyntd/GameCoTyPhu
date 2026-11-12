class_name UiPopup
extends PanelContainer
## Popup quyết định dùng chung: header (icon + tiêu đề), thân (mô tả + nội dung tuỳ biến), hàng nút hành động,
## dải màu theo loại (normal / bad = xui, cảnh báo / good = may, chúc mừng). Vào: trượt + phóng nhẹ (back),
## các nút hiện lệch nhịp; ra: thu lại mượt. Tự đặt vị trí để không che nhân vật đang đứng (đáy ↔ đỉnh màn hình).
## Phím: Enter = nút chính, Esc = nút phụ cuối cùng (thường là "Bỏ qua").
## Các panel đặc thù (đấu giá, chọn công trình...) kế thừa class này và đặt nội dung vào `body`.

signal closed

enum Variant { NORMAL, BAD, GOOD }

var title_label: Label
var desc: Label
var body: VBoxContainer
var actions: HFlowContainer
var icon_rect: TextureRect
var ribbon: ColorRect
var variant: int = Variant.NORMAL
## Hàm trả về toạ độ màn hình của nhân vật cần tránh che (do game gán). Trả Vector2(-1,-1) nếu không có.
var avoid_point: Callable = Callable()
var width := 680.0
var _tw: Tween
var _primary: Button
var _secondary: Button
var _shaking := false
## true từ lúc open_popup tới lúc close_popup (kể cả khi đang chạy hiệu ứng đóng thì đã là false).
var is_open := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	ribbon = ColorRect.new()
	ribbon.custom_minimum_size = Vector2(0, 5)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ribbon)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(34, 34)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon_rect)
	title_label = Label.new()
	title_label.theme_type_variation = "TitleLabel"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size = Vector2(200, 0)
	head.add_child(title_label)
	desc = Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	actions = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	v.add_child(actions)
	visible = false


## Mở popup (hoặc làm mới nội dung nếu đang mở).
func open_popup(title: String, icon: String = "", v: int = Variant.NORMAL) -> void:
	variant = v
	title_label.text = title
	icon_rect.texture = UiIcons.get_icon(icon) if icon != "" else null
	icon_rect.visible = icon != ""
	var pal := UiPalette.get_default()
	ribbon.color = [pal.gold, pal.danger, pal.success][v]
	clear_actions()
	desc.text = ""
	desc.visible = true
	var was_visible := visible
	is_open = true
	visible = true
	_layout()
	if _tw and _tw.is_valid():
		_tw.kill()
	if was_visible:
		# đang hiện (hoặc đang đóng dở) thì chỉ thay nội dung, khôi phục ngay
		modulate.a = 1.0
		scale = Vector2.ONE
	else:
		modulate.a = 0.0
		scale = Vector2.ONE * 0.88
		_tw = create_tween().set_parallel(true)
		_tw.tween_property(self, "modulate:a", 1.0, 0.18)
		_tw.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if v == Variant.BAD:
		shake()


func set_desc(text: String) -> void:
	desc.text = text
	desc.visible = text != ""


func clear_actions() -> void:
	for c in actions.get_children():
		c.queue_free()
	_primary = null
	_secondary = null


## Thêm nút hành động. style: "primary" (đỏ son), "accent" (xanh ngọc), "" (gỗ sáng).
func add_action(text: String, cb: Callable, style: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if style == "primary":
		b.theme_type_variation = "PrimaryButton"
	elif style == "accent":
		b.theme_type_variation = "AccentButton"
	b.pressed.connect(func(): Audio.play("click"))
	b.pressed.connect(cb)
	b.mouse_entered.connect(func(): _hover(b, true))
	b.mouse_exited.connect(func(): _hover(b, false))
	actions.add_child(b)
	if style == "primary" and _primary == null:
		_primary = b
	_secondary = b
	# xuất hiện lệch nhịp
	var idx := actions.get_child_count() - 1
	b.modulate.a = 0.0
	var tw := b.create_tween()
	tw.tween_interval(0.05 * idx + 0.08)
	tw.tween_property(b, "modulate:a", 1.0, 0.15)
	return b


func close_popup() -> void:
	is_open = false
	if not visible:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 0.0, 0.14)
	_tw.tween_property(self, "scale", Vector2.ONE * 0.92, 0.14)
	_tw.chain().tween_callback(func():
		visible = false
		closed.emit())


## Rung nhẹ (sự kiện xui).
func shake() -> void:
	if _shaking:
		return
	_shaking = true
	var base := position
	var tw := create_tween()
	for k in 5:
		tw.tween_property(self, "position", base + Vector2(randf_range(-7, 7), 0), 0.04)
	tw.tween_property(self, "position", base, 0.05)
	tw.tween_callback(func(): _shaking = false)


func _unhandled_key_input(ev: InputEvent) -> void:
	if not is_open or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k := (ev as InputEventKey).keycode
	if (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE) and _primary and not _primary.disabled:
		_primary.pressed.emit()
		get_viewport().set_input_as_handled()
	elif k == KEY_ESCAPE and _secondary and _secondary != _primary and not _secondary.disabled:
		_secondary.pressed.emit()
		get_viewport().set_input_as_handled()


## Đặt ở đáy giữa; nếu nhân vật đang đứng ở nửa dưới màn hình thì dời lên phía trên (dưới thanh Vòng/Mùa).
func _layout() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM if not _should_go_top() else Control.PRESET_CENTER_TOP)
	var top := anchor_top == 0.0
	desc.custom_minimum_size = Vector2(width - 60.0, 0)
	offset_left = -width / 2.0
	offset_right = width / 2.0
	if top:
		offset_top = 70
		offset_bottom = 70
		grow_vertical = Control.GROW_DIRECTION_END
	else:
		offset_top = -16
		offset_bottom = -16
		grow_vertical = Control.GROW_DIRECTION_BEGIN
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	pivot_offset = Vector2(width / 2.0, 0.0 if top else size.y)


func _should_go_top() -> bool:
	if not avoid_point.is_valid():
		return false
	var p: Vector2 = avoid_point.call()
	if p.x < 0:
		return false
	var vp := get_viewport_rect().size
	return p.y > vp.y * 0.52 and absf(p.x - vp.x / 2.0) < width / 2.0 + 80.0


func _hover(b: Button, on: bool) -> void:
	b.pivot_offset = b.size / 2.0
	b.create_tween().tween_property(b, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.1).set_trans(Tween.TRANS_BACK)
