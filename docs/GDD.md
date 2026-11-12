# TỶ PHÚ ĐẤT VIỆT — Bản thiết kế game (GDD v0.3)

> Đã chốt ngày 12/11/2026: tên game, bàn 34 tỉnh / 52 ô, bỏ đấu giá, có thâu tóm, giới hạn vòng, bật kỹ năng nhân vật, làm bản chơi với máy trước. Bổ sung: Kẹt Xe 3 cách thoát + CSGT phân luồng, Trạm BOT, Quỹ Từ Thiện, Đụng độ, 2 bộ thẻ Khí Vận / Cơ Hội, đơn vị tiền "xu".
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

## 2. Bàn cờ — 52 ô

- 4 góc + 48 ô cạnh (12 ô mỗi cạnh).
- 34 ô tỉnh/thành + 14 ô đặc biệt: 4 Hạ Tầng, 3 Khí Vận, 2 Cơ Hội, 1 Thuế, 1 Trạm BOT, 1 Quỹ Từ Thiện, 1 Chợ Phiên, 1 Xổ Số Kiến Thiết.
- Đi theo chiều **Bắc → Nam**, giá đất tăng dần, cuối hành trình là nhóm Siêu Đô Thị.
- Đơn vị tiền: **xu**.

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
| **0** | **KHỞI HÀNH KM 0** | **13** | **KẸT XE** | **26** | **LỄ HỘI** | **39** | **TÀU THỐNG NHẤT** |
| 1 | Lai Châu | 14 | Phú Thọ | 27 | Hà Tĩnh | 40 | Khánh Hòa |
| 2 | Điện Biên | 15 | Bắc Ninh | 28 | Quảng Trị | 41 | Tây Ninh |
| 3 | Khí Vận | 16 | Chợ Phiên | 29 | Xổ Số Kiến Thiết | 42 | Đồng Nai |
| 4 | Sơn La | 17 | Hưng Yên | 30 | Huế | 43 | Khí Vận |
| 5 | Cao Bằng | 18 | Ninh Bình | 31 | Đà Nẵng | 44 | Cà Mau |
| 6 | Bến Xe Khách (Hạ tầng) | 19 | Ga Đường Sắt (Hạ tầng) | 32 | Cảng Biển (Hạ tầng) | 45 | An Giang |
| 7 | Lạng Sơn | 20 | Hải Phòng | 33 | Quảng Ngãi | 46 | Sân Bay (Hạ tầng) |
| 8 | Tuyên Quang | 21 | Khí Vận | 34 | Gia Lai | 47 | Đồng Tháp |
| 9 | Thuế | 22 | Quảng Ninh | 35 | Cơ Hội | 48 | Vĩnh Long |
| 10 | Lào Cai | 23 | Thanh Hóa | 36 | Đắk Lắk | 49 | Cần Thơ |
| 11 | Thái Nguyên | 24 | Trạm BOT (thu phí khi đi qua) | 37 | Lâm Đồng | 50 | Hà Nội |
| 12 | Cơ Hội | 25 | Nghệ An | 38 | Quỹ Từ Thiện | 51 | TP. Hồ Chí Minh |

### 2.3. Ô góc

- **Khởi Hành – Km 0**: đi qua nhận lương; dừng đúng ô nhận gấp đôi.
- **Kẹt Xe** (ô tù, ô 13): bị kẹt khi dừng ở đây, tung đôi 3 lần liên tiếp, hoặc rút thẻ "Bị gọi lên xã". Mỗi lượt kẹt chọn 1 trong 3 cách:
  1. **Tung tìm đôi**: ra đôi thì thoát và đi luôn. Trượt thì tính 1 lần.
  2. **Gọi xe ôm**: trả 100 (Anh Ba Xe Ôm trả 50, tiền vào Quỹ Từ Thiện), thoát rồi tung đi như thường.
  3. **Đi đường tắt**: tung 1 viên, ra chẵn thì thoát rồi tung đi như thường; ra lẻ thì lạc đường, kẹt thêm 1 lượt (không tính vào số lần trượt).
  - **CSGT phân luồng**: tung tìm đôi trượt đủ 2 lần thì được thoát miễn phí, đi theo kết quả lần tung đó.
  - Trong lúc kẹt vẫn thu tiền thuê bình thường.
