class_name CardsData
extends RefCounted
## Thẻ Khí Vận (may rủi, có hiệu lực ngay), thẻ Cơ Hội (lựa chọn làm ăn), Thẻ Kỹ Năng và Nhân vật.
## Nội dung dựa trên bộ thẻ của chủ dự án, đã cân bằng lại cho kinh tế của game.
##
## kind — các loại hiệu ứng mà GameEngine hiểu:
##   money            amount (+ nhận từ ngân hàng / − nộp vào Quỹ Từ Thiện)
##   money_each       amount (+ mỗi người trả bạn / − bạn trả mỗi người)
##   richest_gift     amount: người giàu nhất tặng bạn (nếu bạn giàu nhất thì ngân hàng trả một nửa)
##   pay_prev         amount: trả cho người chơi ở lượt trước bạn
##   move_steps       steps
##   move_to          tile
##   jail             vào Kẹt Xe
##   one_die          lượt sau chỉ được tung 1 viên xúc xắc
##   extra_roll       được tung thêm 1 lần sau lượt này
##   skill            card: nhận Thẻ Kỹ Năng
##   upgrade_free     nâng 1 cấp nhà ngẫu nhiên (bonus: tiền thưởng nếu không có nhà để nâng)
##   per_tile_pay     amount × số ô đang sở hữu
##   region_pay       group, amount × số tỉnh sở hữu trong nhóm
##   repair           amount × tổng cấp nhà
##   year_luck        tung 1 viên: 6 → win, 1 → −lose
##   specialty_money  nhận 1 đặc sản ngẫu nhiên + amount
##   blackout         tiền thuê toàn bàn −50% đến hết vòng
##   market_fire      mọi người mất 1 đặc sản ngẫu nhiên
##   --- Cơ Hội: cần người chơi quyết định ---
##   invest           cost, gain, turns: trả trước, nhận lại sau N lượt của bạn
##   loan             gain, cost, turns: nhận trước, trả sau N lượt
##   gamble           cost, win, need: trả cost, tung 1 viên ≥ need thì nhận win
##   dice_parity      even, odd: tung 1 viên
##   duel_richest     win, lose: đấu xúc xắc với người giàu nhất
##   duel_choose      amount: chọn 1 người đấu xúc xắc, cao hơn nhận amount
##   take_from        amount: chọn 1 người, họ trả bạn
##   swap_pos         chọn 1 người, đổi vị trí
##   buy_remote       discount, only_infra: mua 1 ô chưa có chủ ở bất kỳ đâu
##   sell_bonus       mult: bán 1 ô đất trống của bạn với giá mult × giá gốc
##   build_anywhere   discount: nâng 1 cấp nhà ở tỉnh bất kỳ của bạn
##   move_ahead       range: chọn đi tới 1 ô trong N ô phía trước
##   move_anywhere    chọn đi tới ô bất kỳ
##   move_festival    chuyển Lễ Hội về 1 tỉnh của bạn
##   bonus_tiles      amount, extra, min: nhận amount, sở hữu ≥ min ô thì nhận thêm extra
##   per_tile_gain    amount, cap
##   support_build    amount + nâng 1 cấp nhà ngẫu nhiên miễn phí
##   sell_specialties price: bán toàn bộ đặc sản
## value: điểm ước lượng để bot chọn thẻ có lợi hơn (Bé Na Học Sinh).

