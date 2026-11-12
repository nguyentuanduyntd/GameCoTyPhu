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
	print("Mở cho bạn bè chơi qua Internet: cloudflared tunnel --url http://localhost:%d" % port)
	print("Nhấn Ctrl+C để tắt server.")