- **Lễ Hội**: chọn 1 tỉnh của mình tổ chức lễ hội; tiền thuê ở đó ×2 cho đến khi có lễ hội mới (cả bàn chỉ có 1 lễ hội).
- **Tàu Thống Nhất**: lượt sau trả vé 100 để đi thẳng tới bất kỳ ô nào (đi qua Km 0 vẫn nhận lương).

### 2.4. Ô đặc biệt khác

- **Hạ tầng (4 ô)**: mua được; tiền thuê tăng theo số ô hạ tầng sở hữu: 50 / 100 / 200 / 400. Không xây nhà.
- **Trạm BOT (ô 24)**: ai **đi ngang qua** cũng mất 30. Ô này mua được với giá 150: có chủ thì tiền vào túi chủ, chưa có chủ thì tiền vào Quỹ Từ Thiện. Dừng đúng trạm của người khác thì trả 90. Đi Tàu Thống Nhất hoặc Chuyến xe miễn phí thì không mất phí.
- **Quỹ Từ Thiện (ô 38)**: mọi tiền thuế, tiền phạt, phí xe ôm, phí BOT chưa có chủ đều dồn vào quỹ giữa bàn. Ai dừng ở ô này **nhận hết quỹ**.
- **Khí Vận (3 ô)**: rút thẻ may rủi, có hiệu lực ngay (xem mục 4.5).
- **Cơ Hội (2 ô)**: rút thẻ làm ăn, người chơi được quyết định (xem mục 4.5).
- **Thuế**: nộp 10% tổng tài sản, tối đa 200, tiền vào Quỹ Từ Thiện. Thẻ Miễn Phạt hủy được khoản này.
- **Chợ Phiên**: đổi bộ đặc sản lấy Thẻ Kỹ Năng, hoặc mua 1 đặc sản ngẫu nhiên giá 60.
- **Xổ Số Kiến Thiết**: chọn 1 số từ 1 đến 6 rồi đặt cược 50 / 100 / 200; tung ra đúng số thì nhận gấp 5 tiền cược.

## 3. Luật chơi cốt lõi

### 3.1. Lượt chơi
1. Tung 2 xúc xắc (animation vật lý 3D, kết quả do server/logic quyết định).
2. Đi quân, xử lý ô dừng.
3. Tung đôi → được tung tiếp; 3 lần đôi liên tiếp → vào Kẹt Xe.
4. Giới hạn thời gian mỗi lượt khi chơi online (ví dụ 20 giây; hết giờ → AI tự xử lý).

### 3.1b. Trình diễn lượt chơi (camera điện ảnh)

Luật vẫn do engine quyết định; phần trình diễn chạy theo máy trạng thái:
`WAITING_FOR_TURN → CAMERA_TRANSITION_TO_PLAYER → WAITING_FOR_ROLL → ROLLING_DICE → SHOWING_DICE_RESULT → CAMERA_FOLLOWING_PAWN → MOVING_PAWN → LANDING_ANIMATION → PROCESSING_TILE → CAMERA_RETURNING → TURN_COMPLETE`.

- **Chờ tung:** nút tròn **TUNG** giữa đáy màn hình (viền vàng ánh kim, lòng màu người chơi, hai viên xúc xắc 3D, phát sáng nhịp nhẹ), trên có "ĐẾN LƯỢT BẠN! — Nhấn để tung xúc xắc". Rê chuột phóng to, nhấn lún xuống + vòng sóng; nhấn xong khoá. Lượt người khác: nút xám "CHỜ" + "Lượt của …".
- **Tung:** mâm gỗ lót nỉ đỏ viền vàng giữa màn hình; xúc xắc ném vào, xoay 3 trục, rơi và nảy theo trọng lực, va thành mâm, có bóng đổ và tiếng chạm; cuối cùng khớp đúng mặt kết quả của engine và hiện "3 + 4 = 7" kiểu pop-up với vòng sáng (tung đôi có thêm "ĐÔI!").
- **Đi:** camera chuyển cảnh mượt từ toàn cảnh xuống góc nhìn thứ nhất sau lưng quân cờ, nhìn về phía trước, bám theo từng bước (rung nhẹ theo bước, xoay dần ở góc bàn). Nhân vật đánh tay, đánh chân khi bước.
- **Đáp:** quân cờ nhún xuống, camera zoom vào ô, banner hiện thông tin ô → xử lý ô (mua đất, rút bài…).
- **Hết lượt:** camera nâng lên, lùi về toàn cảnh; lượt của bạn có báo "Hoàn thành lượt!".
- Nút **Góc nhìn: Điện ảnh / Toàn cảnh** trong ván để tắt camera POV bất cứ lúc nào. Cài đặt "Camera điện ảnh khi đi": Tắt / Chỉ lượt của bạn / Mọi người chơi (mặc định). Lượt của máy trình diễn nhanh hơn ×1,7.

