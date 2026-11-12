# TỶ PHÚ ĐẤT VIỆT — Bản thiết kế game (GDD v0.2)

> Đã chốt ngày 12/11/2026: tên game, bàn 34 tỉnh / 48 ô, bỏ đấu giá, có thâu tóm, giới hạn vòng, bật kỹ năng nhân vật, làm bản chơi với máy trước.
> Ngày: 12/11/2026

---

## 1. Tổng quan

| Mục | Nội dung |
|---|---|
| Thể loại | Board game kinh doanh bất động sản, 3D, theo lượt |
| Nền tảng | PC (Windows) + Android. iOS để sau (xem mục 11) |
| Engine | Godot 4 (giấy phép MIT, miễn phí hoàn toàn), ngôn ngữ GDScript |
| Số người | 4–6 người / ván |
| Thời lượng mục tiêu | 20–30 phút / ván (phù hợp mobile) |
| Chủ đề | Hành trình xuyên Việt từ Bắc vào Nam, mỗi ô đất là 1 tỉnh/thành |
| Phong cách hình ảnh | Low-poly, màu tươi, chibi; bàn cờ như 1 sa bàn Việt Nam thu nhỏ |

**Điểm khác biệt chính** (so với cờ tỷ phú truyền thống và các game cùng thể loại):
1. **34 tỉnh thành theo bản đồ hành chính mới (từ 01/07/2025)**, chia theo vùng miền thật.
2. **Hệ thống Mùa & Thời tiết**: mỗi vòng đổi mùa (Tết, mùa du lịch hè, mùa lúa, bão miền Trung…) làm thay đổi giá thuê theo vùng, có hiệu ứng 3D trên bàn cờ.
3. **Đặc sản vùng miền**: trả tiền thuê ở tỉnh nào thì nhận đặc sản tỉnh đó (cơ chế "an ủi" cho người đang thua) → gom bộ đổi Thẻ Kỹ Năng.
4. **Ô góc thuần Việt**: Kẹt Xe (thay nhà tù), Lễ Hội, Tàu Thống Nhất, Khởi Hành Km0.
5. **Điều kiện thắng "Bá Chủ Ba Miền"** ngoài thắng do phá sản/hết giờ.
6. **Nhân vật có kỹ năng nội tại** (nghề nghiệp Việt: xe ôm, thợ xây, ngư dân…).

---

## 2. Bàn cờ — 48 ô

- 4 góc + 44 ô cạnh (11 ô mỗi cạnh).
- 34 ô tỉnh/thành + 4 ô Hạ Tầng + 3 ô Cơ Hội + 1 Thuế + 1 Chợ Phiên + 1 Xổ Số Kiến Thiết.
- Đi theo chiều **Bắc → Nam**, giá đất tăng dần, cuối hành trình là nhóm Siêu Đô Thị.

### 2.1. 10 nhóm vùng (thay cho "nhóm màu")

| # | Nhóm | Tỉnh/thành | Đặc sản (nhận khi trả tiền thuê) |
|---|---|---|---|
| G1 | Tây Bắc | Lai Châu, Điện Biên, Sơn La | Chè Shan tuyết, Gạo Điện Biên, Mận Mộc Châu |
| G2 | Đông Bắc | Cao Bằng, Lạng Sơn, Tuyên Quang, Lào Cai | Hạt dẻ Trùng Khánh, Vịt quay, Cam sành Hàm Yên, Đào Sa Pa |
| G3 | Trung du | Thái Nguyên, Phú Thọ, Bắc Ninh | Chè Tân Cương, Bưởi Đoan Hùng, Bánh phu thê |
| G4 | Đồng bằng & Vịnh Bắc Bộ | Hưng Yên, Ninh Bình, Hải Phòng, Quảng Ninh | Nhãn lồng, Cơm cháy, Bánh đa cua, Chả mực |
| G5 | Bắc Trung Bộ | Thanh Hóa, Nghệ An, Hà Tĩnh | Nem chua, Cháo lươn, Kẹo cu đơ |
| G6 | Miền Trung di sản | Quảng Trị, Huế, Đà Nẵng, Quảng Ngãi | Tiêu Vĩnh Linh, Bún bò Huế, Mì Quảng, Tỏi Lý Sơn |
| G7 | Tây Nguyên | Gia Lai, Đắk Lắk, Lâm Đồng | Phở khô, Cà phê, Dâu tây Đà Lạt |
| G8 | Duyên hải & Đông Nam Bộ | Khánh Hòa, Tây Ninh, Đồng Nai | Yến sào, Bánh tráng phơi sương, Bưởi Tân Triều |
| G9 | Miền Tây sông nước | Cà Mau, An Giang, Đồng Tháp, Vĩnh Long | Cua Cà Mau, Nước mắm Phú Quốc, Sen, Kẹo dừa |
| G10 | Siêu Đô Thị | Cần Thơ, Hà Nội, TP. Hồ Chí Minh | Bánh pía, Phở Hà Nội, Bánh mì Sài Gòn |

