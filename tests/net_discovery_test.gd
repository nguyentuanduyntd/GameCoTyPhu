extends SceneTree
## Kiểm thử tìm phòng trong Wi-Fi: bật server, một client tạo phòng, rồi LanDiscovery phải thấy phòng đó.
## Chạy: godot --headless --path . --script res://tests/net_discovery_test.gd

func _initialize() -> void:
	var server := GameServer.new()
	root.add_child(server)
	if not server.start(8941):
		print("NET_DISCOVERY_TEST FAIL không mở cổng")
		quit(1)
		return
	var c := NetClient.new()
	c.player_name = "Chủ Phòng"
	c.token = "tok-d"
	root.add_child(c)
	c.connect_to("ws://127.0.0.1:8941")
	c.create_room({})
	var t0 := Time.get_ticks_msec()
	while not c.room.has("code") and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	var code: String = c.room.get("code", "")
	var found: Array = await LanDiscovery.search(self, 1.5)
	var ok := false
	for srv in found:
		print("thấy server %s (%s:%d) phòng: %s" % [srv["name"], srv["ip"], srv["port"], srv["rooms"]])
		for r in srv["rooms"]:
			if r["code"] == code and int(srv["port"]) == 8941:
				ok = true
	print("NET_DISCOVERY_TEST code=%s ok=%s ips=%s" % [code, ok, LanDiscovery.local_ipv4()])
	server.stop()
	quit(0 if ok else 1)
