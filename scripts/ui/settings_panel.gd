class_name SettingsPanel
extends PanelContainer
## Bảng cài đặt dùng chung cho sảnh và trong ván. Thay đổi được áp dụng và lưu ngay.

signal closed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -230
	offset_right = 230
	offset_top = -255
	offset_bottom = 255
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	title.text = "CÀI ĐẶT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	v.add_child(title)

	v.add_child(_slider_row("Nhạc nền", Global.music_volume, func(val):
		Global.music_volume = val
		_commit()))
	v.add_child(_slider_row("Hiệu ứng âm thanh", Global.sfx_volume, func(val):
		Global.sfx_volume = val
		_commit()
		Audio.play("coin")))

	var speed_row := HBoxContainer.new()
	speed_row.add_child(_label("Tốc độ ván mặc định"))
	var speed := OptionButton.new()
	for s in [1, 2, 4]:
		speed.add_item("x%d" % s)
	speed.select(maxi(0, [1.0, 2.0, 4.0].find(Global.speed)))
	speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed.item_selected.connect(func(i):
		Global.speed = [1.0, 2.0, 4.0][i]
		_commit())
	speed_row.add_child(speed)
	v.add_child(speed_row)

	v.add_child(_check("Bóng đổ (tắt để mượt hơn trên máy yếu)", Global.shadows, func(on):
		Global.shadows = on
		_commit()))
	v.add_child(_check("Hiệu ứng thời tiết (hoa, lá, mưa)", Global.weather_fx, func(on):
		Global.weather_fx = on
		_commit()))
	v.add_child(_check("Toàn cảnh tự xoay theo người đang đi", Global.cam_auto, func(on):
		Global.cam_auto = on
		_commit()))

	var cine_row := HBoxContainer.new()
	cine_row.add_child(_label("Camera điện ảnh khi đi"))
	var cine := OptionButton.new()
	for t in ["Tắt", "Chỉ lượt của bạn", "Mọi người chơi"]:
		cine.add_item(t)
	cine.select(clampi(Global.cinematic, 0, 2))
	cine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cine.item_selected.connect(func(i):
		Global.cinematic = i
		_commit())
	cine_row.add_child(cine)
	v.add_child(cine_row)

	var fx_row := HBoxContainer.new()
	fx_row.add_child(_label("Hiệu ứng mua đất"))
	var fx := OptionButton.new()
	for t in ["Tắt", "Giảm", "Bật"]:
		fx.add_item(t)
	fx.select(clampi(Global.buy_fx, 0, 2))
	fx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fx.item_selected.connect(func(i):
		Global.buy_fx = i
		_commit())
	fx_row.add_child(fx)
	v.add_child(fx_row)

	var close := Button.new()
	close.text = "Đóng"
	close.custom_minimum_size = Vector2(0, 44)
	close.theme_type_variation = "PrimaryButton"
	close.pressed.connect(func():
		Audio.play("click")
		closed.emit()
		queue_free())
	v.add_child(close)


func _commit() -> void:
	Global.apply_settings()
	Global.save_settings()


func _slider_row(text: String, value: float, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := _label(text)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 32)
	s.drag_ended.connect(func(_changed): cb.call(s.value))
	row.add_child(s)
	return row


func _check(text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(cb)
	return c


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
