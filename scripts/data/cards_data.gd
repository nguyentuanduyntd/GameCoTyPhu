class_name CardsData
extends RefCounted
## Thẻ Cơ Hội, Thẻ Kỹ Năng và Nhân vật — nội dung tự viết.

## kind: money | move_to | move_steps | jail | pay_each | collect_each | upgrade | skill | repair
## value: điểm ước lượng để bot chọn thẻ có lợi hơn.
const CHANCE := [
	{"text": "Trúng mùa vải thiều! Nhận 150.", "kind": "money", "amount": 150, "value": 150},
	{"text": "Bán hàng online chốt đơn liên tục. Nhận 100.", "kind": "money", "amount": 100, "value": 100},
	{"text": "Được thưởng Tết. Nhận 200.", "kind": "money", "amount": 200, "value": 200},
	{"text": "Nhặt được ví, trả lại người mất và được hậu tạ 50.", "kind": "money", "amount": 50, "value": 50},
	{"text": "Vé số trúng giải khuyến khích. Nhận 100.", "kind": "money", "amount": 100, "value": 100},
	{"text": "Bị phạt nguội vì vượt đèn đỏ. Nộp 80.", "kind": "money", "amount": -80, "value": -80},
	{"text": "Xe hỏng giữa đường, sửa hết 50.", "kind": "money", "amount": -50, "value": -50},
	{"text": "Đóng học phí cho con. Nộp 120.", "kind": "money", "amount": -120, "value": -120},
	{"text": "Đi khám sức khỏe định kỳ. Nộp 60.", "kind": "money", "amount": -60, "value": -60},
	{"text": "Lên Tàu Thống Nhất!", "kind": "move_to", "tile": 36, "value": 60},
	{"text": "Về Km 0 nhận lương.", "kind": "move_to", "tile": 0, "value": 200},
	{"text": "Bay ra Hà Nội công tác.", "kind": "move_to", "tile": 46, "value": 20},
	{"text": "Vào TP. Hồ Chí Minh khởi nghiệp.", "kind": "move_to", "tile": 47, "value": 20},
	{"text": "Đi dự Lễ Hội.", "kind": "move_to", "tile": 24, "value": 40},
	{"text": "Đường thông thoáng, đi tiếp 3 bước.", "kind": "move_steps", "steps": 3, "value": 10},
	{"text": "Quên đồ, quay lại 3 bước.", "kind": "move_steps", "steps": -3, "value": -10},
	{"text": "Kẹt xe giờ cao điểm!", "kind": "jail", "value": -100},
	{"text": "Lì xì cho cả nhà: trả mỗi người 30.", "kind": "pay_each", "amount": 30, "value": -90},
	{"text": "Sinh nhật bạn! Mỗi người tặng 30.", "kind": "collect_each", "amount": 30, "value": 90},
	{"text": "Thợ xây làm giúp miễn phí: nâng 1 cấp nhà ngẫu nhiên.", "kind": "upgrade", "value": 120},
	{"text": "Học được bí kíp: nhận 1 Thẻ Kỹ Năng.", "kind": "skill", "value": 110},
	{"text": "Bảo trì nhà cửa: mỗi cấp nhà tốn 20.", "kind": "repair", "amount": 20, "value": -60},
]

const SKILLS := {
	"XUC_XAC_VANG": {"name": "Xúc Xắc Vàng", "desc": "Tự chọn tổng điểm xúc xắc (2–12) cho lượt này.", "rare": true},
	"GIAI_TOA": {"name": "Giải Tỏa", "desc": "Hạ 1 cấp nhà của đối thủ (trừ Danh Thắng).", "rare": true},
	"MIEN_THUE": {"name": "Miễn Thuê", "desc": "Tự động miễn 1 lần trả tiền thuê từ 150 trở lên.", "rare": false},
	"BAO_HIEM": {"name": "Bảo Hiểm", "desc": "Tự động chống 1 lần bão hoặc bị thâu tóm.", "rare": false},
	"THOAT_KET": {"name": "Thoát Kẹt", "desc": "Tự động thoát Kẹt Xe ngay đầu lượt.", "rare": false},
}
const COMMON_SKILLS := ["MIEN_THUE", "BAO_HIEM", "THOAT_KET"]
const RARE_SKILLS := ["XUC_XAC_VANG", "GIAI_TOA"]

const CHARACTERS := [
	{"id": "xe_om", "name": "Anh Ba Xe Ôm", "desc": "Đi Tàu Thống Nhất miễn phí; phí thoát Kẹt Xe giảm 50%."},
	{"id": "tieu_thuong", "name": "Cô Tư Tiểu Thương", "desc": "Mua đất giảm 10%."},
	{"id": "tho_ho", "name": "Chú Năm Thợ Hồ", "desc": "Xây nhà giảm 15%."},
	{"id": "ngu_dan", "name": "Bác Hai Ngư Dân", "desc": "Miễn nhiễm bão 1 lần; tỉnh ven biển của bác thu thêm 10% tiền thuê."},
	{"id": "doanh_nhan", "name": "Chị Bảy Doanh Nhân", "desc": "Thâu tóm giảm 10%."},
	{"id": "hoc_sinh", "name": "Bé Na Học Sinh", "desc": "Rút Cơ Hội được xem 2 thẻ, chọn 1."},
	{"id": "nong_dan", "name": "Ông Sáu Nông Dân", "desc": "Mùa Thu đi qua Km 0 nhận thêm 100."},
	{"id": "nghe_si", "name": "Anh Út Nghệ Sĩ", "desc": "Lễ Hội nhân tiền thuê ×2,5 thay vì ×2."},
]


static func character(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]
