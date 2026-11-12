extends SceneTree
## Kiểm thử nhanh: mở bảng Cài đặt, đổi chất lượng đồ hoạ qua cả 3 mức, không lỗi.
## Chạy: godot --path . --script res://tests/settings_smoke.gd
func _initialize() -> void:
	await process_frame
	var g: Node = root.get_node("/root/Global")
	var p: Control = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(p)
	await process_frame
	for q in [0, 1, 2]:
		g.graphics_quality = q
		g.apply_graphics()
		await process_frame
	print("SETTINGS_SMOKE ok msaa=", root.msaa_3d, " scale=", root.scaling_3d_scale)
	quit()
