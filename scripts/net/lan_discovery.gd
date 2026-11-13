class_name LanDiscovery
extends RefCounted
## Tìm server Tỷ Phú Đất Việt trong cùng mạng Wi-Fi / LAN (không cần gõ địa chỉ IP).
## Máy tìm gửi một gói UDP quảng bá "hỏi"; server nào nghe thấy trả lời trực tiếp kèm danh sách phòng đang chờ.
## Hỏi–đáp (thay vì server tự phát liên tục) nên điện thoại chỉ cần GỬI quảng bá, không cần nhận quảng bá.

const PORT := 8911
const ASK := "TPDV?1"


## Địa chỉ IPv4 nội bộ của máy này (192.168.x.x, 10.x.x.x, 172.16–31.x.x).
static func local_ipv4() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.count(".") != 3 or s.begins_with("127.") or s.begins_with("169.254."):
			continue
		var p := s.split(".")
		var b := int(p[1])
		if s.begins_with("192.168.") or s.begins_with("10.") or (p[0] == "172" and b >= 16 and b <= 31):
			out.append(s)
	return out


## Địa chỉ quảng bá để hỏi: 255.255.255.255 và x.y.z.255 của từng mạng nội bộ (một số router chặn loại đầu).
static func _broadcast_targets() -> Array:
	var out: Array = ["255.255.255.255"]
	for ip in local_ipv4():
		var p := String(ip).split(".")
		out.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	return out


## Tìm trong `secs` giây. Trả về [{ip, port, name, rooms: [{code, host, seats, max}]}], mỗi server một mục.
## Gọi bằng await: `var found := await LanDiscovery.search(get_tree(), 1.5)`
static func search(tree: SceneTree, secs: float = 1.5) -> Array:
	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	if udp.bind(0) != OK:
		return []
	var found := {}
	var t := 0.0
	var resend := 0.0
	while t < secs:
		if resend <= 0.0:
			resend = 0.5
			for target in _broadcast_targets():
				udp.set_dest_address(target, PORT)
				udp.put_packet(ASK.to_utf8_buffer())
		while udp.get_available_packet_count() > 0:
			var pkt := udp.get_packet().get_string_from_utf8()
			var ip := udp.get_packet_ip()
			var msg := NetUtil.decode(pkt)
			if msg.get("t") == "tpdv" and int(msg.get("v", 0)) == NetUtil.PROTOCOL:
				# một server có nhiều card mạng sẽ trả lời nhiều lần: giữ một mục theo tên + cổng
				var key := "%s|%s" % [msg.get("name", ip), msg.get("port", 0)]
				if found.has(key):
					continue
				found[key] = {"ip": ip, "port": int(msg.get("port", NetUtil.DEFAULT_PORT)), "name": String(msg.get("name", ip)),
					"rooms": msg.get("rooms", [])}
		await tree.process_frame
		var dt := tree.root.get_process_delta_time()
		t += dt
		resend -= dt
	udp.close()
	return found.values()


## Phía server: trả lời câu hỏi tìm server. Gọi mỗi khung hình với socket đã bind PORT.
static func answer(udp: PacketPeerUDP, info: Dictionary) -> void:
	while udp.get_available_packet_count() > 0:
		var pkt := udp.get_packet().get_string_from_utf8()
		if pkt != ASK:
			continue
		var reply := info.duplicate()
		reply["t"] = "tpdv"
		reply["v"] = NetUtil.PROTOCOL
		udp.set_dest_address(udp.get_packet_ip(), udp.get_packet_port())
		udp.put_packet(NetUtil.encode(reply).to_utf8_buffer())
