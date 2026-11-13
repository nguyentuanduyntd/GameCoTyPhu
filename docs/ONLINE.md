# Chơi online — hướng dẫn chạy server

Chơi online hoàn toàn miễn phí: **server chính là project Godot này** chạy ở chế độ không màn hình, dùng chung luật chơi với bản offline. Không thuê máy chủ, không dịch vụ trả phí.

## 1. Chơi cùng Wi-Fi (máy tính + điện thoại) — không cần bật gì thêm

1. Máy chủ phòng (máy tính hoặc điện thoại) bấm **Tạo phòng** → để nguyên ô **"Máy này làm server"** → **Tạo phòng**. Game tự bật server ngay bên trong.
2. Các máy khác (cùng mạng Wi-Fi) bấm **Nhập mã phòng** → danh sách **"Phòng trong cùng Wi-Fi"** tự hiện → **chạm vào phòng** là vào. Không cần gõ địa chỉ hay mã.
3. Chủ phòng thêm máy nếu muốn, rồi bấm **BẮT ĐẦU**.

Lưu ý:
- **Tường lửa Windows**: lần đầu máy tính làm server, Windows hỏi *"Allow access?"* cho Tỷ Phú Đất Việt → chọn **Allow** (tích *Private networks*). Nếu lỡ bấm Cancel thì điện thoại sẽ không vào được: mở *Windows Security → Firewall & network protection → Allow an app through firewall* và tích cho game (hoặc cho Godot nếu chạy từ editor).
- Mạng Wi-Fi công cộng (quán cà phê, công ty) thường chặn các máy nói chuyện với nhau → dùng Wi-Fi nhà hoặc điểm phát Wi-Fi từ điện thoại.
- Không thấy phòng trong danh sách: bấm **Tìm lại**; hoặc nhập tay mã phòng + địa chỉ `ws://<IP máy chủ phòng>:8910` (IP hiện ngay trong thanh phòng của máy chủ phòng).
- Máy chủ phòng là điện thoại thì đừng chuyển sang app khác trong lúc chơi (Android tạm dừng game → ván của mọi người bị treo).

## 1b. iPhone (và máy bất kỳ có trình duyệt) — chơi bản Web, không cần cài

iPhone không cài được file như Android (Apple bắt buộc qua App Store / máy Mac), nên iPhone chơi **bản Web** bằng Safari:

1. Máy tính làm server: bấm **Tạo phòng** (để "Máy này làm server") — hoặc bấm đúp `ChayServer.bat`. Thanh phòng (hoặc cửa sổ server) hiện dòng **"iPhone / trình duyệt: mở http://<IP>:8912"**.
2. iPhone (cùng Wi-Fi) mở **Safari**, gõ đúng địa chỉ đó, chờ tải lần đầu (khoảng 40 MB), **xoay ngang** điện thoại.
3. Trên iPhone bấm **Nhập mã phòng** → danh sách phòng trên server hiện ra → chạm để vào. (Hoặc tự **Tạo phòng** — phòng nằm trên máy tính server.)

Mẹo: trong Safari bấm nút *Chia sẻ → Thêm vào MH chính* để có biểu tượng game ngoài màn hình chính. Tường lửa Windows hỏi thì chọn **Allow** (cho cả cổng web 8912).

Bản Web chỉ cần thư mục `web` nằm cạnh `TyPhuDatViet.exe` (script xuất bản tự chép vào). Đưa bản Web lên mạng (itch.io / GitHub Pages) để bạn bè ở xa mở bằng link là bước sau — khi đó chơi online qua địa chỉ `wss://` của tunnel.

## 2. Server riêng (chạy suốt, hoặc chơi qua Internet)

Bản Windows đã xuất: bấm đúp **`ChayServer.bat`**. Hoặc từ project:

```bash
godot --headless --path . -- --server
```

Mặc định cổng **8910** (thêm `--port=9000` để đổi). Nhấn `Ctrl+C` (hoặc đóng cửa sổ) để tắt. Server ghi nhật ký ai tạo/vào phòng, ván bắt đầu, ai rớt mạng/vào lại, và in sẵn các địa chỉ cho máy cùng Wi-Fi. Máy cùng Wi-Fi vẫn **tự thấy phòng** trên server này; khi tạo phòng trên chính máy chạy server, cứ để "Máy này làm server" (game tự dùng server đang chạy).

| Tình huống | Địa chỉ server nhập trong game |
|---|---|
| Cùng máy | `ws://localhost:8910` |
| Cùng mạng Wi-Fi / LAN | thường không cần (tự tìm); nhập tay: `ws://<IP máy server>:8910` |
| Qua Internet | dùng tunnel miễn phí bên dưới |

### Qua Internet bằng Cloudflare Tunnel (miễn phí, không cần tài khoản)

1. Tải `cloudflared` (bản Windows) từ trang chính thức của Cloudflare.
2. Khi server game đang chạy, mở thêm một terminal:

   ```bash
   cloudflared tunnel --url http://localhost:8910
   ```

3. Cloudflare in ra một địa chỉ dạng `https://ten-ngau-nhien.trycloudflare.com`. Trong game, mọi người nhập địa chỉ đó nhưng đổi `https://` thành **`wss://`**:
   `wss://ten-ngau-nhien.trycloudflare.com`

Địa chỉ quick tunnel đổi mỗi lần chạy lại `cloudflared`. Muốn địa chỉ cố định thì sau này có thể tạo tunnel có tên (cần tài khoản Cloudflare miễn phí) hoặc chuyển server lên một VPS miễn phí — không phải sửa code.

## 3. Trong game

