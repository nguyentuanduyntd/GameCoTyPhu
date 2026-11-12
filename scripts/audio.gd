extends Node
## Quản lý âm thanh (autoload "Audio"): hiệu ứng trên bus SFX, nhạc nền trên bus Music có chuyển bài mượt.
## Toàn bộ file âm thanh được tổng hợp bằng tools/gen_audio.py.

const SFX_NAMES := ["dice", "step", "coin", "pay", "buy", "build", "landmark", "card", "horn", "duel",
	"bankrupt", "win", "click", "toll", "thunder", "firework", "turn", "takeover"]
const POOL_SIZE := 10

var _sounds := {}
var _pool: Array = []
var _next := 0
var _music: Array = []
var _music_idx := 0
var _current_track := ""


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX_NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_sounds[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


func play(sound: String, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _sounds[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Chuyển nhạc nền (chéo mượt). track: "music_lobby", "music_game_a", "music_game_b" hoặc "" để tắt.
func play_music(track: String, fade: float = 1.5) -> void:
	if track == _current_track:
		return
	_current_track = track
	var old: AudioStreamPlayer = _music[_music_idx]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade)
	if track == "":
		return
	var path := "res://assets/audio/%s.wav" % track
	if not ResourceLoader.exists(path):
		return
	_music_idx = 1 - _music_idx
	var nxt: AudioStreamPlayer = _music[_music_idx]
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	tw.tween_property(nxt, "volume_db", -6.0, fade)


func stop_music(fade: float = 1.0) -> void:
	play_music("", fade)


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
