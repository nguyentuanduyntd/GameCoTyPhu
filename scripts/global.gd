extends Node
## Cấu hình dùng chung giữa các màn hình (autoload "Global") + cài đặt lưu trên máy.

signal settings_changed

const BOT_NAMES := ["Máy · An", "Máy · Bình", "Máy · Chi", "Máy · Dũng", "Máy · Em"]
const SETTINGS_PATH := "user://settings.cfg"

var player_name: String = "Bạn"
var character: String = "tieu_thuong"
var bot_count: int = 3
var bot_characters: Array = []
var difficulty: int = 1
var max_rounds: int = 25
var speed: float = 1.0

# Cài đặt (lưu vào user://settings.cfg)
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var shadows: bool = true
var weather_fx: bool = true
var cam_auto: bool = true
var buy_fx: int = 2      # hiệu ứng mua đất: 0 tắt, 1 giảm, 2 bật
var cinematic: int = 2   # camera điện ảnh khi đi: 0 tắt, 1 chỉ lượt của bạn, 2 mọi người chơi
## Chất lượng đồ hoạ: 0 Thấp, 1 Vừa, 2 Cao (mặc định Cao trên máy tính, Vừa trên điện thoại)
var graphics_quality: int = 1 if (OS.has_feature("mobile") or OS.has_feature("web")) else 2
const QUALITY_NAMES := ["Thấp", "Vừa", "Cao"]

# Online
## Địa chỉ server (ws://máy:cổng hoặc wss://... của tunnel). Lưu lại cho lần sau.
var server_url: String = NetUtil.PUBLIC_SERVER
## Mã định danh máy này (để vào lại đúng chỗ khi rớt mạng). Tạo một lần, lưu lại.
var net_token: String = ""
## Ván sắp vào là ván online (game.gd đọc); thông tin bắt đầu ván nằm ở Net.start_info.
var online: bool = false


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--server"):
		# chạy làm server online: bỏ sảnh, sang cảnh server (xem scripts/net/server_main.gd)
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
	load_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bots="):
			bot_count = clampi(int(arg.substr(7)), 3, 5)
		if arg.begins_with("--buyfx="):
			buy_fx = clampi(int(arg.substr(8)), 0, 2)
		if arg.begins_with("--cinematic="):
			cinematic = clampi(int(arg.substr(12)), 0, 2)
		if arg.begins_with("--quality="):   # kiểm thử: 0 Thấp, 1 Vừa, 2 Cao
			graphics_quality = clampi(int(arg.substr(10)), 0, 2)
		if arg.begins_with("--rounds="):   # kiểm thử: ván ngắn để xem màn kết thúc
			max_rounds = maxi(1, int(arg.substr(9)))
	if OS.has_feature("web"):
		_web_defaults()
	if net_token == "":
		var r := RandomNumberGenerator.new()
		r.randomize()
		net_token = "%08x%08x" % [r.randi(), r.randi()]
		save_settings()
	apply_settings()
	# Theme gốc cho toàn bộ giao diện: gộp vào theme mặc định của Godot để mọi Control
	# (kể cả nằm dưới CanvasLayer — vốn không kế thừa theme của cửa sổ) đều dùng chung
	var t := UiTheme.get_theme()
	ThemeDB.get_default_theme().merge_with(t)
	ThemeDB.get_default_theme().default_font = t.default_font
	ThemeDB.get_default_theme().default_font_size = t.default_font_size
	ThemeDB.fallback_font_size = t.default_font_size


## Bản Web: địa chỉ server lấy từ link (…/?server=wss://…) nếu có — để chỉ cần gửi MỘT link;
## trang mở từ máy làm server qua http (cùng Wi-Fi) thì kết nối server của chính máy đó (ws://<máy>:8910);
## trang công khai (https, VD GitHub Pages) mà không có ?server= thì để trống — người chơi phải dán
## địa chỉ chủ phòng gửi (địa chỉ đường hầm đổi mỗi lần nên không giữ địa chỉ cũ).
## Kèm nhắc xoay ngang khi điện thoại đang cầm dọc.
var web_server_from_link := false


func _web_defaults() -> void:
	var proto := str(JavaScriptBridge.eval("location.protocol", true))
	var host := str(JavaScriptBridge.eval("location.hostname", true))
	var from_link := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''", true)).strip_edges()
	if from_link.begins_with("ws://") or from_link.begins_with("wss://"):
		server_url = from_link
		web_server_from_link = true
	elif proto == "http:" and host != "":
		server_url = "ws://%s:%d" % [host, NetUtil.DEFAULT_PORT]
	else:
		server_url = NetUtil.PUBLIC_SERVER   # trang công khai (GitHub Pages): dùng server công cộng 24/7
	_rotate_hint = CanvasLayer.new()
	_rotate_hint.layer = 120
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.09, 0.05, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.add_child(bg)
	var l := Label.new()
	l.text = "Xoay ngang điện thoại để chơi"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 96)
	l.add_theme_color_override("font_color", Color("#ffd54f"))
	bg.add_child(l)
	add_child(_rotate_hint)
	get_tree().root.size_changed.connect(_update_rotate_hint)
	_update_rotate_hint()