const KHI_VAN := [
	{"name": "Thần Tài gõ cửa", "text": "Nhặt được chiếc ví bên đường. Nhận 200.", "kind": "money", "amount": 200, "value": 200},
	{"name": "Trúng mùa lúa lớn", "text": "Ruộng lúa nhà bạn bội thu. Nhận 150.", "kind": "money", "amount": 150, "value": 150},
	{"name": "Nhặt được hũ vàng", "text": "Đào đất sau nhà phát hiện hũ vàng. Nhận 300.", "kind": "money", "amount": 300, "value": 300},
	{"name": "Được bà con thương", "text": "Bà con trong làng góp tiền giúp đỡ. Mỗi người tặng bạn 30.", "kind": "money_each", "amount": 30, "value": 120},
	{"name": "Rằm tháng Giêng đi chùa", "text": "Lên chùa cầu may, được lộc. Nhận 1 đặc sản ngẫu nhiên và 50.", "kind": "specialty_money", "amount": 50, "value": 110},
	{"name": "Đám cưới linh đình", "text": "Đi ăn cưới, chủ nhà lì xì. Nhận 100.", "kind": "money", "amount": 100, "value": 100},
	{"name": "Được tổ tiên phù hộ", "text": "May mắn liên tiếp! Đi tiếp 3 ô.", "kind": "move_steps", "steps": 3, "value": 20},
	{"name": "Gặp quý nhân", "text": "Người giàu nhất bàn tặng bạn 150. Nếu bạn là người giàu nhất, ngân hàng tặng 75.", "kind": "richest_gift", "amount": 150, "value": 150},
	{"name": "Mưa thuận gió hòa", "text": "Nhận thẻ Miễn Thuê.", "kind": "skill", "card": "MIEN_THUE", "value": 110},
	{"name": "Thần may mắn nhập vai", "text": "Được tung xúc xắc thêm một lần sau lượt này.", "kind": "extra_roll", "value": 60},
	{"name": "Xin quẻ đầu năm", "text": "Tung 1 viên xúc xắc: ra 6 nhận 400, ra 1 mất 150, số khác bình an.", "kind": "year_luck", "win": 400, "lose": 150, "value": 40},
	{"name": "Cơn sốt đất quê", "text": "Một tỉnh của bạn được nâng 1 cấp nhà miễn phí. Chưa có tỉnh nào thì nhận 100.", "kind": "upgrade_free", "bonus": 100, "value": 130},
	{"name": "Trúng thưởng hội làng", "text": "Thắng cuộc thi kéo co. Nhận 150.", "kind": "money", "amount": 150, "value": 150},
	{"name": "Sổ đỏ chính chủ", "text": "Nhận thẻ Bảo Hiểm.", "kind": "skill", "card": "BAO_HIEM", "value": 90},
	{"name": "Heo đất vỡ", "text": "Tìm thấy khoản tiết kiệm cũ. Nhận 100.", "kind": "money", "amount": 100, "value": 100},
	{"name": "Gà đẻ trứng vàng", "text": "Bán được đàn gà quý. Nhận 250.", "kind": "money", "amount": 250, "value": 250},
	{"name": "Vận đen đầu tháng", "text": "Đánh rơi tiền trên đường. Nộp 100 vào Quỹ Từ Thiện.", "kind": "money", "amount": -100, "value": -100},
	{"name": "Xe bò tuột bánh", "text": "Đứng sửa xe. Lượt sau chỉ được tung 1 viên xúc xắc.", "kind": "one_die", "value": -40},
	{"name": "Gà phá vườn hàng xóm", "text": "Bồi thường 80 cho người chơi ở lượt trước bạn.", "kind": "pay_prev", "amount": 80, "value": -80},
	{"name": "Bị thương lái ép giá", "text": "Bán nông sản lỗ. Nộp 150 vào Quỹ Từ Thiện.", "kind": "money", "amount": -150, "value": -150},
	{"name": "Lũ về miền Tây", "text": "Mỗi tỉnh Miền Tây bạn sở hữu đóng 60 tiền khắc phục.", "kind": "region_pay", "group": 8, "amount": 60, "value": -50},
	{"name": "Bị mất mùa", "text": "Mỗi ô đất bạn sở hữu đóng 30.", "kind": "per_tile_pay", "amount": 30, "value": -120},
	{"name": "Xe máy hết xăng", "text": "Dắt bộ, lùi lại 2 ô.", "kind": "move_steps", "steps": -2, "value": -20},
	{"name": "Bị gọi lên xã", "text": "Có việc phải giải trình. Vào Kẹt Xe!", "kind": "jail", "value": -100},
	{"name": "Cúp điện diện rộng", "text": "Tiền thuê toàn bàn giảm 50% đến hết vòng này.", "kind": "blackout", "value": 0},
	{"name": "Cháy chợ", "text": "Mọi người mất 1 đặc sản ngẫu nhiên.", "kind": "market_fire", "value": -20},
	{"name": "Bảo trì nhà cửa", "text": "Mỗi cấp nhà bạn đang có tốn 25.", "kind": "repair", "amount": 25, "value": -80},
	{"name": "Phạt nguội", "text": "Vượt đèn đỏ bị phạt nguội. Nộp 80 vào Quỹ Từ Thiện.", "kind": "money", "amount": -80, "value": -80},
	{"name": "Đóng học phí", "text": "Đóng học phí cho con. Nộp 120 vào Quỹ Từ Thiện.", "kind": "money", "amount": -120, "value": -120},
	{"name": "Mời cả làng ăn cỗ", "text": "Trả mỗi người chơi 40.", "kind": "money_each", "amount": -40, "value": -160},
]

