class_name WebHost
extends Node
## Máy chủ web tí hon (HTTP, chỉ đọc tệp tĩnh) để phát bản Web của game trong mạng Wi-Fi:
## iPhone / máy bất kỳ mở trình duyệt vào http://<IP máy này>:8912 là chơi, không cần đưa game lên mạng.
## Chỉ phục vụ GET/HEAD các tệp trong thư mục bản Web (index.html, .js, .wasm, .pck...), không gì khác.
## Gửi dữ liệu từng phần mỗi khung hình nên không làm đứng server game đang chạy cùng.

const DEFAULT_PORT := 8912
const CHUNK := 64 * 1024
const MAX_PER_FRAME := 8 * 1024 * 1024
const MIME := {
	"html": "text/html; charset=utf-8", "js": "application/javascript", "wasm": "application/wasm",
	"pck": "application/octet-stream", "png": "image/png", "ico": "image/x-icon", "svg": "image/svg+xml",
	"json": "application/json", "css": "text/css", "txt": "text/plain; charset=utf-8",
}

var root_dir := ""
var port := DEFAULT_PORT
var _tcp := TCPServer.new()
var _clients: Array = []   # [{peer, req, file, out, head_only, idle}]


## Thư mục bản Web: "web" cạnh file game đã xuất, hoặc build/web khi chạy từ project.
static func find_web_dir() -> String:
	var cands: Array = [OS.get_executable_path().get_base_dir().path_join("web")]
	if not OS.has_feature("template"):
		cands.append(ProjectSettings.globalize_path("res://build/web"))
	for d in cands:
		if FileAccess.file_exists(String(d).path_join("index.html")):
			return d
	return ""


func start(dir: String, p: int = DEFAULT_PORT) -> bool:
	root_dir = dir
	port = p
	if _tcp.listen(port, "*") != OK:
		print("Không mở được cổng web %d." % port)
		return false
	print("Đang phát bản Web ở cổng %d." % port)
	return true


func _exit_tree() -> void:
	for c in _clients:
		_close(c)
	_clients.clear()
	_tcp.stop()


func _process(delta: float) -> void:
	while _tcp.is_connection_available():
		_clients.append({"peer": _tcp.take_connection(), "req": PackedByteArray(), "file": null,
			"out": PackedByteArray(), "head_only": false, "idle": 0.0, "responded": false})
	var budget := MAX_PER_FRAME
	for c in _clients.duplicate():
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_close(c)
			continue
		if not c["responded"]:
			var n := peer.get_available_bytes()
			if n > 0:
				var got: Array = peer.get_partial_data(n)
				var acc: PackedByteArray = c["req"]   # PackedByteArray là kiểu giá trị: nối xong phải gán lại
				acc.append_array(got[1])
				c["req"] = acc
				c["idle"] = 0.0
			var req: PackedByteArray = c["req"]
			var text := req.get_string_from_utf8()
			if text.find("\r\n\r\n") >= 0:
				_respond(c, text)
			elif req.size() > 16384:
				_close(c)
			else:
				c["idle"] = float(c["idle"]) + delta
				if float(c["idle"]) > 15.0:
					_close(c)
			continue
		budget -= _pump(c, budget)


func _respond(c: Dictionary, text: String) -> void:
	c["responded"] = true
	var first := text.get_slice("\r\n", 0).split(" ")
	if first.size() < 2 or not (first[0] == "GET" or first[0] == "HEAD"):
		_send_status(c, "405 Method Not Allowed")
		return
	c["head_only"] = first[0] == "HEAD"
	var path := first[1].get_slice("?", 0).uri_decode()
	if path == "/" or path == "":
		path = "/index.html"
	# chặn đi ra ngoài thư mục web
	if path.contains("..") or path.contains("\\") or path.contains(":"):
		_send_status(c, "403 Forbidden")
		return
	var full := root_dir.path_join(path.trim_prefix("/"))
	if not FileAccess.file_exists(full):
		_send_status(c, "404 Not Found")
		return
	var f := FileAccess.open(full, FileAccess.READ)
	if f == null:
		_send_status(c, "404 Not Found")
		return
	var ext := full.get_extension().to_lower()
	var head := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n" % [
		MIME.get(ext, "application/octet-stream"), f.get_length()]
	c["out"] = head.to_utf8_buffer()
	if c["head_only"]:
		f.close()
	else:
		c["file"] = f


func _send_status(c: Dictionary, status: String) -> void:
	var body := status.to_utf8_buffer()
	var out := ("HTTP/1.1 %s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, body.size()]).to_utf8_buffer()
	out.append_array(body)
	c["out"] = out


## Gửi tối đa `budget` byte cho một máy; trả về số byte đã gửi.
func _pump(c: Dictionary, budget: int) -> int:
	var peer: StreamPeerTCP = c["peer"]
	var sent_total := 0
	while sent_total < budget:
		var out: PackedByteArray = c["out"]
		if out.is_empty():
			var f: FileAccess = c["file"]
			if f == null:
				_close(c)   # đã gửi hết
				return sent_total
			out = f.get_buffer(CHUNK)
			if out.is_empty():
				f.close()
				c["file"] = null
				continue
			c["out"] = out
		var res: Array = peer.put_partial_data(out)
		if res[0] != OK:
			_close(c)
			return sent_total
		var sent: int = res[1]
		sent_total += sent
		c["out"] = out.slice(sent)
		if sent == 0:
			break   # bộ đệm mạng đầy: khung hình sau gửi tiếp
	return sent_total


func _close(c: Dictionary) -> void:
	var f: FileAccess = c.get("file")
	if f:
		f.close()
		c["file"] = null
	var peer: StreamPeerTCP = c["peer"]
	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		peer.disconnect_from_host()
	_clients.erase(c)