(Danh sách đặc sản sẽ rà soát lại cho chuẩn trước khi làm art.)

### 2.2. Thứ tự ô

| Ô | Nội dung | Ô | Nội dung | Ô | Nội dung | Ô | Nội dung |
|---|---|---|---|---|---|---|---|
| **0** | **KHỞI HÀNH – Km0** | **12** | **KẸT XE** | **24** | **LỄ HỘI** | **36** | **TÀU THỐNG NHẤT** |
| 1 | Lai Châu | 13 | Phú Thọ | 25 | Hà Tĩnh | 37 | Khánh Hòa |
| 2 | Điện Biên | 14 | Bắc Ninh | 26 | Quảng Trị | 38 | Tây Ninh |
| 3 | Cơ Hội | 15 | Chợ Phiên | 27 | Xổ Số Kiến Thiết | 39 | Đồng Nai |
| 4 | Sơn La | 16 | Hưng Yên | 28 | Huế | 40 | Cà Mau |
| 5 | Cao Bằng | 17 | Ninh Bình | 29 | Đà Nẵng | 41 | An Giang |
| 6 | Bến Xe Khách (Hạ tầng) | 18 | Ga Đường Sắt (Hạ tầng) | 30 | Cảng Biển (Hạ tầng) | 42 | Sân Bay (Hạ tầng) |
| 7 | Lạng Sơn | 19 | Hải Phòng | 31 | Quảng Ngãi | 43 | Đồng Tháp |
| 8 | Tuyên Quang | 20 | Cơ Hội | 32 | Gia Lai | 44 | Vĩnh Long |
| 9 | Thuế | 21 | Quảng Ninh | 33 | Cơ Hội | 45 | Cần Thơ |
| 10 | Lào Cai | 22 | Thanh Hóa | 34 | Đắk Lắk | 46 | Hà Nội |
| 11 | Thái Nguyên | 23 | Nghệ An | 35 | Lâm Đồng | 47 | TP. Hồ Chí Minh |

### 2.3. Ô góc

- **Khởi Hành – Km0**: đi qua nhận lương; dừng đúng ô nhận gấp đôi.
- **Kẹt Xe** (thay nhà tù): bị kẹt tối đa 3 lượt. Thoát bằng: tung đôi, trả "phí xe ôm", hoặc dùng thẻ. Trong lúc kẹt vẫn thu tiền thuê bình thường.
- **Lễ Hội**: chọn 1 tỉnh của mình tổ chức lễ hội → tiền thuê ×2 đến khi có lễ hội mới (chỉ 1 lễ hội tồn tại trên bàn).
- **Tàu Thống Nhất**: trả vé, lượt sau được chọn đi thẳng tới bất kỳ ô nào (đi qua Km0 vẫn nhận lương).

### 2.4. Ô đặc biệt khác

- **Hạ tầng (4 ô)**: mua được; tiền thuê tăng theo số ô hạ tầng sở hữu (1/2/3/4). Không xây nhà.
- **Cơ Hội**: rút thẻ ngẫu nhiên (bộ thẻ tự viết, ~30 thẻ). Ví dụ: "Trúng mùa vải thiều +…", "Bị phạt nguội…", "Đi Tàu Thống Nhất miễn phí", "Xây miễn phí 1 cấp".
- **Thuế**: nộp % tổng tài sản hoặc số cố định (chọn cái nhỏ hơn).
- **Chợ Phiên**: đổi bộ đặc sản lấy Thẻ Kỹ Năng, hoặc mua 1 đặc sản ngẫu nhiên.
- **Xổ Số Kiến Thiết**: mini-game: đặt cược, chọn 1 số 1–6, tung xúc xắc; trúng ×5.

---

## 3. Luật chơi cốt lõi

### 3.1. Lượt chơi
1. Tung 2 xúc xắc (animation vật lý 3D, kết quả do server/logic quyết định).
2. Đi quân, xử lý ô dừng.
3. Tung đôi → được tung tiếp; 3 lần đôi liên tiếp → vào Kẹt Xe.
4. Giới hạn thời gian mỗi lượt khi chơi online (ví dụ 20 giây; hết giờ → AI tự xử lý).

