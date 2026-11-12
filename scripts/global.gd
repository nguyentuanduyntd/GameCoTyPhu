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
var graphics_quality: int = 1 if OS.has_feature("mobile") else 2
const QUALITY_NAMES := ["Thấp", "Vừa", "Cao"]

# Online
## Địa chỉ server (ws://máy:cổng hoặc wss://... của tunnel). Lưu lại cho lần sau.
var server_url: String = "ws://localhost:8910"
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