### 3.2. Đất & xây dựng
- Dừng ở tỉnh chưa ai mua → mua đất hoặc bỏ qua. Mua xong (hoặc thắng đấu giá) thì **chọn loại công trình** (xem 3.2a). **Bỏ qua thì ô được đem ra đấu giá** cho những người còn lại (xem 3.2b).
- **Xây / nâng cấp khi dừng lại đúng ô của mình** (popup "Nâng cấp … lên Cấp X — giá …", có thể nhảy nhiều cấp nếu đủ tiền, trừ Danh Thắng).
- **3 cấp công trình** (hệ số trong `data/economy.tres`):

  | Cấp | Tên | Chi phí xây cấp đó | Tiền thuê cơ bản |
  |---|---|---|---|
  | 0 | Đất trống | — | 0,2 × giá đất |
  | 1 | Nhà nhỏ | 0,6 × giá | 1,0 × giá |
  | 2 | Nhà lớn (thêm tầng) | 0,9 × giá | 2,2 × giá |
  | 3 | **Danh Thắng** của tỉnh | 1,4 × giá | 4,5 × giá |

  Danh Thắng cần sở hữu ≥ 2 tỉnh trong vùng và không thể bị thâu tóm.
- **Hình ảnh**: có chủ là cắm **cờ màu người chơi** (phấp phới) ở góc ô; công trình **mọc lên** có nảy vượt, bụi bay, rung camera nhẹ và tiếng búa khi chạm đất; nâng cấp thì công trình cũ thu lại rồi công trình mới mọc lên (nhẹ hơn mua mới); bị hạ cấp (bão, Giải Tỏa, bán bớt) thì đổi về mô hình nhỏ hơn. Ô hạ tầng có mô hình cố định khi có chủ: xe khách + biển trạm, nhà ga + đường ray, cần cẩu + container, tháp điều khiển + máy bay, chòi thu phí BOT.
- **Sở hữu trọn nhóm vùng**: tiền thuê ×2 cho cả nhóm.

### 3.2a. Loại công trình

Sau khi sở hữu ô tỉnh (mua thường hoặc thắng đấu giá) chủ chọn 1 trong 4 loại (panel 4 thẻ, thẻ không đủ tiền mờ đi kèm lý do; **"Để sau"** giữ đất trống, quay lại ô này sẽ được chọn tiếp). Cấp 2 nâng tiếp cùng loại; cấp 3 là Danh Thắng của tỉnh (giữ hiệu ứng của loại). Số liệu trong `data/buildings/*.tres`:

| Loại | Giá xây cấp 1 / 2 / 3 | Thuê cấp 1 / 2 / 3 | Hiệu ứng riêng |
|---|---|---|---|
| **Nhà hàng** | 0,6 / 0,8 / 1,2 × giá đất | 1,0 / 2,2 / 4,5 | Thuê cao nhất; mùa Tết +20% |
| **Homestay** | 0,5 / 0,7 / 1,0 | 0,75 / 1,6 / 3,2 | Chủ qua Km 0 nhận 10% / 18% / 28% giá đất |
| **Chợ** | 0,4 / 0,6 / 0,9 | 0,6 / 1,3 / 2,6 | Người khác đi qua hoặc dừng nộp phí chợ 5% / 9% / 13% giá đất: 60% cho chủ, 40% vào Quỹ; mùa Tết +20% |
| **Xưởng đặc sản** | 0,45 / 0,65 / 0,95 | 0,5 / 1,1 / 2,2 | Đầu mỗi vòng chủ nhận 1 / 1 / 2 đặc sản của tỉnh |