### 3.2. Đất & xây dựng
- Dừng ở tỉnh chưa ai mua → mua hoặc bỏ qua (**không đấu giá** để ván nhanh hơn trên mobile).
- **Xây khi dừng lại đúng ô của mình** (không bắt buộc sở hữu cả nhóm như luật cổ điển → ván nhanh hơn).
- 4 cấp: **Nhà cấp 4 → Nhà phố → Khách sạn → Danh Thắng**.
  - Danh Thắng chỉ xây được khi đã có Khách sạn và sở hữu ≥ 2 tỉnh trong nhóm.
  - Mỗi tỉnh có 1 mô hình danh thắng riêng (vd: Hà Nội – Hồ Gươm, Huế – Đại Nội, Quảng Ninh – Vịnh Hạ Long, Lâm Đồng – Hồ Xuân Hương…).
- **Sở hữu trọn nhóm vùng**: tiền thuê ×2 cho cả nhóm.

### 3.3. Thâu tóm
- Dừng ở đất đối thủ (sau khi trả tiền thuê) → được quyền mua lại với giá **1,5× tổng giá trị đã đầu tư**, chủ cũ buộc phải bán.
- Tỉnh có Danh Thắng **không thể bị thâu tóm**.

### 3.4. Hết tiền
- Bán nhà (½ giá) / bán đất cho ngân hàng để trả nợ.
- Không đủ trả → **phá sản**, rời ván, tài sản trả về ngân hàng.

### 3.5. Điều kiện thắng
1. **Người cuối cùng còn lại** (các người khác phá sản).
2. **Bá Chủ Ba Miền**: cùng lúc sở hữu trọn ≥ 1 nhóm miền Bắc (G1–G4), ≥ 1 nhóm miền Trung (G5–G7) và ≥ 1 nhóm miền Nam (G8–G10) → thắng ngay.
3. **Hết giờ**: hết số vòng giới hạn (vd 25 vòng hoặc 30 phút) → xếp hạng theo **tổng tài sản**.

---

## 4. Hệ thống riêng của game

### 4.1. Mùa & Thời tiết
Mỗi khi tất cả người chơi đi xong 2 lượt → đổi mùa (Xuân → Hạ → Thu → Đông → lặp lại).

| Mùa | Hiệu ứng | Hình ảnh 3D |
|---|---|---|
| Xuân – Tết | Qua Km0 nhận lương ×1,5; mọi người nhận lì xì nhỏ | Hoa đào/mai, pháo hoa |
| Hạ – Mùa du lịch | Tỉnh ven biển +50% tiền thuê | Nắng gắt, sóng biển |
| Thu – Mùa gặt | G1, G9 +50% tiền thuê | Ruộng bậc thang vàng |
| Đông – Gió mùa | Miền Bắc −30% tiền thuê | Sương mù, mưa phùn |

**Sự kiện ngẫu nhiên** (xác suất nhỏ mỗi mùa): Bão miền Trung (nhà ở G5–G6 giảm 1 cấp nếu không có thẻ Bảo Hiểm), Lũ miền Tây, Năm du lịch quốc gia (1 tỉnh ngẫu nhiên ×3)…

### 4.2. Đặc sản & Thẻ Kỹ Năng
- Mỗi lần **trả tiền thuê** ở tỉnh nào → nhận 1 đặc sản của tỉnh đó (giúp người đang bị "hút máu" có cơ hội lật kèo).
- Gom bộ → đổi Thẻ Kỹ Năng ở Chợ Phiên hoặc ngay trong lượt:
  - 3 đặc sản cùng miền → thẻ thường
  - 1 Bắc + 1 Trung + 1 Nam → thẻ hiếm
- Ví dụ Thẻ Kỹ Năng: **Xúc Xắc Vàng** (chọn tổng điểm), **Miễn Thuê** (1 lần), **Bảo Hiểm** (chống bão/thâu tóm 1 lần), **Giải Tỏa** (hạ 1 cấp nhà đối thủ), **Hoán Đổi** (đổi 1 tỉnh với đối thủ, cùng nhóm giá).
- Giữ tối đa 3 thẻ.

### 4.3. Nhân vật (8 nhân vật gốc, tự thiết kế)

