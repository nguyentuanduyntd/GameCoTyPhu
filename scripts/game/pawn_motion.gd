class_name PawnMotion
extends Node
## Chuyển động quân cờ trên bàn: chuỗi cú nhảy parabol liền mạch từ ô này sang ô kia.
##  - Nhún lấy đà trước cú nhảy đầu (anticipation), kéo dài người khi bay (stretch),
##    nén người khi chạm ô rồi bật đi tiếp (squash) — tất cả tính trong cùng một tween mỗi bước,
##    nên không có tween chồng lên nhau và không bị khựng giữa các ô.
##  - Xoay người mượt theo hướng đi (kể cả khi rẽ ở góc bàn), nghiêng tới khi bật, ngả nhẹ khi đáp.
##  - Cú nhảy cuối cao và chậm hơn, đáp thẳng vào vị trí đứng cuối cùng (không trượt sau khi đáp).
##  - Độ cao nhảy nhân hệ số dáng đi của từng nghề (Character3D.GAITS).
## Là Node (thêm vào cảnh) để coroutine gắn với vòng đời node, thoát game giữa chừng không rò rỉ.

## Độ cao cú nhảy thường (m).
const HOP_HEIGHT := 0.3
## Cú nhảy cuối cao hơn bao nhiêu lần.
const FINAL_HOP_MULT := 1.7
## Cú nhảy cuối dài hơn bao nhiêu lần (thời gian).
const FINAL_HOP_TIME := 1.4
## Độ cao khi đi nhanh (đường dài / dịch chuyển).
const FAST_HOP_HEIGHT := 0.1
## Thời gian nhún lấy đà = tỉ lệ × thời gian một bước.
const ANTICIPATION := 0.45
## Phần đầu mỗi bước dùng để xoay người về hướng mới (0–1).
const TURN_PORTION := 0.45
## Nghiêng người tối đa khi bật lên (rad).
const LEAN := 0.16
## Kéo dãn khi bay / nén khi chạm ô.
const STRETCH := 0.1
const SQUASH := 0.16


## Cho quân `tok` nhảy lần lượt qua các điểm `points` (toạ độ cục bộ cùng hệ với tok.position).
## `step`: thời gian một bước (đã chia theo tốc độ ván). `on_step(i)` được gọi khi chạm điểm thứ i.
## `fast`: nhảy thấp, bỏ nhún lấy đà (dùng cho đường dài).
func hop_path(tok: Character3D, points: Array, step: float, on_step: Callable = Callable(), fast: bool = false) -> void:
	if points.is_empty() or not is_instance_valid(tok):
		return
	tok.stop_reaction()
	tok.walking = true
	if not fast:
		await tok.anticipate(step * ANTICIPATION)
	var g := tok.hop_scale()
	for i in points.size():
		if not is_instance_valid(tok):
			return
		var last := i == points.size() - 1
		var big := last and not fast
		var from: Vector3 = tok.position
		var to: Vector3 = points[i]
		var h := (FAST_HOP_HEIGHT if fast else HOP_HEIGHT) * g * (FINAL_HOP_MULT if big else 1.0)
		var dur := step * (FINAL_HOP_TIME if big else 1.0)
		var yaw0 := tok.rotation.y
		var dir := to - from
		dir.y = 0.0
		var yaw1 := atan2(dir.x, dir.z) if dir.length() > 0.01 else yaw0
		# bước đầu đã nhún lấy đà; các bước sau nén người ở đầu bước (vừa chạm ô xong bật tiếp)
		var push := 0.0 if (i == 0 and not fast) else 1.0
		var detail := 0.0 if fast else 1.0
		var tw := tok.create_tween()
		tw.tween_method(func(u: float): _pose(tok, from, to, h, u, yaw0, yaw1, push, detail), 0.0, 1.0, maxf(dur, 0.02))
		await tw.finished
		if not is_instance_valid(tok):
			return
		tok.ground_y = to.y
		if on_step.is_valid():
			on_step.call(i)
	tok.walking = false
	tok.land(1.0 if not fast else 0.45)


static func _pose(tok: Character3D, from: Vector3, to: Vector3, h: float, u: float, yaw0: float, yaw1: float, push: float, detail: float) -> void:
	var p := from.lerp(to, u)
	p.y = lerpf(from.y, to.y, u) + h * 4.0 * u * (1.0 - u)
	tok.position = p
	tok.ground_y = lerpf(from.y, to.y, u)
	tok.rotation.y = lerp_angle(yaw0, yaw1, smoothstep(0.0, TURN_PORTION, u))
	tok.lean = LEAN * (1.0 - 2.0 * u) * detail
	if tok.body_root:
		var air := sin(PI * u)
		var squash := (1.0 - smoothstep(0.0, 0.2, u)) * push
		var sy := 1.0 + (STRETCH * air - SQUASH * squash) * detail
		var sxz := 1.0 + (-STRETCH * 0.5 * air + SQUASH * 0.6 * squash) * detail
		tok.body_root.scale = Vector3(sxz, sy, sxz)


## Trượt/nhảy ngắn tới vị trí mới (xếp lại chỗ đứng trong ô, hoặc bị đưa đi xa như vào Kẹt Xe).
## Cung nhảy cao dần theo quãng đường. Trả về tween để chờ; tween cũ của quân được truyền vào để huỷ.
static func shuffle_to(tok: Character3D, target: Vector3, duration: float, old: Tween = null) -> Tween:
	if old and old.is_valid():
		old.kill()
	var from := tok.position
	var dist := from.distance_to(target)
	var h := minf(0.06 + dist * 0.12, 1.4)
	var tw := tok.create_tween()
	var dur := maxf(duration * (1.0 + minf(dist, 12.0) * 0.06), 0.02)
	tw.tween_method(func(u: float):
		var e := u * u * (3.0 - 2.0 * u)
		var p := from.lerp(target, e)
		p.y = lerpf(from.y, target.y, e) + h * 4.0 * e * (1.0 - e)
		tok.position = p
		tok.ground_y = lerpf(from.y, target.y, e), 0.0, 1.0, dur)
	return tw
