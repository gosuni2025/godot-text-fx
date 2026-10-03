extends Control
## 효과 카드도 실제 TextFxPlayer 렌더 경로를 사용한다. 보이는 카드만 늦게 굽고,
## hover/키보드 포커스 때만 seek 시간을 진행한다. 비활성 카드는 대표 시점에 멈춘다.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const PlayerScene := preload("res://app/editor/popups/mini_player.tscn")
const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")

const CANVAS := Vector2i(420, 160)
const BG := Color(0.07, 0.075, 0.095, 1)
const INK := Color(0.93, 0.95, 1.0, 1)
const ACCENT := Color(0.43, 0.75, 1.0, 1)

var kind := ""        # enter | exit | hold | deco | easing
var value := ""
var active := false:
	set(v):
		if active == v:
			return
		active = v
		_t = 0.0 if v else _static_t
		_seek()
		queue_redraw()

var _player: Player = null
var _doc: Dictionary = {}
var _visibility_poll := 0.0
var _cycle := 1.0
var _t := 0.0
var _static_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visibility_changed.connect(_visibility_changed)
	resized.connect(_request_visible_player)
	_visibility_changed()


func configure(p_kind: String, p_value: String, sample: String) -> void:
	kind = p_kind
	value = p_value
	if is_instance_valid(_player):
		remove_child(_player)
		_player.queue_free()
		_player = null
	_doc = _doc_for(sample) if kind in ["enter", "exit", "hold", "deco"] else {}
	_cycle = 3.0 if kind in ["hold", "deco"] else 1.6
	match kind:
		"enter": _static_t = 0.3
		"exit": _static_t = 0.5 + 0.3
		"hold": _static_t = 0.37
		"deco": _static_t = 2.0
		_: _static_t = 1.0
	_t = _static_t
	_request_visible_player()
	queue_redraw()


func _doc_for(sample: String) -> Dictionary:
	var d := Doc.defaults()
	d["text"] = sample
	d["canvas"] = {"width": CANVAS.x, "height": CANVAS.y}
	d["layout"]["font_size"] = 72
	d["layout"]["auto_shrink"] = true
	d["layout"]["min_font_size"] = 24
	var tl: Dictionary = d["timeline"]
	tl["loop"] = "once"
	match kind:
		"enter":
			tl["enter"] = {"effect": value, "order": "forward", "duration": 0.5, "stagger": 0.09,
				"easing": "auto", "params": Enter.default_params(value)}
			tl["hold"] = {"duration": 0.8, "effects": []}
			tl["exit"]["enabled"] = false
		"exit":
			tl["enter"] = {"effect": "fade", "order": "all", "duration": 0.0, "stagger": 0.0, "easing": "linear",
				"params": {}}
			tl["hold"] = {"duration": 0.5, "effects": []}
			tl["exit"] = {"enabled": true, "effect": value, "order": "forward", "duration": 0.5, "stagger": 0.09,
				"easing": "auto", "params": Enter.default_params(value)}
		"hold", "deco":
			tl["enter"] = {"effect": "fade", "order": "all", "duration": 0.0, "stagger": 0.0, "easing": "linear",
				"params": {}}
			tl["hold"] = {"duration": 600.0, "effects": [Hold.default_params(value)] if kind == "hold" else []}
			tl["exit"]["enabled"] = false
			if kind == "deco":
				d["layout"]["font_size"] = 56
				d["decorations"] = [Doc.default_decoration(value)]
				d["decorations"][0]["thickness"] = 6.0
	if kind in ["enter", "exit"]:
		if value in ["typewriter", "erase"]:
			tl[kind]["duration"] = 0.0
			if value == "typewriter":
				tl[kind]["params"]["pop"] = 0.0
		if value == "center_split":
			tl[kind]["params"]["overlap_hold"] = 0.3
		if value == "text_morph":
			tl[kind]["order"] = "all"
			tl[kind]["stagger"] = 0.0
			tl[kind]["duration"] = 1.6
			tl[kind]["params"]["from_text"] = tr("Morph preview source")
	if kind == "hold" and value == "glow_pulse":
		d["style"]["glow"]["enabled"] = true
		d["style"]["glow"]["size"] = 16.0
	return Doc.normalize(d)


func _process(delta: float) -> void:
	_visibility_poll -= delta
	if _visibility_poll <= 0.0:
		_visibility_poll = 0.15
		_request_visible_player()
	if not active or not _on_screen():
		return
	if is_instance_valid(_player) and not _player.is_baked():
		return
	_t = fmod(_t + delta, _cycle)
	_seek()
	if kind == "easing":
		queue_redraw()


func _visibility_changed() -> void:
	set_process(is_visible_in_tree())
	if is_instance_valid(_player):
		_player.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED
	if is_visible_in_tree():
		_request_visible_player.call_deferred()


## Control.visible은 ScrollContainer의 잘린 영역을 고려하지 않으므로 조상 clip도 검사한다.
func _on_screen() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or size.x <= 1.0 or size.y <= 1.0:
		return false
	var rect := get_global_rect().intersection(get_viewport_rect())
	var parent := get_parent()
	while parent is CanvasItem:
		if parent is Control and (parent as Control).clip_contents:
			rect = rect.intersection((parent as Control).get_global_rect())
		parent = parent.get_parent()
	return rect.has_area()


func _request_visible_player() -> void:
	if _doc.is_empty() or is_instance_valid(_player) or not _on_screen():
		return
	_player = PlayerScene.instantiate() as Player
	add_child(_player)
	_player.baked.connect(_seek)
	_player.set_document(_doc)
	_cycle = maxf(0.6, _player.get_duration() + 0.5) if kind not in ["hold", "deco"] else 3.0
	if value == "center_stamp" and kind == "enter":
		_static_t = 0.1
	if value == "slam" and kind == "enter":
		_static_t = 0.22
	if value == "text_morph" and kind == "enter":
		_static_t = 0.95
	if not active:
		_t = _static_t
	_seek()


func _seek() -> void:
	if is_instance_valid(_player):
		_player.seek(_t + (0.001 if kind == "hold" else 0.0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if kind == "easing":
		_draw_easing()


func _draw_easing() -> void:
	var m := Vector2(size.x * 0.12, size.y * 0.16)
	var area := Rect2(m, size - m * 2.0)
	var lo := -0.35
	var hi := 1.35
	var to_px := func(p: float, e: float) -> Vector2:
		return Vector2(area.position.x + p * area.size.x, area.end.y - (e - lo) / (hi - lo) * area.size.y)
	var dim := Color(1, 1, 1, 0.15)
	draw_line(to_px.call(0.0, 0.0), to_px.call(1.0, 0.0), dim, 1.0)
	draw_line(to_px.call(0.0, 1.0), to_px.call(1.0, 1.0), dim, 1.0)
	var pts := PackedVector2Array()
	for i in 49:
		var p := float(i) / 48.0
		pts.append(to_px.call(p, Easing.apply(value, p)))
	draw_polyline(pts, ACCENT, 2.0, true)
	var p2 := clampf(_t / 1.2, 0.0, 1.0)
	draw_circle(to_px.call(p2, Easing.apply(value, p2)), 4.0, INK)
