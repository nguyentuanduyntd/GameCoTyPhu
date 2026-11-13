# Tỷ Phú Đất Việt

Game cờ tỷ phú 3D với 34 tỉnh thành Việt Nam, làm bằng Godot 4 (miễn phí, giấy phép MIT).
Bản thiết kế đầy đủ: [docs/GDD.md](docs/GDD.md).

## Chạy game

1. Mở Godot 4.7 → **Import** → chọn file `project.godot` trong thư mục này.
2. Bấm **F5** (hoặc nút ▶ góc trên bên phải).

Màn đầu tiên là **sảnh 3D**: các nhân vật đứng thành hàng ngang trên bục, nhân vật của bạn ở giữa có đèn rọi. Bấm ◀ ▶ để đổi nhân vật, chọn số đối thủ (bấm "Đổi đối thủ" để bốc lại nhân vật cho máy), độ khó, số vòng rồi bấm **CHƠI VỚI MÁY**. Nút **Cài đặt** chỉnh âm lượng nhạc/hiệu ứng, tốc độ, bóng đổ, hiệu ứng thời tiết, camera; cài đặt được lưu lại trên máy.

Điều khiển trong ván:
- Kéo chuột trái để xoay bàn cờ, lăn chuột để phóng to/thu nhỏ (trên điện thoại: vuốt và chụm 2 ngón).
- Đến lượt bạn: bấm nút tròn **TUNG** ở giữa đáy màn hình. Xúc xắc tung trong mâm, rồi camera chuyển xuống góc nhìn thứ nhất bám theo quân cờ và quay về toàn cảnh khi hết lượt.
- Nút **Góc nhìn: Điện ảnh / Toàn cảnh** bật/tắt camera bám quân cờ ngay trong ván. Trong Cài đặt có "Camera điện ảnh khi đi" (Tắt / Chỉ lượt của bạn / Mọi người chơi), "Toàn cảnh tự xoay theo người đang đi" và "Hiệu ứng mua đất" (Tắt / Giảm / Bật).
- Bấm vào một ô để xem thông tin: chủ, tiền thuê, đặc sản, danh thắng.
- Khi cần chọn ô (Tàu Thống Nhất, Lễ Hội, Giải Tỏa, thẻ Cơ Hội), bấm thẳng vào ô trên bàn cờ hoặc chọn trong danh sách.

## Cấu trúc

```
scripts/core/     Luật chơi thuần logic (GameEngine) + bot (BotAI) — dùng lại cho server online
scripts/net/      Online: server WebSocket, phòng chơi, client (autoload "Net") — xem docs/ONLINE.md
scripts/data/     Dữ liệu bàn cờ, thẻ, nhân vật; EconomyConfig (Resource hằng số cân bằng)
data/economy.tres Hằng số đấu giá, cấp nhà, tính cách AI — mở trong Godot Inspector để chỉnh
data/buildings/   4 loại công trình (Nhà hàng, Homestay, Chợ, Xưởng đặc sản) — giá xây, thuê, hiệu ứng
scripts/game/     Bàn cờ 3D, bản đồ Việt Nam, nhân vật, danh thắng, xúc xắc, hiệu ứng mùa, camera
                  (game.gd nối engine với hình ảnh)
scripts/ui/       Sảnh 3D, HUD trong ván, bảng cài đặt
scripts/ui/theme/ Theme gốc: bảng màu (data/ui/palette.tres), UiTheme, bộ icon vẽ bằng code
scripts/ui/hud/   Thẻ nhân vật (avatar), thanh Vòng/Mùa/Quỹ, nhật ký
scripts/ui/popup/ UiPopup (popup quyết định dùng chung), NotifyQueue (hàng đợi thông báo)
scripts/game/pawn_motion.gd  Chuyển động quân cờ (nhảy parabol, squash/stretch, xếp chỗ)
shaders/          tile (vát cạnh giả + nhiễu màu ô), water (biển gợn sóng), ground (nền cỏ)
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

Xem trọn hoạt ảnh rút một lá bài cụ thể (chỉ số lá theo `scripts/data/cards_data.gd`, thêm chỉ số thứ hai để xem cảnh chọn 1 trong 2):

```bash
godot --path . -- --carddemo=khi_van:15 --shot=screenshots
```

Xem chậm một lượt của bạn (tốc độ x1, chụp 16 ảnh cách nhau 0,55 giây):

```bash
godot --path . -- --autotest-human --speed=1 --shots=16 --every=0.55 --shot=screenshots
```

Xem panel đấu giá (Hà Nội được đem ra đấu giá ngay đầu ván, bạn tham gia):

```bash
godot --path . -- --auctiondemo --speed=1 --shots=8 --every=0.7 --shot=screenshots
```

Xem hiệu ứng mua đất (mua → xây Nhà hàng → thắng đấu giá; ván tạm dừng):

```bash
godot --path . -- --juicedemo --shot=screenshots
```

Thử các mức hiệu ứng / camera: thêm `--buyfx=0|1|2`, `--cinematic=0|1|2`, `--speed=1|2|4` vào lệnh autotest.

Xem panel chọn loại công trình (bạn vừa sở hữu Hà Nội):

```bash
godot --path . -- --pickerdemo --speed=1 --shots=1 --every=2 --shot=screenshots
```

Trưng bày công trình (mỗi tỉnh một loại × cấp, hạ tầng có chủ) và xem hoạt ảnh xây từng cấp:

```bash
godot --path . -- --typeshow --shots=1 --every=1.5 --shot=screenshots
```

```bash
godot --path . -- --builddemo --shot=screenshots
```

Chạy ván toàn bot ở tốc độ x4 và tự chụp 6 ảnh màn hình (`--autotest-human` để người chơi số 1 tự bấm nút):

```bash
godot --path . -- --autotest --shot=screenshots
```

Trưng bày toàn bộ 34 danh thắng (ván không chạy), đặt camera gần một cạnh bàn cờ:

```bash
godot --path . -- --showcase --camdist=8 --camlook=8.3 --camyaw=0 --shot=screenshots
```

Xem chuyển động quân cờ (4 quân chung ô, một quân nhảy đi rồi về, rồi các phản ứng):

```bash
godot --path . -- --motiondemo --speed=1 --shots=12 --every=0.45 --shot=screenshots
```

Thử mức chất lượng đồ hoạ: thêm `--quality=0|1|2` (Thấp / Vừa / Cao); đo FPS thật thì thêm `--disable-vsync` trước `--path`.
Kiểm tra nhanh bảng Cài đặt: `godot --path . --script res://tests/settings_smoke.gd`.

