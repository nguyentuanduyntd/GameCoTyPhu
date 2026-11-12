class_name UiPalette
extends Resource
## Design tokens của toàn bộ giao diện — đổi ở đây (data/ui/palette.tres) là cả game đổi theo.
## Phong cách "bàn cờ đồ chơi gỗ Việt": giấy dó/kem ấm, viền gỗ nâu, nhấn đỏ son – vàng nghệ – xanh ngọc.

@export_group("Màu nền & chất liệu")
@export var paper: Color = Color("#fff4dc")
@export var paper_dark: Color = Color("#f0dcb2")
@export var wood: Color = Color("#7a4a2a")
@export var wood_dark: Color = Color("#4a2a17")
@export var wood_light: Color = Color("#a8743f")
@export var ink: Color = Color("#3b2414")
@export var ink_soft: Color = Color("#7a6250")

@export_group("Màu nhấn")
@export var primary: Color = Color("#c0392b")      # đỏ son
@export var gold: Color = Color("#f2b31b")         # vàng nghệ
@export var jade: Color = Color("#1f8a7a")         # xanh ngọc
@export var success: Color = Color("#2e9b4f")
@export var danger: Color = Color("#c62828")
@export var money: Color = Color("#ffd54a")
@export var money_gain: Color = Color("#3ddc6e")
@export var money_loss: Color = Color("#ff5a4a")

@export_group("Người chơi")
@export var players: Array[Color] = [Color("#e53935"), Color("#1e88e5"), Color("#43a047"), Color("#fdd835"), Color("#8e24aa"), Color("#fb8c00")]

@export_group("Mùa (tông thanh trên cùng)")
@export var seasons: Array[Color] = [Color("#b3261e"), Color("#1f8a7a"), Color("#b5651d"), Color("#4f6d8a")]

@export_group("Kích thước")
@export var radius_lg: int = 16
@export var radius_md: int = 12
@export var radius_sm: int = 8
@export var font_title: int = 24
@export var font_subtitle: int = 19
@export var font_body: int = 16
@export var font_caption: int = 13
@export var font_money: int = 21
@export var font_big: int = 34


static var _default: UiPalette


static func get_default() -> UiPalette:
	if _default == null:
		_default = load("res://data/ui/palette.tres") if ResourceLoader.exists("res://data/ui/palette.tres") else UiPalette.new()
	return _default


func player(i: int) -> Color:
	return players[i % players.size()]
