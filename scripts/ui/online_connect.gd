class_name OnlineConnect
extends PanelContainer
## Hộp kết nối online.
##  - Tạo phòng: mặc định "Máy này làm server" → bật server ngay trong game, bạn cùng Wi-Fi vào được,
##    không cần chạy ChayServer.bat. Bỏ chọn để dùng server khác (VD qua tunnel Internet).
##  - Vào phòng: tự tìm các phòng đang chờ trong cùng Wi-Fi, chạm là vào (không phải gõ IP hay mã).
##    Vẫn có ô nhập mã + địa chỉ server cho trường hợp chơi qua Internet.
## Thành công (đã vào phòng) thì tự đóng; lỗi thì báo ngay trong hộp.

signal finished(ok: bool)

const CONNECT_TIMEOUT := 8.0

var mode := "create"   # create | join
var _server: LineEdit
var _server_row: Control
var _code: LineEdit
var _host_here: CheckBox
var _status: Label
var _go: Button
var _lan_box: VBoxContainer
var _lan_status: Label
var _busy := false
var _searching := false
var _t := 0.0
var _target_url := ""
var _target_code := ""


func _init(p_mode: String = "create") -> void:
	mode = p_mode


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -300
	offset_right = 300
	offset_top = -230
	offset_bottom = 230
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "Tạo phòng chơi online" if mode == "create" else "Vào phòng chơi online"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	if mode == "create":
		_host_here = CheckBox.new()
		_host_here.text = "Máy này làm server — bạn cùng Wi-Fi vào được ngay"
		_host_here.button_pressed = true
		_host_here.toggled.connect(func(on): _server_row.visible = not on)
		v.add_child(_host_here)
		v.add_child(_caption("Chơi qua Internet: bỏ chọn và nhập địa chỉ server (wss://...trycloudflare.com).", true))
	else:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		v.add_child(head)
		var lt := Label.new()
		lt.text = "Phòng trong cùng Wi-Fi"
		lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(lt)
		var again := Button.new()
		again.text = "Tìm lại"
		again.pressed.connect(func():
			Audio.play("click")
			_search_lan())
		head.add_child(again)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(540, 120)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(scroll)
		_lan_box = VBoxContainer.new()
		_lan_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lan_box.add_theme_constant_override("separation", 6)
		scroll.add_child(_lan_box)
		_lan_status = Label.new()
		_lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lan_status.custom_minimum_size = Vector2(520, 0)
		_lan_status.theme_type_variation = "CaptionLabel"
		_lan_box.add_child(_lan_status)
		v.add_child(HSeparator.new())
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", 8)
		v.add_child(code_row)
		code_row.add_child(_caption("Hoặc nhập mã phòng:"))
		_code = LineEdit.new()
		_code.max_length = NetUtil.CODE_LEN
		_code.placeholder_text = "VD: KXT4MP"
		_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_code.add_theme_font_size_override("font_size", 22)
		_code.text_changed.connect(func(t):
			var c := _code.caret_column
			_code.text = t.to_upper()
			_code.caret_column = c)
		_code.text_submitted.connect(func(_t): _go_pressed())
		code_row.add_child(_code)

	var srow := VBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	_server_row = srow
	v.add_child(srow)
	srow.add_child(_caption("Địa chỉ server:"))
	_server = LineEdit.new()
	_server.text = Global.server_url
	_server.placeholder_text = "ws://192.168.1.5:8910 hoặc wss://....trycloudflare.com"
	_server.text_submitted.connect(func(_t): _go_pressed())
	srow.add_child(_server)
	srow.visible = mode == "join"

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(540, 0)
	v.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_go = Button.new()
	_go.text = "Tạo phòng" if mode == "create" else "Vào bằng mã"
	_go.theme_type_variation = "PrimaryButton"
	_go.custom_minimum_size = Vector2(190, 50)
	_go.pressed.connect(_go_pressed)
	row.add_child(_go)
	var cancel := Button.new()
	cancel.text = "Huỷ"
	cancel.custom_minimum_size = Vector2(120, 50)
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
	if mode == "join":
		_search_lan()