- Ô chưa xây (đất trống) thu 0,2 × giá đất. Các hệ số vùng, Lễ Hội, mùa, kỹ năng nhân vật vẫn nhân thêm như cũ.
- Popup/banner trả thuê ghi rõ loại và cấp (vd. "Nhà hàng · Cấp 2 · Hà Nội"); bảng người chơi hiện "Đất · Nhà · Đặc sản".
- **Máy chọn loại** theo tính cách (`build_pref` trong `data/economy.tres`: Doanh Nhân thích Nhà hàng, Tiểu Thương thích Chợ, Nông Dân thích Xưởng, Ngư Dân thích Homestay…) và tình huống: còn nhiều vòng thì Homestay có lợi, ô ở đoạn đông người (sau Km 0, sau Kẹt Xe) thì Chợ / Nhà hàng có lợi.
- Mô phỏng 600 ván: tỉ lệ xây Nhà hàng 42%, Homestay 29%, Chợ 17%, Xưởng 12%; loại chủ đạo của người thắng gần đúng tỉ lệ đó (không loại nào lấn át); tỉ lệ thắng các nhân vật 17–24%; ~1 người phá sản mỗi ván.

### 3.2c. Hiệu ứng khoảnh khắc mua / xây

- **Mua đất**: tiếng "keng", cờ chủ cắm xuống, **xu bay theo vòng cung** từ khung người chơi ra ô, **số tiền trong HUD chạy xuống** (đỏ khi giảm, xanh khi tăng), chữ "−X" nổi trên đầu nhân vật, **camera tiến nhẹ vào ô rồi lùi lại** (đang ở góc nhìn điện ảnh thì chỉ thu FOV, không đổi chế độ; bấm nhanh liên tục chỉ kéo dài thời gian giữ, không giật).
- **Xây / nâng cấp**: công trình mọc lên có nảy vượt, bụi bay, rung màn hình rất nhẹ và tiếng búa lúc chạm đất; ít xu bay hơn, zoom ngắn hơn.
- **Thắng đấu giá**: chuông + banner "THẮNG ĐẤU GIÁ! tên — tỉnh · giá", xu bay, pháo giấy, zoom.
- **Danh Thắng / gom đủ cả vùng**: pháo giấy, pháo hoa, banner "… gom đủ vùng …! Tiền thuê cả vùng ×2".
- Cài đặt **"Hiệu ứng mua đất: Tắt / Giảm / Bật"**: Giảm = ít xu, không zoom, pháo giấy chỉ khi Danh Thắng / gom vùng; Tắt = không xu, không zoom, không pháo giấy, tiền đổi ngay.
- Mọi thời lượng chia theo tốc độ game; chuỗi hiệu ứng ~1,5–2,5 giây ở x1 và phần lớn chạy song song, không chặn lượt.

### 3.2b. Đấu giá

- Kích hoạt khi người dừng ở ô chưa có chủ (tỉnh, hạ tầng, Trạm BOT) chọn **Bỏ qua**; người vừa bỏ qua không được tham gia. Ai không đủ tiền giá khởi điểm thì đứng ngoài.
- Giá khởi điểm 50% giá niêm yết, bước giá 10% (làm tròn 5 xu). Lần lượt từng người còn trong cuộc: **trả +1 / +2 / +3 bước** hoặc **Bỏ**; không thể trả quá số xu đang có. Mỗi người trả tối đa 6 lần. Còn 1 người dẫn đầu → thắng, trả đúng giá chốt. Không ai trả giá khởi điểm → ô vẫn trống.
- Người chơi thật có **9 giây** mỗi lượt (rút ngắn theo tốc độ, tối thiểu 4 giây), hết giờ coi như bỏ. Nếu bạn không tham gia, các máy đấu giá nhanh, kết quả ghi ở nhật ký và banner.
- **Máy đấu giá theo tính cách** (`data/economy.tres`): giá trần = giá trị ước tính × hệ số tính cách × ngẫu nhiên ±10%. Giá trị ước tính xét giai đoạn ván (đầu ván đất quý hơn), số tỉnh đã có trong vùng, gom đủ vùng (×1,5), chặn đối thủ gom vùng (×1,2), hạ tầng đang có. Máy luôn giữ lại tiền an toàn (≥ 150 xu và 8% tổng tài sản, nhân hệ số tính cách).