var _rotate_hint: CanvasLayer


func _update_rotate_hint() -> void:
	if _rotate_hint:
		var sz := DisplayServer.window_get_size()
		_rotate_hint.visible = sz.y > sz.x


## Nút Back (Android): trong ván thì về sảnh (online thì rời phòng đúng cách), ở sảnh thì thoát game.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.ends_with("lobby.tscn"):
		get_tree().quit()
	elif scene.has_method("_leave_to_lobby"):
		scene._leave_to_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	player_name = cf.get_value("player", "name", player_name)
	character = cf.get_value("player", "character", character)
	bot_count = cf.get_value("match", "bot_count", bot_count)
	difficulty = cf.get_value("match", "difficulty", difficulty)
	max_rounds = cf.get_value("match", "max_rounds", max_rounds)
	speed = cf.get_value("match", "speed", speed)
	music_volume = cf.get_value("audio", "music", music_volume)
	sfx_volume = cf.get_value("audio", "sfx", sfx_volume)
	shadows = cf.get_value("graphics", "shadows", shadows)
	weather_fx = cf.get_value("graphics", "weather_fx", weather_fx)
	cam_auto = cf.get_value("graphics", "cam_auto", cam_auto)
	cinematic = cf.get_value("graphics", "cinematic", cinematic)
	buy_fx = cf.get_value("graphics", "buy_fx", buy_fx)
	graphics_quality = cf.get_value("graphics", "quality", graphics_quality)
	server_url = cf.get_value("online", "server", server_url)
	if server_url == "ws://localhost:8910" or server_url == "":
		server_url = NetUtil.PUBLIC_SERVER   # mặc định cũ (máy này) → server công cộng
	net_token = cf.get_value("online", "token", net_token)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("player", "character", character)
	cf.set_value("match", "bot_count", bot_count)
	cf.set_value("match", "difficulty", difficulty)
	cf.set_value("match", "max_rounds", max_rounds)
	cf.set_value("match", "speed", speed)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("graphics", "shadows", shadows)
	cf.set_value("graphics", "weather_fx", weather_fx)
	cf.set_value("graphics", "cam_auto", cam_auto)
	cf.set_value("graphics", "cinematic", cinematic)
	cf.set_value("graphics", "buy_fx", buy_fx)
	cf.set_value("graphics", "quality", graphics_quality)
	cf.set_value("online", "server", server_url)
	cf.set_value("online", "token", net_token)
	cf.save(SETTINGS_PATH)


func apply_settings() -> void:
	Audio.set_bus_volume("Music", music_volume)
	Audio.set_bus_volume("SFX", sfx_volume)
	apply_graphics()
	settings_changed.emit()


## Khử răng cưa, độ phân giải 3D, độ nét bóng đổ theo chất lượng (áp dụng cho cả sảnh và ván chơi).
## Hiệu ứng riêng của cảnh (glow, gợn nước, nhiễu màu ô) do game.gd đọc `graphics_quality` để bật/tắt.
## Ghi chú: SSAO/SSR không có ở renderer Mobile nên không dùng.
func apply_graphics() -> void:
	var vp := get_tree().root
	match graphics_quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 0.8
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)


## Chọn ngẫu nhiên nhân vật cho máy (không trùng nhau, không trùng người chơi).
func reroll_bots() -> void:
	var pool: Array = []
	for c in CardsData.CHARACTERS:
		if c["id"] != character:
			pool.append(c["id"])
	pool.shuffle()
	bot_characters = pool.slice(0, bot_count)


## Đảm bảo danh sách nhân vật máy hợp lệ sau khi đổi số máy hoặc đổi nhân vật người chơi.
func fix_bots() -> void:
	var used := {character: true}
	var res: Array = []
	for c in bot_characters:
		if res.size() < bot_count and not used.has(c):
			res.append(c)
			used[c] = true
	for c in CardsData.CHARACTERS:
		if res.size() >= bot_count:
			break
		if not used.has(c["id"]):
			res.append(c["id"])
			used[c["id"]] = true
	bot_characters = res


func make_player_configs(all_bots: bool = false) -> Array:
	if bot_characters.size() != bot_count:
		reroll_bots()
	fix_bots()
	var cfg: Array = [{"name": player_name, "character": character, "is_bot": all_bots, "difficulty": 2}]
	for i in bot_count:
		cfg.append({"name": BOT_NAMES[i], "character": bot_characters[i], "is_bot": true, "difficulty": difficulty})
	return cfg
