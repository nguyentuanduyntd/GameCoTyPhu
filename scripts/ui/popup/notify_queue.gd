class_name NotifyQueue
extends VBoxContainer
## Thông báo ngắn (toast/banner): hiện ở vùng riêng phía trên-giữa, dưới thanh Vòng/Mùa, KHÔNG chặn thao tác.
## Có hàng đợi để không đè nhau, lọc trùng (cùng nội dung hoặc cùng tag thì gộp), mỗi lúc tối đa 2 thông báo.
## Loại: info (gỗ), good (lấp lánh), bad (rung nhẹ), event (to, cho sự kiện lớn).

signal item_done(id: int)

const MAX_VISIBLE := 2

var _queue: Array = []
var _showing: Array = []   # [{id, text, tag, node}]
var _next_id := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -280
	offset_right = 280
	offset_top = 66
	offset_bottom = 66
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Thêm thông báo. Trả về id (để chờ bằng `await wait(id)` nếu cần).
func push(text: String, kind: String = "info", duration: float = 1.6, tag: String = "") -> int:
	for it in _showing + _queue:
		if it["text"] == text or (tag != "" and it["tag"] == tag):
			return it["id"]
	_next_id += 1
	_queue.append({"id": _next_id, "text": text, "kind": kind, "duration": duration, "tag": tag, "node": null})
	_pump()
	return _next_id


func wait(id: int) -> void:
	while _contains(id):
		var done: int = await item_done
		if done == id:
			return


## Huỷ thông báo theo tag (vd. bảng quyết định Kẹt Xe đã mở thì bỏ toast "bị kẹt xe").
func cancel_tag(tag: String) -> void:
	for it in _queue.duplicate():
		if it["tag"] == tag:
			_queue.erase(it)
			item_done.emit(it["id"])
	for it in _showing.duplicate():
		if it["tag"] == tag:
			_hide(it)


func _contains(id: int) -> bool:
	for it in _showing + _queue:
		if it["id"] == id:
			return true
	return false


func _pump() -> void:
	while _showing.size() < MAX_VISIBLE and not _queue.is_empty():
		var it: Dictionary = _queue.pop_front()
		_show(it)


func _show(it: Dictionary) -> void:
	var pal := UiPalette.get_default()
	var panel := PanelContainer.new()
	panel.theme_type_variation = "WoodPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon: String = {"good": "star", "bad": "alert", "event": "card"}.get(it["kind"], "turn")
	var ic := TextureRect.new()
	ic.texture = UiIcons.get_icon(icon)
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := Label.new()
	l.theme_type_variation = "LightLabel"
	l.text = it["text"]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(380, 0)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_font_size_override("font_size", 20 if it["kind"] == "event" else 17)
	if it["kind"] == "good":
		l.add_theme_color_override("font_color", pal.money)
	elif it["kind"] == "bad":
		l.add_theme_color_override("font_color", Color("#ffb3a7"))
	row.add_child(l)
	add_child(panel)
	it["node"] = panel
	_showing.append(it)
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(280, 0)
	panel.scale = Vector2(0.9, 0.9)
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if it["kind"] == "bad":
		var sh := panel.create_tween()
		sh.tween_interval(0.12)
		for k in 4:
			sh.tween_property(ic, "rotation", 0.25 * (1 if k % 2 == 0 else -1), 0.05)
		sh.tween_property(ic, "rotation", 0.0, 0.05)
	elif it["kind"] == "good":
		ic.pivot_offset = Vector2(14, 14)
		var sp := panel.create_tween().set_loops(3)
		sp.tween_property(ic, "scale", Vector2.ONE * 1.3, 0.18)
		sp.tween_property(ic, "scale", Vector2.ONE, 0.18)
	get_tree().create_timer(float(it["duration"])).timeout.connect(func(): _hide(it))


func _hide(it: Dictionary) -> void:
	if not _showing.has(it):
		return
	_showing.erase(it)
	var panel: Control = it["node"]
	if is_instance_valid(panel):
		var tw := panel.create_tween()
		tw.tween_property(panel, "modulate:a", 0.0, 0.18)
		tw.tween_callback(panel.queue_free)
	item_done.emit(it["id"])
	_pump()
