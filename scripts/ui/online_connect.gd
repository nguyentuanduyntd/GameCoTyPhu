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
	# cao vừa nội dung (không chừa khoảng trống thừa), luôn ở giữa màn hình
	offset_top = 0
	offset_bottom = 0
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
		# Mặc định: phòng trên server công cộng 24/7 (Cloudflare) — bạn bè ở đâu cũng vào được bằng mã phòng.
		# Bản cài có thêm lựa chọn "Máy này làm server" cho chơi cùng Wi-Fi không cần Internet.
		var on_public := Global.server_url == NetUtil.PUBLIC_SERVER
		v.add_child(_caption(("Phòng được tạo trên server công cộng (chạy 24/7) — bạn bè ở đâu cũng vào được bằng mã phòng, kể cả iPhone qua trang web." if on_public
			else "Phòng được tạo trên server ở địa chỉ bên dưới."), true))
		_host_here = CheckBox.new()
		_host_here.text = "Máy này làm server (chỉ bạn cùng Wi-Fi vào được, không cần Internet)"
		_host_here.button_pressed = false
		_host_here.toggled.connect(func(on): _server_row.visible = not on)
		v.add_child(_host_here)
		if OS.has_feature("web"):
			_host_here.visible = false   # trình duyệt không làm server được
	else:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		v.add_child(head)
		var lt := Label.new()
		lt.text = "Phòng đang chờ"
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
	_server.placeholder_text = "Dán link hoặc địa chỉ wss://… chủ phòng gửi" if OS.has_feature("web") else "ws://192.168.1.5:8910 hoặc wss://....trycloudflare.com"
	_server.text_submitted.connect(func(_t): _go_pressed())
	srow.add_child(_server)
	srow.visible = true   # tạo phòng: ẩn khi chọn "Máy này làm server"

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
	_lan_status.text = "Đang tìm phòng..."
	_lan_status.visible = true
	# phòng trên server ở ô địa chỉ (mặc định server công cộng) + phòng trong cùng Wi-Fi (bản cài)
	var found: Array = []
	if _server.text.strip_edges() != "":
		found.append_array(await _search_server())
	if not OS.has_feature("web") and is_inside_tree():
		found.append_array(await LanDiscovery.search(get_tree(), 1.6))
	_searching = false
	if not is_inside_tree():
		return
	var n := 0
	for srv in found:
		for r in srv["rooms"]:
			n += 1
			var b := Button.new()
			b.text = "Phòng của %s   ·   %d/%d người   ·   mã %s" % [r["host"], r["seats"], r["max"], r["code"]]
			b.tooltip_text = "Server: %s (%s)" % [srv["name"], srv.get("ip", srv.get("url", ""))]
			b.custom_minimum_size = Vector2(0, 52)
			b.theme_type_variation = "AccentButton"
			var url: String = srv["url"] if srv.has("url") else "ws://%s:%d" % [srv["ip"], int(srv["port"])]
			var code: String = r["code"]
			b.pressed.connect(func():
				Audio.play("click")
				_start(url, code))
			_lan_box.add_child(b)
	if n > 0:
		_lan_status.visible = false
	elif found.is_empty():
		_lan_status.text = "Không kết nối được server. Kiểm tra mạng Internet, rồi bấm \"Tìm lại\" — hoặc nhập mã phòng bên dưới."
	else:
		_lan_status.text = "Chưa có phòng nào đang chờ. Bấm \"Tìm lại\" khi bạn bè đã tạo phòng — hoặc nhập mã phòng bên dưới."


## Bản Web: kết nối tới server ở ô địa chỉ và hỏi danh sách phòng đang chờ (thay cho tìm qua UDP).
func _search_server() -> Array:
	var url := _server_address()
	if url == "":
		return []
	if not (Net.is_online() and Net.url == url):
		Net.player_name = Global.player_name
		Net.character = Global.character
		Net.token = Global.net_token
		if Net.connect_to(url) != OK:
			return []
	var t := 0.0
	while not Net.is_online() and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not Net.is_online():
		return []
	var got: Array = []
	var done := [false]
	var cb := func(rooms: Array):
		got.append_array(rooms)
		done[0] = true
	Net.rooms_listed.connect(cb, CONNECT_ONE_SHOT)
	Net.request_rooms()
	t = 0.0
	while not done[0] and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not done[0]:
		Net.rooms_listed.disconnect(cb)
		return []
	return [{"url": url, "name": "Server công cộng" if url == NetUtil.PUBLIC_SERVER else url, "rooms": got}]


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
			var addr := _server_address()
			if addr == "":
				return
			Global.server_url = addr
			Global.save_settings()
			_start(addr, "")
		return
	if _code.text.strip_edges().length() != NetUtil.CODE_LEN:
		_say("Mã phòng gồm %d ký tự." % NetUtil.CODE_LEN, true)
		return
	var addr2 := _server_address()
	if addr2 == "":
		return
	Global.server_url = addr2
	Global.save_settings()
	_start(addr2, _code.text.strip_edges())


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


## Địa chỉ server từ ô nhập: nhận cả địa chỉ (ws:// / wss:// / IP:cổng) lẫn nguyên link chia sẻ
## (…/?server=wss://…). Trả về "" và báo lỗi dễ hiểu nếu không dùng được.
func _server_address() -> String:
	var t := _server.text.strip_edges()
	if t.contains("server="):
		t = t.get_slice("server=", 1).get_slice("&", 0).uri_decode().strip_edges()
		_server.text = t
	if t == "":
		# bản Web đã hiện hướng dẫn đầy đủ phía trên → chỉ nhắc ngắn, không lặp lại
		_say("Chưa có địa chỉ server — xem hướng dẫn ở trên." if OS.has_feature("web") else _no_server_hint(), true)
		return ""
	if t.begins_with("http://") or t.begins_with("https://"):
		_say("Đây là link trang web, chưa có địa chỉ server. Hãy mở hoặc dán đúng link chủ phòng gửi (có phần ?server=wss://…).", true)
		return ""
	var u := _normalized(t)
	if _page_is_https() and u.begins_with("ws://") and not (u.contains("localhost") or u.contains("127.0.0.1")):
		_say("Trang web này (https) chỉ kết nối được địa chỉ wss://… — hãy mở đúng link chủ phòng gửi.", true)
		return ""
	return u


func _page_is_https() -> bool:
	return OS.has_feature("web") and str(JavaScriptBridge.eval("location.protocol", true)) == "https:"


func _no_server_hint() -> String:
	if OS.has_feature("web"):
		return "Bản Web không tự làm server được. Nhờ chủ phòng bật ChiaSeInternet.bat trên máy tính rồi gửi link — mở đúng link đó, hoặc dán link vào ô Địa chỉ server. Chơi một mình: bấm Huỷ rồi CHƠI VỚI MÁY."
	return "Nhập địa chỉ server (VD ws://192.168.1.5:8910 hoặc wss://….trycloudflare.com)."


func _process(delta: float) -> void:
	if _busy and not Net.is_online():
		_t += delta
		if _t > CONNECT_TIMEOUT:
			Net.close()
			_fail(_cannot_connect_hint())


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
		_fail(_cannot_connect_hint())


func _cannot_connect_hint() -> String:
	if OS.has_feature("web") and _page_is_https():
		return "Không kết nối được tới server. Kiểm tra chủ phòng còn mở cửa sổ ChiaSeInternet, và bạn đang dùng link MỚI NHẤT họ gửi (mỗi lần bật lại, link đổi)."
	return "Không kết nối được tới server. Kiểm tra địa chỉ, server đã bật chưa, và tường lửa Windows của máy server đã cho phép game chưa."


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