const CO_HOI := [
	{"name": "Mở quán cà phê võng", "text": "Đầu tư 200, sau 2 lượt của bạn nhận về 350.", "kind": "invest", "cost": 200, "gain": 350, "turns": 2, "value": 150},
	{"name": "Nuôi cá ao làng", "text": "Bỏ vốn 150 rồi tung 1 viên: 4–6 thu về 350, 1–3 mất vốn.", "kind": "gamble", "cost": 150, "win": 350, "need": 4, "value": 25},
	{"name": "Buôn chuyến trái cây", "text": "Chuyến hàng lãi lớn. Nhận 150.", "kind": "money", "amount": 150, "value": 150},
	{"name": "Mua đất nhanh tay", "text": "Chọn 1 ô chưa có chủ ở bất kỳ đâu, mua ngay với giá giảm 20%.", "kind": "buy_remote", "discount": 0.8, "only_infra": false, "value": 160},
	{"name": "Hùn vốn làm ăn", "text": "Góp 100 rồi tung 1 viên: 4–6 thu về 250, 1–3 mất vốn.", "kind": "gamble", "cost": 100, "win": 250, "need": 4, "value": 25},
	{"name": "Thuê người trông đất", "text": "Nhận thẻ Miễn Thuê.", "kind": "skill", "card": "MIEN_THUE", "value": 110},
	{"name": "Đổi đời nhờ TikTok", "text": "Quảng bá nông sản thành công. Nhận 250.", "kind": "money", "amount": 250, "value": 250},
	{"name": "Bán hàng livestream", "text": "Mỗi người chơi chốt đơn, trả bạn 40.", "kind": "money_each", "amount": 40, "value": 160},
	{"name": "Trúng hợp đồng cung cấp gạo", "text": "Nhận 300 từ ngân hàng.", "kind": "money", "amount": 300, "value": 300},
	{"name": "Mở rộng trang trại", "text": "Nâng 1 cấp nhà ở tỉnh bất kỳ của bạn, giảm 50% chi phí.", "kind": "build_anywhere", "discount": 0.5, "value": 170},
	{"name": "Đi tắt đón đầu", "text": "Chọn đi tới 1 ô bất kỳ trong 5 ô phía trước.", "kind": "move_ahead", "range": 5, "value": 80},
	{"name": "Dời Lễ Hội", "text": "Chuyển Lễ Hội về 1 tỉnh của bạn.", "kind": "move_festival", "value": 120},
	{"name": "Mượn vốn ngân hàng", "text": "Nhận ngay 300, sau 3 lượt của bạn phải trả 400.", "kind": "loan", "gain": 300, "cost": 400, "turns": 3, "value": 10},
	{"name": "Bắt được mối hàng lớn", "text": "Nhận 150. Nếu sở hữu từ 3 ô đất trở lên, nhận thêm 150.", "kind": "bonus_tiles", "amount": 150, "extra": 150, "min": 3, "value": 220},
	{"name": "Bán đất sinh lời", "text": "Bán 1 ô đất chưa xây nhà của bạn cho ngân hàng với giá 150% giá gốc.", "kind": "sell_bonus", "mult": 1.5, "value": 60},
	{"name": "Đòi nợ cũ", "text": "Chọn 1 người chơi, người đó trả bạn 80.", "kind": "take_from", "amount": 80, "value": 80},
	{"name": "Đặc sản lên sàn", "text": "Bán toàn bộ đặc sản đang có, mỗi món 70.", "kind": "sell_specialties", "price": 70, "value": 60},
	{"name": "Gói hỗ trợ nông nghiệp", "text": "Nhận 150 và được nâng 1 cấp nhà miễn phí.", "kind": "support_build", "amount": 150, "value": 260},
	{"name": "Chuyến xe miễn phí", "text": "Đi tới bất kỳ ô nào bạn muốn.", "kind": "move_anywhere", "value": 150},
	{"name": "Bí quyết kinh doanh", "text": "Nhận thẻ Miễn Phạt.", "kind": "skill", "card": "MIEN_PHAT", "value": 100},
	{"name": "Thử vận may", "text": "Chọn 1 người đấu xúc xắc. Ai cao hơn nhận 150 từ người kia.", "kind": "duel_choose", "amount": 150, "value": 0},
	{"name": "Bảo hiểm tài sản", "text": "Nhận thẻ Bảo Hiểm.", "kind": "skill", "card": "BAO_HIEM", "value": 90},
	{"name": "Đầu tư hạ tầng", "text": "Chọn 1 ô hạ tầng hoặc Trạm BOT chưa có chủ, mua ngay với giá gốc.", "kind": "buy_remote", "discount": 1.0, "only_infra": true, "value": 90},
	{"name": "Chạy quảng cáo", "text": "Nhận 50 cho mỗi ô đất bạn sở hữu, tối đa 400.", "kind": "per_tile_gain", "amount": 50, "cap": 400, "value": 200},
	{"name": "Cơ hội vàng", "text": "Tung 1 viên: chẵn nhận 250, lẻ nhận 80.", "kind": "dice_parity", "even": 250, "odd": 80, "value": 165},
	{"name": "Thách thức đại gia", "text": "Đấu xúc xắc với người giàu nhất: thắng nhận 250 từ ngân hàng, thua trả họ 100.", "kind": "duel_richest", "win": 250, "lose": 100, "value": 60},
	{"name": "Chọn ngày lành", "text": "Nhận thẻ Xúc Xắc Vàng.", "kind": "skill", "card": "XUC_XAC_VANG", "value": 140},
	{"name": "Làm ăn xa quê", "text": "Về Km 0 nhận lương.", "kind": "move_to", "tile": 0, "value": 250},
	{"name": "Giải tỏa mặt bằng", "text": "Nhận thẻ Giải Tỏa.", "kind": "skill", "card": "GIAI_TOA", "value": 120},
	{"name": "Lật kèo phút chót", "text": "Chọn 1 người chơi, đổi vị trí của hai người trên bàn cờ.", "kind": "swap_pos", "value": 40},
]

