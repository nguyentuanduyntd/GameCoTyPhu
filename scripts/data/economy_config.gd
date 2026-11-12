class_name EconomyConfig
extends Resource
## Hằng số cân bằng có thể chỉnh trong Godot Inspector (mở data/economy.tres).
## Engine, bot và giao diện đều đọc từ đây — không hardcode rải rác.

@export_group("Đấu giá")
## Giá khởi điểm = tỉ lệ × giá niêm yết.
@export var auction_start_ratio: float = 0.5
## Bước giá tối thiểu = tỉ lệ × giá niêm yết (làm tròn theo auction_round_to).
@export var auction_step_ratio: float = 0.1
@export var auction_round_to: int = 5
## Mỗi người được trả giá tối đa bao nhiêu lần trong một cuộc đấu giá.
@export var auction_max_bids: int = 6
## Số bước giá tối đa có thể nhảy trong một lần trả (+1, +2, +3 bước).
@export var auction_max_raise_steps: int = 3
## Thời gian suy nghĩ của người chơi thật mỗi lượt trả giá (giây, ở tốc độ x1).
@export var auction_human_seconds: float = 9.0
## Thời gian tối thiểu dù chơi ở tốc độ cao.
@export var auction_human_min_seconds: float = 4.0

@export_group("AI đấu giá")
## Độ ngẫu nhiên giá trần của máy (±).
@export var ai_random: float = 0.1
## Tiền mặt an toàn tối thiểu máy luôn giữ lại.
@export var ai_min_reserve: int = 150
## Ngoài mức tối thiểu, máy giữ thêm tỉ lệ này của tổng tài sản.
@export var ai_reserve_ratio: float = 0.08
## Giá trị đất đầu ván và cuối ván (nhân với giá niêm yết) — cuối ván đất kém giá trị hơn.
@export var ai_value_early: float = 1.3
@export var ai_value_late: float = 0.7
## Nhân thêm khi mua ô này sẽ gom đủ cả vùng.
@export var ai_complete_group_mult: float = 1.5
## Nhân thêm khi ô này giúp chặn đối thủ gom đủ vùng.
@export var ai_block_mult: float = 1.2

## Tính cách theo nhân vật:
##  bid_mult    — hệ số giá trần (liều > 1, thủ thế < 1)
##  group_bonus — cộng thêm theo mỗi tỉnh đã có trong cùng vùng
##  infra_bonus — cộng thêm khi đấu giá ô hạ tầng / Trạm BOT
##  jump        — xác suất nhảy giá +2/+3 bước
##  reserve     — hệ số tiền an toàn (cao = giữ tiền kỹ)
##  random      — độ ngẫu nhiên riêng (bỏ trống thì dùng ai_random)
@export var personalities: Dictionary = {}


static var _default: EconomyConfig


static func get_default() -> EconomyConfig:
	if _default == null:
		if ResourceLoader.exists("res://data/economy.tres"):
			_default = load("res://data/economy.tres")
		else:
			_default = EconomyConfig.new()
	return _default


func personality(character_id: String) -> Dictionary:
	var base := {"bid_mult": 1.0, "group_bonus": 0.25, "infra_bonus": 0.0, "jump": 0.2, "reserve": 1.0, "random": ai_random, "label": ""}
	var p: Dictionary = personalities.get(character_id, {})
	for k in p.keys():
		base[k] = p[k]
	return base


func round_price(v: float) -> int:
	var r := maxi(1, auction_round_to)
	return maxi(r, int(round(v / r)) * r)