| Nhân vật | Tính cách | Giá trần | Ghi chú |
|---|---|---|---|
| Chú Năm Thợ Hồ | Liều | ×1,25 | Hay nhảy giá, giữ ít tiền |
| Chị Bảy Doanh Nhân | Tham vọng | ×1,15 | |
| Anh Út Nghệ Sĩ | Phô trương | ×1,05 | |
| Anh Ba Xe Ôm | Lanh lẹ | ×1,0 | +30% với hạ tầng |
| Ông Sáu Nông Dân | Gom đất | ×1,0 | +60% mỗi tỉnh đã có cùng vùng |
| Cô Tư Tiểu Thương | Tính kỹ | ×0,95 | |
| Bé Na Học Sinh | Bốc đồng | ×0,9 | Ngẫu nhiên ±20% |
| Bác Hai Ngư Dân | Thủ thế | ×0,8 | Giữ tiền gấp rưỡi |

Mô phỏng 600 ván: ~9 cuộc đấu giá mỗi ván, 98% được bán, giá chốt trung bình bằng giá niêm yết; Thợ Hồ thắng đấu giá nhiều nhất, Ngư Dân ít nhất; tỉ lệ thắng ván các nhân vật vẫn trong khoảng 18–23%.

### 3.3. Thâu tóm
- Dừng ở đất đối thủ (sau khi trả tiền thuê) → được quyền mua lại với giá **1,5× tổng giá trị đã đầu tư**, chủ cũ buộc phải bán.
- Tỉnh có Danh Thắng **không thể bị thâu tóm**.

### 3.4. Hết tiền
- Bán nhà (½ giá) / bán đất cho ngân hàng để trả nợ.
- Không đủ trả → **phá sản**, rời ván, tài sản trả về ngân hàng.

### 3.5. Đụng độ

- Dừng lại ở ô đang có người khác đứng (trừ ô Kẹt Xe) thì hai người **đấu xúc xắc 1 viên**. Ai cao hơn lấy 50 của người kia; bằng nhau thì hòa. Nếu ô có nhiều người, đấu lần lượt với từng người.

### 3.6. Điều kiện thắng
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
| Anh Ba Xe Ôm | Đi Tàu Thống Nhất và qua Trạm BOT miễn phí; phí thoát Kẹt Xe giảm 50% |
| Cô Tư Tiểu Thương | Mua đất giảm 10% |
| Chú Năm Thợ Hồ | Xây nhà giảm 15% |
| Bác Hai Ngư Dân | Miễn nhiễm bão 1 lần; tỉnh ven biển +10% thuê |
| Chị Bảy Doanh Nhân | Thâu tóm giảm 10% |
| Bé Na Học Sinh | Rút Cơ Hội được xem 2 chọn 1 |
| Ông Sáu Nông Dân | Mùa Thu qua Km 0 nhận thêm 100; tỉnh Tây Bắc, Đông Bắc, Miền Tây của ông thu thêm 15% tiền thuê |
| Anh Út Nghệ Sĩ | Lễ Hội ×3 thay vì ×2 |

> Trong Leo Hạng có thể bật "chế độ cân bằng" (tắt kỹ năng) — cần chốt.

---

### 4.5. Thẻ Khí Vận và Cơ Hội

- **Khí Vận** là may rủi: rút xong có hiệu lực ngay. Bộ thẻ được cân bằng để trung bình mỗi lần rút có lợi khoảng +30.
- **Cơ Hội** là lựa chọn làm ăn: nhiều thẻ cho người chơi quyết định (đồng ý hay bỏ qua, chọn ô, chọn người). Bé Na Học Sinh được xem 2 thẻ Cơ Hội và chọn 1.
- Khoản đầu tư hoặc khoản vay có thời hạn hiện trên bảng người chơi và tự xử lý khi đến lượt.
- Thẻ "giữ lại dùng sau" chính là Thẻ Kỹ Năng, chung giới hạn tối đa 3 thẻ. Thẻ Kỹ Năng có thêm **Miễn Phạt** (hủy 1 khoản Thuế hoặc phạt Khí Vận).

