class_name BoardData
extends RefCounted
## Dữ liệu tĩnh của bàn cờ: 52 ô, 34 tỉnh thành (theo bản đồ hành chính từ 01/07/2025).

enum T { START, JAIL, FESTIVAL, TRAIN, PROVINCE, INFRA, CO_HOI, KHI_VAN, TAX, MARKET, LOTTERY, TOLL, CHARITY }

const TILE_COUNT := 52
const SIDE := 13  # số ô mỗi cạnh tính cả 1 góc
const START_TILE := 0
const JAIL_TILE := 13
const FESTIVAL_TILE := 26
const TRAIN_TILE := 39

const REGION_NAMES := ["Miền Bắc", "Miền Trung", "Miền Nam"]

## Nhóm vùng (thay cho "nhóm màu"). region: 0 Bắc, 1 Trung, 2 Nam.
const GROUPS := [
	{"name": "Tây Bắc", "region": 0, "color": "#8d6e63"},
	{"name": "Đông Bắc", "region": 0, "color": "#26a69a"},
	{"name": "Trung du", "region": 0, "color": "#9ccc65"},
	{"name": "Đồng bằng & Vịnh Bắc Bộ", "region": 0, "color": "#29b6f6"},
	{"name": "Bắc Trung Bộ", "region": 1, "color": "#ec407a"},
	{"name": "Miền Trung di sản", "region": 1, "color": "#ffa726"},
	{"name": "Tây Nguyên", "region": 1, "color": "#7e57c2"},
	{"name": "Duyên hải & Đông Nam Bộ", "region": 2, "color": "#fdd835"},
	{"name": "Miền Tây sông nước", "region": 2, "color": "#43a047"},
	{"name": "Siêu Đô Thị", "region": 2, "color": "#e53935"},
]