| Nhân vật | Kỹ năng nội tại |
|---|---|
| Anh Ba Xe Ôm | Đi Tàu Thống Nhất miễn phí; phí thoát Kẹt Xe giảm 50% |
| Cô Tư Tiểu Thương | Mua đất giảm 10% |
| Chú Năm Thợ Hồ | Xây nhà giảm 15% |
| Bác Hai Ngư Dân | Miễn nhiễm bão 1 lần; tỉnh ven biển +10% thuê |
| Chị Bảy Doanh Nhân | Thâu tóm giảm 10% |
| Bé Na Học Sinh | Rút Cơ Hội được xem 2 chọn 1 |
| Ông Sáu Nông Dân | Mùa Thu nhận thêm lương |
| Anh Út Nghệ Sĩ | Lễ Hội ×2,5 thay vì ×2 |

> Trong Leo Hạng có thể bật "chế độ cân bằng" (tắt kỹ năng) — cần chốt.

---

## 5. Chế độ chơi

| Chế độ | Mô tả |
|---|---|
| **Chơi với máy** | Offline, 3–5 bot, độ khó Dễ / Thường / Khó |
| **Tạo phòng** | Chủ phòng nhận **mã 6 ký tự**, bạn bè nhập mã để vào. Chủ phòng bấm bắt đầu khi đủ 4–6 người (cho phép điền bot vào chỗ trống) |
| **Ghép trận** | Vào hàng chờ; đủ 6 → bắt đầu ngay; đủ 4 và chờ quá 30 giây → bắt đầu |
| **Leo hạng** | Ghép trận có tính điểm hạng, ghép theo hạng gần nhau |

---

## 6. Leo hạng

| Hạng | Bậc | Ghi chú |
|---|---|---|
| Đồng | III → II → I | Không bị trừ điểm khi thua (hạng tân thủ) |
| Sắt | III → II → I | |
| Bạc | III → II → I | |
| Vàng | III → II → I | |
| Kim Cương | III → II → I | |
| Cao Thủ | Tính theo điểm | |
| **Tối Thượng** | Top 100 server | Cập nhật bảng xếp hạng hằng ngày |

- 100 điểm / bậc. Có "khiên rớt hạng": vừa lên bậc mới thì thua không rớt ngay.
- Điểm theo thứ hạng cuối ván (sơ bộ):
  - Ván 4 người: +30 / +10 / −10 / −20
  - Ván 6 người: +35 / +20 / +5 / −5 / −15 / −25
- Hạng cao (Kim Cương trở lên) điểm trừ khi thua lớn hơn.
- Mùa giải (season) reset mềm mỗi 2–3 tháng.

---

## 7. Sảnh game (Lobby 3D)

- Nền 3D: sân khấu kiểu đình làng / phố cổ, đèn lồng.
- **Hàng ngang 4–6 bục đứng**: mỗi bục là 1 người chơi trong phòng, nhân vật 3D đứng idle, trên đầu có tên + huy hiệu hạng + trạng thái "Sẵn sàng".
- Người chơi chọn nhân vật bằng thanh cuộn (carousel) phía dưới; nhân vật trên bục của mình đổi ngay + animation chào.
- Màn hình chính: Chơi với máy / Tạo phòng / Nhập mã phòng / Ghép trận / Leo hạng / Hồ sơ / Cài đặt.

---

## 8. Âm thanh & Âm nhạc

- **Nhạc nền**: phong cách ngũ cung Việt Nam (sáo trúc, đàn tranh, đàn bầu) pha lo-fi/hiện đại. Mỗi mùa có biến tấu riêng; nhạc sảnh vui, nhạc cuối ván kịch tính hơn.
- **Hiệu ứng**: xúc xắc lăn, bước đi, tiền "ting ting", xây nhà, thâu tóm, phá sản, pháo Tết, mưa/bão, còi xe khi Kẹt Xe, tiếng tàu hỏa…
- **Giọng thông báo** (tùy chọn, làm sau): "Kẹt xe rồi!", "Thâu tóm!"…
- Âm lượng nhạc / hiệu ứng tách riêng trong Cài đặt.

---

## 9. Kỹ thuật (100% miễn phí)

| Hạng mục | Công nghệ | Chi phí |
|---|---|---|
| Engine | Godot 4 (MIT) | 0đ |
| Mô hình 3D | Blender (GPL, tự làm) + gói CC0 của Kenney, Quaternius | 0đ |
| Âm thanh | Gói CC0 (Kenney, OpenGameArt/Freesound lọc CC0) + tự soạn bằng LMMS/BeepBox | 0đ |
| Font | Be Vietnam Pro (SIL OFL, hỗ trợ tiếng Việt đầy đủ) | 0đ |
| Server online | Godot chạy headless làm server (cùng code GDScript), giao tiếp WebSocket | 0đ |
| Lưu tài khoản / hạng | SQLite trên server (addon godot-sqlite, MIT) | 0đ |
| Hosting server | Giai đoạn test: chạy trên máy bạn. Chính thức: VPS miễn phí vĩnh viễn (Oracle Cloud Always Free) | 0đ (*) |
| Quản lý mã nguồn | Git + GitHub (repo private miễn phí) | 0đ |