**Trải nghiệm rút bài** (giống nhau cho người và máy):
1. Quân cờ dừng ô Khí Vận / Cơ Hội → **khoá lượt**, bộ bài phóng to giữa màn hình, lơ lửng và nghiêng theo phối cảnh 3D, có ánh sáng, bóng đổ, hạt lấp lánh. Khí Vận tông đỏ – vàng, lưng bài là mặt trống đồng; Cơ Hội tông xanh lá – vàng, lưng bài là đồng xu lỗ vuông và bông lúa.
2. Nút **RÚT BÀI** (có hiệu ứng rê chuột, nhấn) → bộ bài tách đôi, xen kẽ, xáo nhanh như chia bài thật → 1 lá bay ra, phóng lớn, lật mặt từ từ trên nền tia sáng.
3. Mặt bài: biểu tượng minh hoạ, tên sự kiện, mô tả, dòng hiệu ứng. Hoạt ảnh theo nội dung: nhận tiền → đồng xu bay ra; mất tiền → chớp đỏ, lá bài rung, tiền rơi; di chuyển → mũi tên đường đi và quân cờ nhảy; may mắn → pháo giấy; vận xui → mây giông, sét.
4. **Chú Ba** (người dẫn trò: áo bà ba, khăn rằn, ria mép) biểu cảm: vui mừng (nhận thưởng, may mắn), bất ngờ (cơ hội, di chuyển), buồn bã (mất tiền), hoang mang (vận xui).
5. Nút **XÁC NHẬN** → giao diện đóng mượt, **lúc này engine mới áp dụng hiệu ứng thẻ** (đúng một lần, do engine kiểm tra trạng thái chờ), cập nhật tiền, tài sản, vị trí, rồi trả lượt. Bé Na Học Sinh thấy 2 lá và bấm **CHỌN LÁ NÀY**.

**Bộ Khí Vận (30 thẻ)**

| # | Tên thẻ | Nội dung |
|---|---|---|
| 01 | Thần Tài gõ cửa | Nhặt được chiếc ví bên đường. Nhận 200. |
| 02 | Trúng mùa lúa lớn | Ruộng lúa nhà bạn bội thu. Nhận 150. |
| 03 | Nhặt được hũ vàng | Đào đất sau nhà phát hiện hũ vàng. Nhận 300. |
| 04 | Được bà con thương | Bà con trong làng góp tiền giúp đỡ. Mỗi người tặng bạn 30. |
| 05 | Rằm tháng Giêng đi chùa | Lên chùa cầu may, được lộc. Nhận 1 đặc sản ngẫu nhiên và 50. |
| 06 | Đám cưới linh đình | Đi ăn cưới, chủ nhà lì xì. Nhận 100. |
| 07 | Được tổ tiên phù hộ | May mắn liên tiếp! Đi tiếp 3 ô. |
| 08 | Gặp quý nhân | Người giàu nhất bàn tặng bạn 150. Nếu bạn là người giàu nhất, ngân hàng tặng 75. |
| 09 | Mưa thuận gió hòa | Nhận thẻ Miễn Thuê. |
| 10 | Thần may mắn nhập vai | Được tung xúc xắc thêm một lần sau lượt này. |
| 11 | Xin quẻ đầu năm | Tung 1 viên xúc xắc: ra 6 nhận 400, ra 1 mất 150, số khác bình an. |
| 12 | Cơn sốt đất quê | Một tỉnh của bạn được nâng 1 cấp nhà miễn phí. Chưa có tỉnh nào thì nhận 100. |
| 13 | Trúng thưởng hội làng | Thắng cuộc thi kéo co. Nhận 150. |
| 14 | Sổ đỏ chính chủ | Nhận thẻ Bảo Hiểm. |
| 15 | Heo đất vỡ | Tìm thấy khoản tiết kiệm cũ. Nhận 100. |
| 16 | Gà đẻ trứng vàng | Bán được đàn gà quý. Nhận 250. |
| 17 | Vận đen đầu tháng | Đánh rơi tiền trên đường. Nộp 100 vào Quỹ Từ Thiện. |
| 18 | Xe bò tuột bánh | Đứng sửa xe. Lượt sau chỉ được tung 1 viên xúc xắc. |
| 19 | Gà phá vườn hàng xóm | Bồi thường 80 cho người chơi ở lượt trước bạn. |
| 20 | Bị thương lái ép giá | Bán nông sản lỗ. Nộp 150 vào Quỹ Từ Thiện. |
| 21 | Lũ về miền Tây | Mỗi tỉnh Miền Tây bạn sở hữu đóng 60 tiền khắc phục. |
| 22 | Bị mất mùa | Mỗi ô đất bạn sở hữu đóng 30. |
| 23 | Xe máy hết xăng | Dắt bộ, lùi lại 2 ô. |
| 24 | Bị gọi lên xã | Có việc phải giải trình. Vào Kẹt Xe! |
| 25 | Cúp điện diện rộng | Tiền thuê toàn bàn giảm 50% đến hết vòng này. |
| 26 | Cháy chợ | Mọi người mất 1 đặc sản ngẫu nhiên. |
| 27 | Bảo trì nhà cửa | Mỗi cấp nhà bạn đang có tốn 25. |
| 28 | Phạt nguội | Vượt đèn đỏ bị phạt nguội. Nộp 80 vào Quỹ Từ Thiện. |
| 29 | Đóng học phí | Đóng học phí cho con. Nộp 120 vào Quỹ Từ Thiện. |
| 30 | Mời cả làng ăn cỗ | Trả mỗi người chơi 40. |