const TILES := [
	{"type": T.START, "name": "Khởi Hành
Km 0"},
	{"type": T.PROVINCE, "name": "Lai Châu", "group": 0, "price": 60, "coastal": false, "specialty": "Chè Shan tuyết", "landmark": "Cầu kính Rồng Mây"},
	{"type": T.PROVINCE, "name": "Điện Biên", "group": 0, "price": 60, "coastal": false, "specialty": "Gạo Điện Biên", "landmark": "Đồi A1"},
	{"type": T.KHI_VAN, "name": "Khí Vận"},
	{"type": T.PROVINCE, "name": "Sơn La", "group": 0, "price": 80, "coastal": false, "specialty": "Mận Mộc Châu", "landmark": "Cao nguyên Mộc Châu"},
	{"type": T.PROVINCE, "name": "Cao Bằng", "group": 1, "price": 100, "coastal": false, "specialty": "Hạt dẻ Trùng Khánh", "landmark": "Thác Bản Giốc"},
	{"type": T.INFRA, "name": "Bến Xe Khách", "price": 200},
	{"type": T.PROVINCE, "name": "Lạng Sơn", "group": 1, "price": 100, "coastal": false, "specialty": "Vịt quay", "landmark": "Động Tam Thanh"},
	{"type": T.PROVINCE, "name": "Tuyên Quang", "group": 1, "price": 110, "coastal": false, "specialty": "Cam sành Hàm Yên", "landmark": "Cột cờ Lũng Cú"},
	{"type": T.TAX, "name": "Thuế"},
	{"type": T.PROVINCE, "name": "Lào Cai", "group": 1, "price": 120, "coastal": false, "specialty": "Đào Sa Pa", "landmark": "Đỉnh Fansipan"},
	{"type": T.PROVINCE, "name": "Thái Nguyên", "group": 2, "price": 140, "coastal": false, "specialty": "Chè Tân Cương", "landmark": "Hồ Núi Cốc"},
	{"type": T.CO_HOI, "name": "Cơ Hội"},
	{"type": T.JAIL, "name": "Kẹt Xe"},
	{"type": T.PROVINCE, "name": "Phú Thọ", "group": 2, "price": 140, "coastal": false, "specialty": "Bưởi Đoan Hùng", "landmark": "Đền Hùng"},
	{"type": T.PROVINCE, "name": "Bắc Ninh", "group": 2, "price": 160, "coastal": false, "specialty": "Bánh phu thê", "landmark": "Chùa Dâu"},
	{"type": T.MARKET, "name": "Chợ Phiên"},
	{"type": T.PROVINCE, "name": "Hưng Yên", "group": 3, "price": 180, "coastal": true, "specialty": "Nhãn lồng", "landmark": "Phố Hiến"},
	{"type": T.PROVINCE, "name": "Ninh Bình", "group": 3, "price": 180, "coastal": true, "specialty": "Cơm cháy", "landmark": "Tràng An"},
	{"type": T.INFRA, "name": "Ga Đường Sắt", "price": 200},
	{"type": T.PROVINCE, "name": "Hải Phòng", "group": 3, "price": 200, "coastal": true, "specialty": "Bánh đa cua", "landmark": "Đảo Cát Bà"},
	{"type": T.KHI_VAN, "name": "Khí Vận"},
	{"type": T.PROVINCE, "name": "Quảng Ninh", "group": 3, "price": 220, "coastal": true, "specialty": "Chả mực", "landmark": "Vịnh Hạ Long"},
	{"type": T.PROVINCE, "name": "Thanh Hóa", "group": 4, "price": 220, "coastal": true, "specialty": "Nem chua", "landmark": "Thành nhà Hồ"},
	{"type": T.TOLL, "name": "Trạm BOT", "price": 150},
	{"type": T.PROVINCE, "name": "Nghệ An", "group": 4, "price": 220, "coastal": true, "specialty": "Cháo lươn", "landmark": "Làng Sen"},
	{"type": T.FESTIVAL, "name": "Lễ Hội"},
	{"type": T.PROVINCE, "name": "Hà Tĩnh", "group": 4, "price": 240, "coastal": true, "specialty": "Kẹo cu đơ", "landmark": "Ngã ba Đồng Lộc"},
	{"type": T.PROVINCE, "name": "Quảng Trị", "group": 5, "price": 250, "coastal": true, "specialty": "Tiêu Vĩnh Linh", "landmark": "Động Phong Nha"},
	{"type": T.LOTTERY, "name": "Xổ Số
Kiến Thiết"},
	{"type": T.PROVINCE, "name": "Huế", "group": 5, "price": 260, "coastal": true, "specialty": "Bún bò Huế", "landmark": "Đại Nội"},
	{"type": T.PROVINCE, "name": "Đà Nẵng", "group": 5, "price": 290, "coastal": true, "specialty": "Mì Quảng", "landmark": "Phố cổ Hội An"},
	{"type": T.INFRA, "name": "Cảng Biển", "price": 200},
	{"type": T.PROVINCE, "name": "Quảng Ngãi", "group": 5, "price": 270, "coastal": true, "specialty": "Tỏi Lý Sơn", "landmark": "Đảo Lý Sơn"},
	{"type": T.PROVINCE, "name": "Gia Lai", "group": 6, "price": 300, "coastal": true, "specialty": "Phở khô", "landmark": "Biển Hồ"},
	{"type": T.CO_HOI, "name": "Cơ Hội"},
	{"type": T.PROVINCE, "name": "Đắk Lắk", "group": 6, "price": 300, "coastal": true, "specialty": "Cà phê Buôn Ma Thuột", "landmark": "Gành Đá Đĩa"},
	{"type": T.PROVINCE, "name": "Lâm Đồng", "group": 6, "price": 320, "coastal": true, "specialty": "Dâu tây Đà Lạt", "landmark": "Hồ Xuân Hương"},
	{"type": T.CHARITY, "name": "Quỹ Từ Thiện"},
	{"type": T.TRAIN, "name": "Tàu
Thống Nhất"},
	{"type": T.PROVINCE, "name": "Khánh Hòa", "group": 7, "price": 330, "coastal": true, "specialty": "Yến sào", "landmark": "Tháp Bà Ponagar"},
	{"type": T.PROVINCE, "name": "Tây Ninh", "group": 7, "price": 330, "coastal": false, "specialty": "Bánh tráng phơi sương", "landmark": "Núi Bà Đen"},
	{"type": T.PROVINCE, "name": "Đồng Nai", "group": 7, "price": 350, "coastal": false, "specialty": "Bưởi Tân Triều", "landmark": "Vườn quốc gia Cát Tiên"},
	{"type": T.KHI_VAN, "name": "Khí Vận"},
	{"type": T.PROVINCE, "name": "Cà Mau", "group": 8, "price": 360, "coastal": true, "specialty": "Cua Cà Mau", "landmark": "Mũi Cà Mau"},
	{"type": T.PROVINCE, "name": "An Giang", "group": 8, "price": 370, "coastal": true, "specialty": "Nước mắm Phú Quốc", "landmark": "Đảo Phú Quốc"},
	{"type": T.INFRA, "name": "Sân Bay", "price": 200},
	{"type": T.PROVINCE, "name": "Đồng Tháp", "group": 8, "price": 370, "coastal": true, "specialty": "Sen Đồng Tháp", "landmark": "Tràm Chim"},
	{"type": T.PROVINCE, "name": "Vĩnh Long", "group": 8, "price": 380, "coastal": true, "specialty": "Kẹo dừa", "landmark": "Văn Thánh Miếu"},
	{"type": T.PROVINCE, "name": "Cần Thơ", "group": 9, "price": 400, "coastal": true, "specialty": "Bánh pía", "landmark": "Chợ nổi Cái Răng"},
	{"type": T.PROVINCE, "name": "Hà Nội", "group": 9, "price": 450, "coastal": false, "specialty": "Phở Hà Nội", "landmark": "Hồ Gươm"},
	{"type": T.PROVINCE, "name": "TP. Hồ Chí Minh", "group": 9, "price": 480, "coastal": true, "specialty": "Bánh mì Sài Gòn", "landmark": "Chợ Bến Thành"},
]


static func tile(t: int) -> Dictionary:
	return TILES[t]


static func is_property(t: int) -> bool:
	var ty: int = TILES[t]["type"]
	return ty == T.PROVINCE or ty == T.INFRA or ty == T.TOLL


static func find_tile(name: String) -> int:
	for i in TILES.size():
		if TILES[i]["name"] == name:
			return i
	return -1


static func is_province(t: int) -> bool:
	return TILES[t]["type"] == T.PROVINCE


static func region_of(t: int) -> int:
	return GROUPS[TILES[t]["group"]]["region"]


static func plain_name(t: int) -> String:
	return String(TILES[t]["name"]).replace("\n", " ")


## Định dạng tiền: 12345 -> "12.345"
static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out
