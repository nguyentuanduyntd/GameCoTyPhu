extends Node
## Cấu hình dùng chung giữa các màn hình (autoload "Global").

const BOT_NAMES := ["Máy · An", "Máy · Bình", "Máy · Chi", "Máy · Dũng", "Máy · Em"]

var player_name: String = "Bạn"
var character: String = "tieu_thuong"
var bot_count: int = 3
var difficulty: int = 1
var max_rounds: int = 25
var speed: float = 1.0


func make_player_configs(all_bots: bool = false) -> Array:
	var cfg: Array = [{"name": player_name, "character": character, "is_bot": all_bots, "difficulty": 2}]
	var pool: Array = []
	for c in CardsData.CHARACTERS:
		if c["id"] != character:
			pool.append(c["id"])
	pool.shuffle()
	for i in bot_count:
		cfg.append({"name": BOT_NAMES[i], "character": pool[i], "is_bot": true, "difficulty": difficulty})
	return cfg