**Bộ Cơ Hội (30 thẻ)**

| # | Tên thẻ | Nội dung |
|---|---|---|
| 01 | Mở quán cà phê võng | Đầu tư 200, sau 2 lượt của bạn nhận về 350. |
| 02 | Nuôi cá ao làng | Bỏ vốn 150 rồi tung 1 viên: 4–6 thu về 350, 1–3 mất vốn. |
| 03 | Buôn chuyến trái cây | Chuyến hàng lãi lớn. Nhận 150. |
| 04 | Mua đất nhanh tay | Chọn 1 ô chưa có chủ ở bất kỳ đâu, mua ngay với giá giảm 20%. |
| 05 | Hùn vốn làm ăn | Góp 100 rồi tung 1 viên: 4–6 thu về 250, 1–3 mất vốn. |
| 06 | Thuê người trông đất | Nhận thẻ Miễn Thuê. |
| 07 | Đổi đời nhờ TikTok | Quảng bá nông sản thành công. Nhận 250. |
| 08 | Bán hàng livestream | Mỗi người chơi chốt đơn, trả bạn 40. |
| 09 | Trúng hợp đồng cung cấp gạo | Nhận 300 từ ngân hàng. |
| 10 | Mở rộng trang trại | Nâng 1 cấp nhà ở tỉnh bất kỳ của bạn, giảm 50% chi phí. |
| 11 | Đi tắt đón đầu | Chọn đi tới 1 ô bất kỳ trong 5 ô phía trước. |
| 12 | Dời Lễ Hội | Chuyển Lễ Hội về 1 tỉnh của bạn. |
| 13 | Mượn vốn ngân hàng | Nhận ngay 300, sau 3 lượt của bạn phải trả 400. |
| 14 | Bắt được mối hàng lớn | Nhận 150. Nếu sở hữu từ 3 ô đất trở lên, nhận thêm 150. |
| 15 | Bán đất sinh lời | Bán 1 ô đất chưa xây nhà của bạn cho ngân hàng với giá 150% giá gốc. |
| 16 | Đòi nợ cũ | Chọn 1 người chơi, người đó trả bạn 80. |
| 17 | Đặc sản lên sàn | Bán toàn bộ đặc sản đang có, mỗi món 70. |
| 18 | Gói hỗ trợ nông nghiệp | Nhận 150 và được nâng 1 cấp nhà miễn phí. |
| 19 | Chuyến xe miễn phí | Đi tới bất kỳ ô nào bạn muốn. |
| 20 | Bí quyết kinh doanh | Nhận thẻ Miễn Phạt. |
| 21 | Thử vận may | Chọn 1 người đấu xúc xắc. Ai cao hơn nhận 150 từ người kia. |
| 22 | Bảo hiểm tài sản | Nhận thẻ Bảo Hiểm. |
| 23 | Đầu tư hạ tầng | Chọn 1 ô hạ tầng hoặc Trạm BOT chưa có chủ, mua ngay với giá gốc. |
| 24 | Chạy quảng cáo | Nhận 50 cho mỗi ô đất bạn sở hữu, tối đa 400. |
| 25 | Cơ hội vàng | Tung 1 viên: chẵn nhận 250, lẻ nhận 80. |
| 26 | Thách thức đại gia | Đấu xúc xắc với người giàu nhất: thắng nhận 250 từ ngân hàng, thua trả họ 100. |
| 27 | Chọn ngày lành | Nhận thẻ Xúc Xắc Vàng. |
| 28 | Làm ăn xa quê | Về Km 0 nhận lương. |
| 29 | Giải tỏa mặt bằng | Nhận thẻ Giải Tỏa. |
| 30 | Lật kèo phút chót | Chọn 1 người chơi, đổi vị trí của hai người trên bàn cờ. |

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

