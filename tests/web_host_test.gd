extends SceneTree
## Kiểm thử máy chủ web phát bản Web: GET index.html / tệp lớn / 404 / chặn đi ra ngoài thư mục.
## Cần đã xuất bản Web (build/web). Chạy: godot --headless --path . --script res://tests/web_host_test.gd

func _initialize() -> void:
	var dir := WebHost.find_web_dir()
	if dir == "":
		print("WEB_HOST_TEST SKIP (chưa có build/web)")
		quit(0)
		return
	var w := WebHost.new()
	root.add_child(w)
	if not w.start(dir, 8952):
		print("WEB_HOST_TEST FAIL listen")
		quit(1)
		return
	var fails: Array = []
	for case in [["/", 200], ["/index.wasm", 200], ["/khongco.txt", 404], ["/../project.godot", 403]]:
		var r: Array = await _http_get(case[0])
		print("%s -> %d (%d byte)" % [case[0], r[0], r[1]])
		if r[0] != case[1]:
			fails.append(case[0])
	print("WEB_HOST_TEST fails=%s" % [fails])
	quit(1 if fails.size() > 0 else 0)


func _http_get(path: String) -> Array:
	var c := StreamPeerTCP.new()
	c.connect_to_host("127.0.0.1", 8952)
	var t0 := Time.get_ticks_msec()
	while c.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() - t0 < 3000:
		c.poll()
		await process_frame
	c.put_data(("GET %s HTTP/1.1\r\nHost: x\r\n\r\n" % path).to_utf8_buffer())
	var data := PackedByteArray()
	while Time.get_ticks_msec() - t0 < 20000:
		c.poll()
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var n := c.get_available_bytes()
		if n > 0:
			data.append_array(c.get_partial_data(n)[1])
		await process_frame
	var head := data.slice(0, mini(data.size(), 200)).get_string_from_utf8()
	var code := int(head.get_slice(" ", 1)) if head.begins_with("HTTP/") else 0
	return [code, data.size()]