Ván ngắn để xem màn kết thúc: thêm `--rounds=1`. Cho popup quyết định hiện lâu hơn khi autotest: `--clickdelay=4`.

### Phím kiểm thử (chỉ bản debug, khi đang trong ván)

| Phím | Tác dụng |
|---|---|
| F1 | Popup mẫu, lần lượt loại thường / xui / may (Enter = nút chính, Esc = nút phụ) |
| F2 | Loạt thông báo (có thông báo trùng để thử gộp) |
| F3 | Quân đang tới lượt nhảy thử 6 ô rồi nhảy về (chỉ hình ảnh) |
| F4 | Thử vào Kẹt Xe (chỉ hình ảnh) |
| F5 | Lần lượt các phản ứng: lucky, jolt, cheer, slump, sigh, sad |
| F6 | Đổi kích thước cửa sổ 1280×720 ↔ 1920×1080 |

## Xuất bản (Windows / Android)

`powershell -ExecutionPolicy Bypass -File toolsuild.ps1` → `build\windows\TyPhuDatViet.exe` (một file, gửi bạn bè chạy luôn, kèm `ChayServer.bat` để bật server) và `buildndroid\TyPhuDatViet.apk`. Hướng dẫn đầy đủ: [docs/PUBLISH.md](docs/PUBLISH.md).

## Chơi online với bạn bè

Bật server ngay trên máy bạn (miễn phí): `godot --headless --path . -- --server`, rồi ở sảnh bấm **Tạo phòng** để lấy mã 6 ký tự gửi bạn bè; họ bấm **Nhập mã phòng**. Chơi qua Internet bằng Cloudflare Tunnel miễn phí. Hướng dẫn đầy đủ: [docs/ONLINE.md](docs/ONLINE.md).

## Tiến độ

- [x] M0 — Khởi tạo project
- [x] M1 — Luật chơi + bot + bàn cờ 3D cơ bản, chơi với máy được
- [x] M2 — Bàn cờ 3D: bản đồ Việt Nam, 8 nhân vật, 34 danh thắng, hiệu ứng mùa/thời tiết, camera tự động
- [x] M3 — Sảnh 3D chọn nhân vật, âm thanh và nhạc ngũ cung tự tổng hợp, cài đặt lưu trên máy
- [x] Thẻ Khí Vận / Cơ Hội, đấu giá, 4 loại công trình, camera điện ảnh, đánh bóng giao diện và chuyển động
- [~] M4 — Online: **tạo phòng bằng mã ✓** (server tự chạy, rớt mạng vào lại, hết giờ bỏ lượt); ghép trận ngẫu nhiên — đợt 2
- [ ] M5 — Tài khoản, leo hạng
- [~] M6 — Xuất bản Windows (.exe) + Android (.apk) ✓, điều khiển cảm ứng ✓; còn: thử trên điện thoại thật, tối ưu hiệu năng máy yếu
