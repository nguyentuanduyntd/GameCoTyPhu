extends Node
## Cảnh khởi động server (không màn hình):
##   godot --headless --path . -- --server [--port=8910]
## Ra Internet: cloudflared tunnel --url http://localhost:8910

func _ready() -> void:
	var port := NetUtil.DEFAULT_PORT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.substr(7))
	var server := GameServer.new()
	add_child(server)
	if not server.start(port):
		get_tree().quit(1)
		return
	# Phát luôn bản Web (nếu có thư mục web cạnh game): iPhone / máy bất kỳ cùng Wi-Fi mở trình duyệt là chơi
	var web_port := WebHost.DEFAULT_PORT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--webport="):
			web_port = int(a.substr(10))
	var dir := WebHost.find_web_dir()
	if dir != "":
		var web := WebHost.new()
		add_child(web)
		if web.start(dir, web_port):
			for ip in LanDiscovery.local_ipv4():
				print("iPhone / trình duyệt cùng Wi-Fi mở: http://%s:%d" % [ip, web_port])
	else:
		print("(Không thấy thư mục web cạnh game — chưa phát bản Web. Xuất bằng tools/build.ps1 để có.)")
	print("Mở cho bạn bè chơi qua Internet: cloudflared tunnel --url http://localhost:%d" % port)
	print("Nhấn Ctrl+C để tắt server.")