Toàn bộ được **tổng hợp bằng code** (`tools/gen_audio.py`), không dùng mẫu âm thanh bên ngoài nên không vướng bản quyền.

- **Nhạc cụ mô phỏng**: đàn tranh (dây gảy Karplus-Strong), đàn bầu (sin có luyến cao độ và rung), sáo trúc (sin + tiếng hơi), mõ, trống, cồng chiêng.
- **Nhạc nền** (lặp liền mạch, chuyển bài mượt):
  | Bản | Dùng ở | Nhạc cụ chính | Điệu |
  |---|---|---|---|
  | music_lobby | Sảnh | Sáo trúc | Bắc (Hò Xự Xang Xê Cống), tươi sáng |
  | music_game_a | Mùa Xuân, Hạ | Đàn tranh | Bắc |
  | music_game_b | Mùa Thu, Đông | Đàn bầu | Oán, trầm lắng |
- **Hiệu ứng (18)**: xúc xắc, bước đi, tiền vào, trả tiền, mua đất, xây nhà, danh thắng (cồng chiêng), rút thẻ, còi xe Kẹt Xe, đụng độ (trống), thâu tóm, phá sản, chiến thắng, bấm nút, qua Trạm BOT, sấm (bão), pháo hoa, tới lượt bạn.
- Âm lượng nhạc và hiệu ứng chỉnh riêng trong Cài đặt.
- **Làm sau**: giọng thông báo ("Kẹt xe rồi!", "Thâu tóm!"…).

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
| M0 ✅ | Cài Godot, khởi tạo project, Git, cấu trúc thư mục | Project chạy được |
| M1 ✅ | Core luật chơi + bot AI + bàn cờ 3D đơn giản | **Chơi với máy được (bản thô)** |
| M2 ✅ | Bàn cờ 3D: bản đồ Việt Nam giữa bàn (cờ chủ sở hữu theo tỉnh, có Hoàng Sa, Trường Sa), 8 nhân vật chibi theo nghề, 34 danh thắng (11 kiểu dáng), hiệu ứng mùa/bão/cúp điện/pháo hoa Tết, camera tự xoay theo lượt, bấm ô xem thông tin | Ván chơi đẹp mắt |
| M3 ✅ | Sảnh 3D kiểu đình làng (nhân vật đứng hàng ngang trên bục, đổi nhân vật ◀ ▶, bốc lại đối thủ), 18 hiệu ứng âm thanh + 3 bản nhạc ngũ cung tự tổng hợp, bảng cài đặt lưu trên máy | Bản offline hoàn chỉnh |
| M4 | Server: tạo phòng bằng mã, ghép trận | Chơi online với bạn bè |
| M5 | Tài khoản, leo hạng, bảng xếp hạng | Leo hạng |
| M6 | Tối ưu mobile, xuất bản Windows + Android, cân bằng | Bản phát hành |

---

## 13. Thông số cân bằng hiện tại (sau mô phỏng 600 ván toàn bot)

| Thông số | Giá trị |
|---|---|
| Tiền khởi đầu / lương qua Km 0 | 2.000 / 200 xu |
| Hệ số tiền thuê theo cấp (đất trống → Danh Thắng) | 0,2 / 0,8 / 1,8 / 3,2 / 5,0 × giá đất |
| Hệ số chi phí xây từng cấp | 0,5 / 0,6 / 0,8 / 1,2 × giá đất |
| Thâu tóm | 1,5 × giá trị đầu tư |
| Trạm BOT | qua 30, dừng 90, giá mua 150 |
| Đụng độ | 50 |
| Kẹt Xe | phí xe ôm 100; CSGT phân luồng sau 2 lần trượt |
| Đổi mùa | mỗi 2 vòng; 35% có sự kiện (bão / lũ / năm du lịch) |

Kết quả mô phỏng (bàn 52 ô, 25 vòng): không lỗi; trung bình 1,3 người phá sản mỗi ván; Quỹ Từ Thiện lúc hết ván còn trung bình khoảng 160 xu. Tỷ lệ thắng của 8 nhân vật từ 18% đến 24% (mức trung bình kỳ vọng là khoảng 20%), sau khi tăng kỹ năng cho Anh Ba Xe Ôm, Ông Sáu Nông Dân và Anh Út Nghệ Sĩ. Các con số nằm trong `scripts/core/game_engine.gd` và được chỉnh tiếp sau khi chơi thử.