1. Qua Internet: chủ phòng bấm **Tạo phòng** → **bỏ chọn** "Máy này làm server" → nhập địa chỉ `wss://...` → được **mã phòng 6 ký tự** (bấm *Sao chép mã* rồi gửi bạn bè).
2. Bạn bè bấm **Nhập mã phòng** → nhập mã + địa chỉ server → **Vào bằng mã**.
3. Ai cũng đổi nhân vật được bằng ◀ ▶ (không trùng nhau). Chủ phòng thêm/bớt máy, chọn số vòng, độ khó của máy, giờ suy nghĩ (15/30/60 giây), rồi bấm **BẮT ĐẦU**. Phòng có 2–6 chỗ.

Luật online:
- Mỗi lần tới lượt có đồng hồ (hiện trên thẻ người chơi). Đồng hồ chỉ chạy khi mọi người đã xem xong hoạt cảnh trước đó.
- **Hết giờ** → bị bỏ lượt / bỏ qua (không mua, không xây, bỏ đấu giá). **3 lần hết giờ liên tiếp → bị loại** (xử phá sản).
- **Rớt mạng**: game tự kết nối lại mỗi 3 giây và vào lại đúng chỗ cũ. Trong lúc vắng, lượt của bạn chỉ chờ 5 giây rồi bị bỏ (vẫn tính vào 3 lần).
- Thoát ra sảnh giữa ván = bỏ cuộc dần (các lượt sau bị bỏ cho tới khi bị loại).

## 4. Cách hoạt động (cho người phát triển)

- **Lockstep**: lúc bắt đầu, server gửi cùng một seed và danh sách người chơi cho mọi máy. Mỗi nước đi gửi lên server; server áp vào engine của nó để kiểm tra hợp lệ, đánh số thứ tự rồi phát cho mọi máy. Mỗi máy tự chạy engine nên ra đúng cùng chuỗi sự kiện và giữ nguyên mọi hoạt cảnh của bản offline.
- Kèm mỗi nước là mã trạng thái (`GameEngine.state_hash()`); máy nào lệch tự xin server gửi lại toàn bộ ván.
- Bot chỉ "suy nghĩ" trên server (dùng bộ ngẫu nhiên riêng `ai_rng`), các máy nhận nước đi của bot như của người.
- Server là đồng hồ: chờ các máy báo "sẵn sàng" (diễn xong, tối đa 20 giây) mới tính giờ hoặc cho bot đi.
- Giới hạn đã biết: vì mọi máy biết seed, người rành kỹ thuật có thể đoán trước xúc xắc. Chấp nhận được khi chơi với bạn bè; muốn chặn hẳn thì cho server tung xúc xắc và gửi kết quả xuống (việc của đợt sau).

| File | Vai trò |
|---|---|
| `scripts/net/net_util.gd` | Phiên bản giao thức, mã phòng, đóng/giải gói JSON (đưa số nguyên về `int`) |
| `scripts/net/game_server.gd` | Server WebSocket, định tuyến tin nhắn |
| `scripts/net/server_room.gd` | Phòng: chỗ ngồi, chủ phòng, tuỳ chọn, engine chuẩn, đồng hồ, bot, hết giờ, vào lại |
| `scripts/net/net_client.gd` | Kết nối phía game (autoload `Net`), ping giữ kết nối, bật server trong game (`start_local_server`) |
| `scripts/net/web_host.gd` | Máy chủ web tí hon phát bản Web (cổng 8912) cho iPhone / trình duyệt cùng Wi-Fi |
| `scripts/net/lan_discovery.gd` | Tìm server/phòng trong cùng Wi-Fi: máy tìm gửi UDP quảng bá cổng 8911, server trả lời kèm danh sách phòng đang chờ |
| `scripts/ui/online_connect.gd` | Hộp nhập địa chỉ server / mã phòng |
| `scripts/ui/lobby.gd` | Thanh phòng chờ, hàng nhân vật 3D theo người trong phòng |
| `scripts/game/game.gd` | Chế độ online của ván chơi (`_online_begin`, `_apply_net`, `_drain_net`...) |

Tin nhắn (JSON, trường `t` là loại):
- Client → server: `hello`, `create_room`, `join_room`, `leave_room`, `set_character`, `add_bot`, `remove_bot`, `set_options`, `start_game`, `action`, `ready`, `ping`
- Server → client: `welcome`, `room`, `start` (seed, người chơi, toàn bộ nước đã đi), `move` (số thứ tự, nước đi, mã trạng thái), `timer`, `presence`, `notice`, `reject`, `error`, `left`, `pong`

## 5. Kiểm thử

```bash
godot --headless --path . --script res://tests/net_determinism.gd -- 150
```

```bash
godot --headless --path . --script res://tests/net_server_test.gd
```

```bash
godot --headless --path . --script res://tests/net_discovery_test.gd
```

Máy chủ phòng tự làm server + máy kia tự tìm phòng trong Wi-Fi rồi vào (không cần server riêng):

```bash
godot --path . -- --netauto=hostlocal:2 --netbot --until-over
```

```bash
godot --path . -- --netauto=joinlan --netbot --until-over
```

Chạy thật hai máy tự chơi (một terminal server, hai terminal game):

```bash
godot --headless --path . -- --server --port=8920
```

```bash
godot --path . -- --netauto=host:2 --server-url=ws://127.0.0.1:8920 --netcodefile=code.txt --netbot --until-over
```

```bash
godot --path . -- --netauto=join --server-url=ws://127.0.0.1:8920 --netcodefile=code.txt --netbot --until-over --netdrop=20
```

`--netidle=K`: K lần đầu tới lượt không bấm (thử hết giờ). `--netdrop=N`: giả lập rớt mạng sau nước thứ N (thử vào lại). Khi thoát, mỗi máy in dòng `AUTOTEST ... hash=...` — hai máy phải cùng mã.
