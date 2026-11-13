# Xuất bản (Windows .exe, Android .apk)

Mọi công cụ đều miễn phí: Godot 4.7.2 + export templates (bộ khung đóng gói của Godot), và để làm bản Android thì cần Android Studio (có sẵn Android SDK và Java).

## Chuẩn bị (một lần)

1. **Export templates 4.7.2** — mở Godot → *Editor → Manage Export Templates → Download and Install* (khoảng 1,3 GB), hoặc tải `Godot_v4.7.2-stable_export_templates.tpz` từ trang phát hành chính thức và giải nén thư mục `templates` vào `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
2. **Android** (chỉ khi cần bản điện thoại): cài Android Studio (kèm Android SDK, build-tools). Trong Godot: *Editor Settings → Export → Android*, đặt *Android SDK Path* (thường là `%LOCALAPPDATA%\Android\Sdk`); *Java SDK Path* có thể để trống nếu đã đặt `JAVA_HOME` — script bên dưới tự dùng Java đi kèm Android Studio.

## Xuất bằng script

```bash
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

Kết quả nằm trong `build\` (không đưa lên Git):

| File | Dùng để |
|---|---|
| `build\windows\TyPhuDatViet.exe` | Game Windows — một file duy nhất, gửi bạn bè chạy luôn, không cần cài Godot |
| `build\windows\TyPhuDatViet.console.exe` | Bản có cửa sổ dòng lệnh (dùng cho server) |
| `build\windows\ChayServer.bat` | Bấm đúp để bật server online (cổng 8910) |
| `build\windows\HuongDanOnline.md` | Hướng dẫn chơi online |
| `build\android\TyPhuDatViet.apk` | Game Android (máy 64-bit ARM và x86_64) |
| `build\web\` (index.html, index.wasm...) | Bản Web — chơi bằng trình duyệt, kể cả Safari trên iPhone; cũng được chép vào `build\windows\web` để server phát ở cổng 8912 |

Chỉ xuất một nền tảng: thêm `-WindowsOnly`, `-AndroidOnly` hoặc `-WebOnly`. Godot ở chỗ khác: thêm `-Godot "<đường dẫn ..._console.exe>"`.

Gửi bạn bè bản Windows: nén thư mục `build\windows` thành .zip. Windows có thể hiện cảnh báo SmartScreen vì file chưa được ký số (ký số tốn phí) → bấm *More info → Run anyway*.

## Cài APK lên điện thoại

- Gửi file `.apk` qua Zalo/Drive/cáp, mở trên điện thoại, cho phép *Cài ứng dụng không rõ nguồn gốc* khi được hỏi.
- Hoặc cắm cáp (bật *Gỡ lỗi USB* trong *Tuỳ chọn nhà phát triển*) rồi:

  ```bash
  %LOCALAPPDATA%\Android\Sdk\platform-tools\adb install -r build\android\TyPhuDatViet.apk
  ```

- Yêu cầu: Android 64-bit hỗ trợ Vulkan (đa số máy từ khoảng 2018 trở lại đây). Game tự chọn chất lượng đồ hoạ *Vừa* trên điện thoại; máy yếu thì chỉnh *Thấp* trong Cài đặt.

## Cập nhật lên điện thoại của bạn mà không phải gửi file

Ghép điện thoại với máy tính **một lần**, sau đó mỗi lần sửa game chỉ cần chạy một lệnh: script xuất APK, **cài đè** lên điện thoại (giữ nguyên dữ liệu và cài đặt trong game) rồi mở game luôn.

**Cách 1 — qua Wi-Fi (Android 11 trở lên, không cần cáp):**

1. Bật *Tuỳ chọn nhà phát triển*: *Cài đặt → Giới thiệu điện thoại* → chạm 7 lần vào *Số hiệu bản tạo* (Build number).
2. *Cài đặt → Hệ thống → Tuỳ chọn nhà phát triển* → bật **Gỡ lỗi không dây** (điện thoại và máy tính cùng Wi-Fi).
3. **Ghép lần đầu**: trong *Gỡ lỗi không dây* chọn *Ghép nối thiết bị bằng mã ghép nối* → điện thoại hiện `IP:cổng` và mã 6 số. Trên máy tính chạy lệnh dưới (thay đúng IP:cổng) rồi tự gõ mã 6 số khi được hỏi:

   ```bash
   %LOCALAPPDATA%\Android\Sdk\platform-tools\adb pair 192.168.1.23:37000
   ```

4. **Mỗi lần cập nhật**: xem dòng *Địa chỉ IP và cổng* ở màn hình *Gỡ lỗi không dây* (cổng này **khác** cổng ghép, và đổi mỗi lần bật lại gỡ lỗi không dây), rồi chạy:

   ```bash
   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -AndroidOnly -Install -Phone 192.168.1.23:41235
   ```

**Cách 2 — cắm cáp USB:** bật *Gỡ lỗi USB* trong *Tuỳ chọn nhà phát triển*, cắm cáp, chấp nhận hộp *Cho phép gỡ lỗi USB?* trên điện thoại, rồi chạy (không cần `-Phone`):

```bash
powershell -ExecutionPolicy Bypass -File tools\build.ps1 -AndroidOnly -Install
```

Bạn bè vẫn cần file APK mới khi game đổi, nhất là khi chơi online (các máy phải cùng phiên bản giao thức).

## Đã kiểm tra

- Bản Windows: mở sảnh, chơi với máy, bật server bằng chính file .exe, hai bản .exe chơi online trọn ván (mã trạng thái khớp).
- Bản Android (Vulkan) **chạy được trên điện thoại thật** (cài APK gửi qua mạng).
- Bản Android trên máy ảo Pixel 9 Pro (Android 16): màn hình ngang toàn màn hình, sảnh và ván chơi hiển thị đủ, chạm để tung xúc xắc / chọn hoạt động.
- Lưu ý máy ảo Android: Vulkan của máy ảo không đưa được hình lên màn hình (màn đen, log "Couldn't present to Vulkan queue") — lỗi của máy ảo, không phải của game. Để thử trên máy ảo, xuất tạm một bản dùng OpenGL (thêm `renderer/rendering_method.mobile="gl_compatibility"` vào `project.godot`, xuất xong bỏ đi). Trên điện thoại thật nên thử bản chính trước.
- Game bật **tự chuyển sang OpenGL** khi máy không khởi tạo được Vulkan (`rendering_device/fallback_to_opengl3`), nên máy đời cũ vẫn chạy được. Nếu một máy nào đó vẫn bị màn đen, có thể cho bản Android luôn dùng OpenGL bằng dòng ở trên (đổi lại: hình kém hơn một chút).

## Khoá ký APK

Script ký APK bằng **khoá debug chuẩn** của Android (Godot cũng tự tạo khoá này, mật khẩu công khai `android`) — đủ để tự cài và gửi bạn bè; các bản sau cài đè được miễn là ký bằng cùng khoá trên cùng máy.

Muốn đưa lên Google Play thì cần **khoá riêng của bạn** (tự tạo bằng `keytool` đi kèm Java, giữ kỹ file và mật khẩu, không đưa lên Git), rồi đặt trước khi chạy script:

```bash
set GODOT_ANDROID_KEYSTORE_RELEASE_PATH=D:\khoa\typhu.keystore
set GODOT_ANDROID_KEYSTORE_RELEASE_USER=typhu
set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=mat_khau_cua_ban
```

(Google Play thu phí đăng ký tài khoản nhà phát triển một lần — không bắt buộc nếu chỉ chia sẻ APK.)

## Trên điện thoại

- Màn hình luôn nằm ngang, ẩn thanh hệ thống (toàn màn hình).
- 1 ngón kéo = xoay bàn cờ, chụm/mở 2 ngón = thu nhỏ/phóng to, chạm ô = xem thông tin.
- Nút *Back*: trong ván → về sảnh (online thì rời phòng đúng cách); ở sảnh → thoát game.
- Chơi online: nhập địa chỉ server như trên máy tính (cùng Wi-Fi: `ws://<IP máy server>:8910`; qua Internet: `wss://...trycloudflare.com`).

## Đổi phiên bản

Tăng số ở 3 chỗ trước khi xuất bản bản mới: `project.godot` (`config/version`), `export_presets.cfg` (`application/file_version`, `application/product_version`, `version/name`) và **`version/code`** của Android (số nguyên, phải tăng mỗi lần để cài đè được).
