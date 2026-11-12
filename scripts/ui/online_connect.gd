class_name OnlineConnect
extends PanelContainer
## Hộp kết nối online: nhập địa chỉ server (và mã phòng khi vào phòng), rồi tạo / vào phòng.
## Thành công (đã có phòng) thì tự đóng; lỗi thì báo ngay trong hộp.

signal finished(ok: bool)

const CONNECT_TIMEOUT := 8.0

var mode := "create"   # create | join
var _server: LineEdit
var _code: LineEdit
var _status: Label
var _go: Button
var _busy := false
var _t := 0.0


func _init(p_mode: String = "create") -> void:
	mode = p_mode


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -280
	offset_right = 280
	offset_top = -150
	offset_bottom = 150
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "Tạo phòng chơi online" if mode == "create" else "Vào phòng bằng mã"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if mode == "join":
		v.add_child(_caption("Mã phòng (6 ký tự, bạn của bạn gửi):"))
		_code = LineEdit.new()
		_code.max_length = NetUtil.CODE_LEN
		_code.placeholder_text = "VD: KXT4MP"
		_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_code.add_theme_font_size_override("font_size", 28)
		_code.text_changed.connect(func(t):
			var c := _code.caret_column
			_code.text = t.to_upper()
			_code.caret_column = c)
		_code.text_submitted.connect(func(_t): _go_pressed())
		v.add_child(_code)
	v.add_child(_caption("Địa chỉ server:"))
	_server = LineEdit.new()
	_server.text = Global.server_url
	_server.placeholder_text = "ws://localhost:8910 hoặc wss://....trycloudflare.com"
	_server.text_submitted.connect(func(_t): _go_pressed())
	v.add_child(_server)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(500, 0)
	v.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_go = Button.new()
	_go.text = "Tạo phòng" if mode == "create" else "Vào phòng"
	_go.theme_type_variation = "PrimaryButton"
	_go.custom_minimum_size = Vector2(180, 46)
	_go.pressed.connect(_go_pressed)
	row.add_child(_go)
	var cancel := Button.new()
	cancel.text = "Huỷ"
	cancel.custom_minimum_size = Vector2(120, 46)
	cancel.pressed.connect(func():
		Audio.play("click")
		if _busy:
			Net.close()
		_finish(false))
	row.add_child(cancel)
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.error_received.connect(_on_error)
	Net.room_updated.connect(_on_room)
	if _code:
		_code.grab_focus.call_deferred()


func _caption(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = "CaptionLabel"
	return l


func _go_pressed() -> void:
	if _busy:
		return
	Audio.play("click")
	if mode == "join" and _code.text.strip_edges().length() != NetUtil.CODE_LEN:
		_say("Mã phòng gồm %d ký tự." % NetUtil.CODE_LEN, true)
		return
	Global.server_url = _server.text.strip_edges()
	Global.save_settings()
	Net.player_name = Global.player_name
	Net.character = Global.character
	Net.token = Global.net_token
	_busy = true
	_t = 0.0
	_go.disabled = true
	if Net.is_online() and Net.url == _normalized(Global.server_url):
		_on_connected()
		return
	_say("Đang kết nối tới server...")
	if Net.connect_to(Global.server_url) != OK:
		_fail("Địa chỉ server không hợp lệ.")


func _normalized(u: String) -> String:
	u = u.strip_edges()
	return u if (u.begins_with("ws://") or u.begins_with("wss://")) else "ws://" + u


func _process(delta: float) -> void:
	if _busy and not Net.is_online():
		_t += delta
		if _t > CONNECT_TIMEOUT:
			Net.close()
			_fail("Không kết nối được. Kiểm tra địa chỉ và server đã bật chưa.")


func _on_connected() -> void:
	if not _busy:
		return
	_say("Đã kết nối. Đang %s..." % ("tạo phòng" if mode == "create" else "vào phòng"))
	if mode == "create":
		Net.create_room({"rounds": Global.max_rounds, "difficulty": Global.difficulty})
	else:
		Net.join_room(_code.text.strip_edges())


func _on_disconnected() -> void:
	if _busy:
		_fail("Mất kết nối tới server.")


func _on_error(text: String) -> void:
	if _busy:
		_fail(text)


func _on_room(room: Dictionary) -> void:
	if _busy and not room.is_empty():
		_busy = false
		_finish(true)


func _fail(text: String) -> void:
	_busy = false
	_go.disabled = false
	_say(text, true)
	Audio.play("pay", 0.0, -6.0)


func _say(text: String, bad: bool = false) -> void:
	_status.text = text
	if bad:
		_status.add_theme_color_override("font_color", UiPalette.get_default().danger)
	else:
		_status.remove_theme_color_override("font_color")


func _finish(ok: bool) -> void:
	Net.connected.disconnect(_on_connected)
	Net.disconnected.disconnect(_on_disconnected)
	Net.error_received.disconnect(_on_error)
	Net.room_updated.disconnect(_on_room)
	finished.emit(ok)
	queue_free()