(*) Oracle yêu cầu thẻ để xác minh danh tính, không trừ tiền nếu chỉ dùng gói Always Free.

### Kiến trúc
```
core/        Luật chơi thuần logic (không phụ thuộc đồ họa): GameState, Rules, Cards, Bot AI
             → dùng chung cho chơi offline, bot và server online (server có quyền quyết định)
game3d/      Bàn cờ 3D, quân cờ, xúc xắc, camera, hiệu ứng mùa
ui/          Menu, sảnh, HUD, popup mua/xây/thâu tóm
net/         Client WebSocket, phòng, ghép trận
server/      Bản headless: quản lý phòng, mã phòng, hàng chờ, leo hạng, chống gian lận
data/        Bảng giá ô đất, thẻ Cơ Hội, nhân vật, mùa (JSON/Resource) → dễ cân bằng
```
- Server là bên **tung xúc xắc và tính kết quả** → người chơi không hack được kết quả (bắt buộc cho Leo Hạng).
- Đồ họa: renderer "Mobile" của Godot; tối ưu low-poly để chạy mượt trên điện thoại tầm trung.

---

## 10. Tránh vi phạm bản quyền

- **Không** dùng tên/logo/hình ảnh/âm thanh/nội dung thẻ của "Monopoly" (Hasbro), "Cờ Tỷ Phú ZingPlay", "Business Tour", "Get Rich" hay game nào khác.
- Tên game, bàn cờ, bộ thẻ, nhân vật, luật kết hợp đều **tự thiết kế**.
- Chỉ dùng tài nguyên **CC0** hoặc tự làm; mọi nguồn ghi vào `CREDITS.md`.
- Danh thắng được dựng lại bằng mô hình low-poly tự làm, không dùng ảnh chụp có bản quyền.
- Trước khi phát hành: tra cứu tên game để tránh trùng nhãn hiệu.

---

## 11. Giới hạn cần biết về "miễn phí"

| Việc | Chi phí |
|---|---|
| Xuất bản Windows, Android (file APK), đăng itch.io | Miễn phí |
| Đăng lên Google Play | 25 USD (một lần) — **tùy chọn** |
| Xuất bản iOS / App Store | Cần máy Mac + 99 USD/năm → **không nằm trong phạm vi miễn phí** |

---

## 12. Lộ trình làm

| Giai đoạn | Nội dung | Kết quả chơi được |
|---|---|---|
| M0 | Cài Godot, khởi tạo project, Git, cấu trúc thư mục | Project chạy được |
| M1 | Core luật chơi + bot AI + bàn cờ 3D đơn giản | **Chơi với máy được (bản thô)** |
| M2 | Bàn cờ 3D hoàn chỉnh: xúc xắc 3D, quân cờ, nhà/danh thắng, camera, mùa | Ván chơi đẹp mắt |
| M3 | Menu, sảnh 3D chọn nhân vật, âm thanh, cài đặt | Bản offline hoàn chỉnh |
| M4 | Server: tạo phòng bằng mã, ghép trận | Chơi online với bạn bè |
| M5 | Tài khoản, leo hạng, bảng xếp hạng | Leo hạng |
| M6 | Tối ưu mobile, xuất bản Windows + Android, cân bằng | Bản phát hành |

---

## 13. Thông số cân bằng hiện tại (sau mô phỏng 300 ván toàn bot)

| Thông số | Giá trị |
|---|---|
| Tiền khởi đầu / lương qua Km 0 | 2.000 / 200 |
| Hệ số tiền thuê theo cấp (đất trống → Danh Thắng) | 0,2 / 0,8 / 1,8 / 3,2 / 5,0 × giá đất |
| Hệ số chi phí xây từng cấp | 0,5 / 0,6 / 0,8 / 1,2 × giá đất |
| Thâu tóm | 1,5 × giá trị đầu tư |
| Đổi mùa | mỗi 2 vòng; 35% có sự kiện (bão / lũ / năm du lịch) |

Kết quả mô phỏng: không lỗi; trung bình 1,5 người phá sản mỗi ván; tỷ lệ thắng các nhân vật từ 16% đến 25% (mức trung bình kỳ vọng là khoảng 20%). Các con số nằm trong `scripts/core/game_engine.gd` và được chỉnh tiếp sau khi chơi thử.
