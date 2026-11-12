class_name AvatarFactory
extends Node
## Chụp chân dung nhân vật MỘT lần từ chính mô hình 3D (SubViewport riêng, render 1 khung) rồi giải phóng —
## nhẹ hơn để SubViewport chạy liên tục. Kết quả là ImageTexture tĩnh dùng cho thẻ người chơi.

signal ready_avatar(pid: int, tex: Texture2D)


func make(pid: int, character: String, col: Color) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff3e0")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 25, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	var ch := Character3D.new().setup(character, col)
	ch.set_process(false)
	vp.add_child(ch)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.05, 0.78, 1.15), Vector3(0, 0.62, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img:
		ready_avatar.emit(pid, ImageTexture.create_from_image(img))
