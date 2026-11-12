# Chơi online — hướng dẫn chạy server

Chơi online hoàn toàn miễn phí: **server chính là project Godot này** chạy ở chế độ không màn hình, dùng chung luật chơi với bản offline. Không thuê máy chủ, không dịch vụ trả phí.

## 1. Bật server

Trên máy của bạn (máy sẽ làm server), mở terminal tại thư mục project:

```bash
godot --headless --path . -- --server
```

Mặc định server nghe cổng **8910**; muốn đổi cổng thì thêm `--port=9000`. Nhấn `Ctrl+C` để tắt. Server ghi nhật ký: ai tạo/vào phòng, ván bắt đầu, ai rớt mạng/vào lại.

> `godot` ở đây là đường dẫn tới file Godot của bạn, ví dụ `D:\Dowload\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.

## 2. Cho người khác kết nối

| Tình huống | Địa chỉ server nhập trong game |
|---|---|
| Thử trên cùng máy (mở 2 cửa sổ game) | `ws://localhost:8910` |
| Cùng mạng Wi-Fi / LAN | `ws://<IP máy server>:8910` (xem IP bằng `ipconfig`, ví dụ `ws://192.168.1.5:8910`) |
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

1. Ở sảnh bấm **Tạo phòng** → nhập địa chỉ server → được một **mã phòng 6 ký tự** (bấm *Sao chép mã* rồi gửi bạn bè).
2. Bạn bè bấm **Nhập mã phòng** → nhập mã + địa chỉ server.
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
| `scripts/net/net_client.gd` | Kết nối phía game (autoload `Net`), ping giữ kết nối |
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
