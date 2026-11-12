# Tỷ Phú Đất Việt

Game cờ tỷ phú 3D với 34 tỉnh thành Việt Nam, làm bằng Godot 4 (miễn phí, giấy phép MIT).
Bản thiết kế đầy đủ: [docs/GDD.md](docs/GDD.md).

## Chạy game

1. Mở Godot 4.7 → **Import** → chọn file `project.godot` trong thư mục này.
2. Bấm **F5** (hoặc nút ▶ góc trên bên phải).

Điều khiển: kéo chuột trái để xoay bàn cờ, lăn chuột để phóng to/thu nhỏ (trên điện thoại: vuốt và chụm 2 ngón). Khi cần chọn ô (Tàu Thống Nhất, Lễ Hội, Giải Tỏa), bấm thẳng vào ô trên bàn cờ hoặc chọn trong danh sách.

## Cấu trúc

```
scripts/core/     Luật chơi thuần logic (GameEngine) + bot (BotAI) — dùng lại cho server online
scripts/data/     Dữ liệu bàn cờ, thẻ Cơ Hội, thẻ Kỹ Năng, nhân vật
scripts/game/     Bàn cờ 3D, xúc xắc, quân cờ, camera (game.gd nối engine với hình ảnh)
scripts/ui/       Menu chính, HUD trong ván
tests/sim.gd      Mô phỏng hàng trăm ván toàn bot để kiểm tra luật và cân bằng
docs/GDD.md       Bản thiết kế game
```

## Kiểm thử

Mô phỏng 300 ván toàn bot (kiểm tra lỗi luật, tiền âm, ván không kết thúc, tỷ lệ thắng từng nhân vật):

```bash
godot --headless --path . --script res://tests/sim.gd -- 300
```

Chạy ván toàn bot ở tốc độ x4 và tự chụp 6 ảnh màn hình (`--autotest-human` để người chơi số 1 tự bấm nút):

```bash
godot --path . -- --autotest --shot=screenshots
```

## Tiến độ

- [x] M0 — Khởi tạo project
- [x] M1 — Luật chơi + bot + bàn cờ 3D cơ bản, chơi với máy được
- [ ] M2 — Bàn cờ 3D hoàn chỉnh (mô hình danh thắng, nhân vật, hiệu ứng mùa)
- [ ] M3 — Sảnh 3D chọn nhân vật, âm thanh, cài đặt
- [ ] M4 — Online: tạo phòng bằng mã, ghép trận
- [ ] M5 — Tài khoản, leo hạng
- [ ] M6 — Tối ưu điện thoại, xuất bản Windows + Android