## Các loại thẻ Cơ Hội cần người chơi quyết định, và kiểu quyết định tương ứng.
const DECISION_KINDS := {
	"invest": "confirm", "loan": "confirm", "gamble": "confirm", "duel_richest": "confirm", "sell_specialties": "confirm",
	"duel_choose": "player", "take_from": "player", "swap_pos": "player",
	"buy_remote": "tile", "sell_bonus": "tile", "build_anywhere": "tile", "move_ahead": "tile", "move_anywhere": "tile", "move_festival": "tile",
}

const SKILLS := {
	"XUC_XAC_VANG": {"name": "Xúc Xắc Vàng", "desc": "Tự chọn tổng điểm xúc xắc (2–12) cho lượt này.", "rare": true},
	"GIAI_TOA": {"name": "Giải Tỏa", "desc": "Hạ 1 cấp nhà của đối thủ (trừ Danh Thắng).", "rare": true},
	"MIEN_THUE": {"name": "Miễn Thuê", "desc": "Tự động miễn 1 lần trả tiền thuê từ 150 trở lên.", "rare": false},
	"BAO_HIEM": {"name": "Bảo Hiểm", "desc": "Tự động chống 1 lần bão hoặc bị thâu tóm.", "rare": false},
	"THOAT_KET": {"name": "Thoát Kẹt", "desc": "Tự động thoát Kẹt Xe ngay đầu lượt.", "rare": false},
	"MIEN_PHAT": {"name": "Miễn Phạt", "desc": "Tự động hủy 1 khoản phạt: Thuế hoặc thẻ Khí Vận mất tiền.", "rare": false},
}
const COMMON_SKILLS := ["MIEN_THUE", "BAO_HIEM", "THOAT_KET", "MIEN_PHAT"]
const RARE_SKILLS := ["XUC_XAC_VANG", "GIAI_TOA"]

const CHARACTERS := [
	{"id": "xe_om", "name": "Anh Ba Xe Ôm", "desc": "Đi Tàu Thống Nhất và qua Trạm BOT miễn phí; phí thoát Kẹt Xe giảm 50%."},
	{"id": "tieu_thuong", "name": "Cô Tư Tiểu Thương", "desc": "Mua đất giảm 10%."},
	{"id": "tho_ho", "name": "Chú Năm Thợ Hồ", "desc": "Xây nhà giảm 15%."},
	{"id": "ngu_dan", "name": "Bác Hai Ngư Dân", "desc": "Miễn nhiễm bão 1 lần; tỉnh ven biển của bác thu thêm 10% tiền thuê."},
	{"id": "doanh_nhan", "name": "Chị Bảy Doanh Nhân", "desc": "Thâu tóm giảm 10%."},
	{"id": "hoc_sinh", "name": "Bé Na Học Sinh", "desc": "Rút Cơ Hội được xem 2 thẻ, chọn 1."},
	{"id": "nong_dan", "name": "Ông Sáu Nông Dân", "desc": "Mùa Thu qua Km 0 nhận thêm 100; tỉnh Tây Bắc, Đông Bắc, Miền Tây của ông thu thêm 15% tiền thuê."},
	{"id": "nghe_si", "name": "Anh Út Nghệ Sĩ", "desc": "Lễ Hội nhân tiền thuê ×3 thay vì ×2."},
]


static func deck(name: String) -> Array:
	return KHI_VAN if name == "khi_van" else CO_HOI


static func card(deck_name: String, idx: int) -> Dictionary:
	return deck(deck_name)[idx]


static func character(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]