## wrap = true chỉ dùng khi nhãn nằm trong cột dọc (trong hàng ngang, nhãn tự xuống dòng sẽ bị bóp còn 1 chữ/dòng).
func _caption(t: String, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = "CaptionLabel"
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(540, 0)
	return l


# ---------------------------------------------------------------- tìm trong Wi-Fi

func _search_lan() -> void:
	if _searching:
		return
	_searching = true
	for c in _lan_box.get_children():
		if c != _lan_status:
			c.queue_free()
	_lan_status.text = "Đang tìm phòng trong Wi-Fi..."
	_lan_status.visible = true
	var found: Array = await LanDiscovery.search(get_tree(), 1.6)
	_searching = false
	if not is_inside_tree():
		return
	var n := 0
	for srv in found:
		for r in srv["rooms"]:
			n += 1
			var b := Button.new()
			b.text = "Phòng của %s   ·   %d/%d người   ·   mã %s" % [r["host"], r["seats"], r["max"], r["code"]]
			b.tooltip_text = "Server: %s (%s)" % [srv["name"], srv["ip"]]
			b.custom_minimum_size = Vector2(0, 52)
			b.theme_type_variation = "AccentButton"
			var url := "ws://%s:%d" % [srv["ip"], int(srv["port"])]
			var code: String = r["code"]
			b.pressed.connect(func():
				Audio.play("click")
				_start(url, code))
			_lan_box.add_child(b)
	if n > 0:
		_lan_status.visible = false
	elif found.is_empty():
		_lan_status.text = "Chưa thấy phòng nào trong Wi-Fi. Nhờ chủ phòng bấm \"Tạo phòng\" (để chọn \"Máy này làm server\") và dùng chung Wi-Fi, rồi bấm \"Tìm lại\" — hoặc nhập mã bên dưới."
	else:
		_lan_status.text = "Thấy server trong Wi-Fi nhưng chưa có phòng nào đang chờ. Bấm \"Tìm lại\" khi chủ phòng đã tạo phòng."


# ---------------------------------------------------------------- kết nối

func _go_pressed() -> void:
	if _busy:
		return
	Audio.play("click")
	if mode == "create":
		if _host_here.button_pressed:
			if not Net.start_local_server():
				_say("Máy này đã có server đang chạy — dùng luôn server đó.")
			_start("ws://127.0.0.1:%d" % NetUtil.DEFAULT_PORT, "")
		else:
			Global.server_url = _server.text.strip_edges()
			Global.save_settings()
			_start(Global.server_url, "")
		return
	if _code.text.strip_edges().length() != NetUtil.CODE_LEN:
		_say("Mã phòng gồm %d ký tự." % NetUtil.CODE_LEN, true)
		return
	Global.server_url = _server.text.strip_edges()
	Global.save_settings()
	_start(Global.server_url, _code.text.strip_edges())


## Kết nối tới `url`, rồi tạo phòng (code rỗng) hoặc vào phòng `code`.
func _start(url: String, code: String) -> void:
	if _busy:
		return
	Net.player_name = Global.player_name
	Net.character = Global.character
	Net.token = Global.net_token
	_target_url = _normalized(url)
	_target_code = code
	_busy = true
	_t = 0.0
	_go.disabled = true
	if Net.is_online() and Net.url == _target_url:
		_on_connected()
		return
	_say("Đang kết nối...")
	if Net.connect_to(_target_url) != OK:
		_fail("Địa chỉ server không hợp lệ.")


func _normalized(u: String) -> String:
	u = u.strip_edges()
	return u if (u.begins_with("ws://") or u.begins_with("wss://")) else "ws://" + u


func _process(delta: float) -> void:
	if _busy and not Net.is_online():
		_t += delta
		if _t > CONNECT_TIMEOUT:
			Net.close()
			_fail("Không kết nối được. Kiểm tra địa chỉ, server đã bật chưa, và tường lửa Windows của máy server đã cho phép game chưa.")


func _on_connected() -> void:
	if not _busy:
		return
	if _target_code == "":
		_say("Đã kết nối. Đang tạo phòng...")
		Net.create_room({"rounds": Global.max_rounds, "difficulty": Global.difficulty})
	else:
		_say("Đã kết nối. Đang vào phòng %s..." % _target_code)
		Net.join_room(_target_code)


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
