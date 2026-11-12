# Tỷ Phú Đất Việt

Game cờ tỷ phú 3D với 34 tỉnh thành Việt Nam, làm bằng Godot 4 (miễn phí, giấy phép MIT).
Bản thiết kế đầy đủ: [docs/GDD.md](docs/GDD.md).

## Chạy game

1. Mở Godot 4.7 → **Import** → chọn file `project.godot` trong thư mục này.
2. Bấm **F5** (hoặc nút ▶ góc trên bên phải).

Màn đầu tiên là **sảnh 3D**: các nhân vật đứng thành hàng ngang trên bục, nhân vật của bạn ở giữa có đèn rọi. Bấm ◀ ▶ để đổi nhân vật, chọn số đối thủ (bấm "Đổi đối thủ" để bốc lại nhân vật cho máy), độ khó, số vòng rồi bấm **CHƠI VỚI MÁY**. Nút **Cài đặt** chỉnh âm lượng nhạc/hiệu ứng, tốc độ, bóng đổ, hiệu ứng thời tiết, camera; cài đặt được lưu lại trên máy.

Điều khiển trong ván:
- Kéo chuột trái để xoay bàn cờ, lăn chuột để phóng to/thu nhỏ (trên điện thoại: vuốt và chụm 2 ngón).
- Nút **Camera: Tự động** xoay bàn cờ theo người đang đi để chữ trên ô luôn đọc xuôi; kéo chuột sẽ chuyển sang **Tự do**.
- Bấm vào một ô để xem thông tin: chủ, tiền thuê, đặc sản, danh thắng.
- Khi cần chọn ô (Tàu Thống Nhất, Lễ Hội, Giải Tỏa, thẻ Cơ Hội), bấm thẳng vào ô trên bàn cờ hoặc chọn trong danh sách.

## Cấu trúc

```
scripts/core/     Luật chơi thuần logic (GameEngine) + bot (BotAI) — dùng lại cho server online
scripts/data/     Dữ liệu bàn cờ, thẻ Cơ Hội, thẻ Kỹ Năng, nhân vật
scripts/game/     Bàn cờ 3D, bản đồ Việt Nam, nhân vật, danh thắng, xúc xắc, hiệu ứng mùa, camera
                  (game.gd nối engine với hình ảnh)
scripts/ui/       Sảnh 3D, HUD trong ván, bảng cài đặt
scripts/audio.gd  Quản lý âm thanh (autoload "Audio")
assets/audio/     Âm thanh và nhạc nền (.wav) — do tools/gen_audio.py tổng hợp
tools/            Script tạo âm thanh (Python + numpy)
tests/sim.gd      Mô phỏng hàng trăm ván toàn bot để kiểm tra luật và cân bằng
docs/GDD.md       Bản thiết kế game
```

## Âm thanh

Toàn bộ âm thanh và nhạc nền được **tổng hợp bằng code**, không dùng mẫu âm thanh bên ngoài: đàn tranh (dây gảy Karplus-Strong), đàn bầu (luyến cao độ), sáo trúc, mõ, trống, cồng chiêng trên thang âm ngũ cung. Có 3 bản nhạc: sảnh (sáo trúc, điệu Bắc), trong ván mùa Xuân/Hạ (đàn tranh, điệu Bắc), mùa Thu/Đông (đàn bầu, điệu Oán). Muốn chỉnh rồi tạo lại:

```bash
python tools/gen_audio.py
```

## Kiểm thử

Mô phỏng 300 ván toàn bot (kiểm tra lỗi luật, tiền âm, ván không kết thúc, tỷ lệ thắng từng nhân vật):

```bash
godot --headless --path . --script res://tests/sim.gd -- 300
```

Chụp sảnh 3D (`--bots=5` để xem đủ 6 người):

```bash
godot --path . -- --bots=5 --menushot=screenshots/lobby.png
```

Chạy ván toàn bot ở tốc độ x4 và tự chụp 6 ảnh màn hình (`--autotest-human` để người chơi số 1 tự bấm nút):

```bash
godot --path . -- --autotest --shot=screenshots
```

Trưng bày toàn bộ 34 danh thắng (ván không chạy), đặt camera gần một cạnh bàn cờ:

```bash
godot --path . -- --showcase --camdist=8 --camlook=8.3 --camyaw=0 --shot=screenshots
```

## Tiến độ

- [x] M0 — Khởi tạo project
- [x] M1 — Luật chơi + bot + bàn cờ 3D cơ bản, chơi với máy được
- [x] M2 — Bàn cờ 3D: bản đồ Việt Nam, 8 nhân vật, 34 danh thắng, hiệu ứng mùa/thời tiết, camera tự động
- [x] M3 — Sảnh 3D chọn nhân vật, âm thanh và nhạc ngũ cung tự tổng hợp, cài đặt lưu trên máy
- [ ] M4 — Online: tạo phòng bằng mã, ghép trận
- [ ] M5 — Tài khoản, leo hạng
- [ ] M6 — Tối ưu điện thoại, xuất bản Windows + Android
