class_name NetUtil
extends RefCounted
## Tiện ích mạng dùng chung cho server và client.

## Phiên bản giao thức: server và client phải trùng nhau mới chơi được với nhau.
const PROTOCOL := 1
const DEFAULT_PORT := 8910
## Ký tự dùng cho mã phòng: bỏ các ký tự dễ nhầm (0/O, 1/I/L, 5/S, 8/B).
const CODE_CHARS := "ACDEFGHJKMNPQRTUVWXY234679"
const CODE_LEN := 6


## JSON biến mọi số thành float (1 → 1.0). Đưa các số nguyên trở lại kiểu int (đệ quy),
## để hành động nhận qua mạng giống hệt hành động tạo tại chỗ (engine so sánh/đánh chỉ số bằng int).
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(normalize(x))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[k] = normalize(v[k])
			return d
	return v


## Đóng gói / giải gói tin nhắn JSON.
static func encode(msg: Dictionary) -> String:
	return JSON.stringify(msg)


static func decode(text: String) -> Dictionary:
	var v: Variant = JSON.parse_string(text)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return normalize(v)


static func make_code(rng: RandomNumberGenerator) -> String:
	var s := ""
	for i in CODE_LEN:
		s += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return s


## Hành động chỉ server được phép tạo (client gửi lên sẽ bị từ chối).
static func is_server_only(action: Dictionary) -> bool:
	return String(action.get("action", "")) == "skip"
