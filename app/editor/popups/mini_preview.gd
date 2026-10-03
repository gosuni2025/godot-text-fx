extends Control
## 효과·이징 카드의 작은 미리보기. TextFxPlayer 대신 런타임 계산기(TextFxEvaluator) 결과를
## draw_string으로 바로 그린다(굽기 없음). active일 때만 시간이 흐르고, 아니면 효과가 드러나는 한 장면에 멈춘다.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")

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
		set_process(v)
		_t = 0.0 if v else _static_t
		queue_redraw()

var _ev: Evaluator = null
var _fonts: Dictionary = {}
var _cycle := 1.0
var _t := 0.0
var _static_t := 0.0


func _ready() -> void:
	set_process(active)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(p_kind: String, p_value: String, sample: String) -> void:
	kind = p_kind
	value = p_value
	_ev = null
	if kind in ["enter", "exit", "hold", "deco"]:
		var doc := _doc_for(sample)
		_fonts = Layout.resolve_fonts(doc)
		_ev = Evaluator.new(doc, {}, _fonts)
		_cycle = maxf(0.6, _ev.get_duration() + 0.5) if kind not in ["hold", "deco"] else 3.0
	else:
		_cycle = 1.6
	match kind:
		"enter": _static_t = 0.3
		"exit": _static_t = 0.5 + 0.3
		"hold": _static_t = 0.37
		"deco": _static_t = 2.0
		_: _static_t = 1.0
	_t = _static_t
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
				"easing": Enter.SUGGESTED_EASING.get(value, "cubic_out"), "params": Enter.default_params(value)}
			tl["hold"] = {"duration": 0.8, "effects": []}
			tl["exit"]["enabled"] = false
		"exit":
			tl["enter"] = {"effect": "fade", "order": "all", "duration": 0.0, "stagger": 0.0, "easing": "linear",
				"params": {}}
			tl["hold"] = {"duration": 0.5, "effects": []}
			tl["exit"] = {"enabled": true, "effect": value, "order": "forward", "duration": 0.5, "stagger": 0.09,
				"easing": "cubic_in", "params": Enter.default_params(value)}
		"hold", "deco":
			tl["enter"] = {"effect": "fade", "order": "all", "duration": 0.0, "stagger": 0.0, "easing": "linear",
				"params": {}}
			tl["hold"] = {"duration": 600.0, "effects": [Hold.default_params(value)] if kind == "hold" else []}
			tl["exit"]["enabled"] = false
			if kind == "deco":
				d["layout"]["font_size"] = 56
				d["decorations"] = [Doc.default_decoration(value)]
				d["decorations"][0]["thickness"] = 6.0
	return Doc.normalize(d)


func _process(delta: float) -> void:
	_t = fmod(_t + delta, _cycle)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if kind == "easing":
		_draw_easing()
	elif _ev != null:
		_draw_glyphs()


func _draw_glyphs() -> void:
	var canvas := Vector2(CANVAS)
	var s := minf(size.x / canvas.x, size.y / canvas.y)
	var origin := (size - canvas * s) * 0.5
	var glyphs: Array = _ev.layout["glyphs"]
	var t := _t + (0.001 if kind == "hold" else 0.0)
	var frame := _ev.evaluate_frame(t)
	for deco in frame["decorations"]:
		Drawer.draw_decoration(self, deco, origin, s)
	for st in frame["glyphs"]:
		if not st.visible or st.character.strip_edges() == "" or st.index >= glyphs.size():
			continue
		var font: Font = _fonts.get(st.role, _fonts.get("main"))
		var fsz := maxi(6, roundi(float(glyphs[st.index]["font_size"]) * s * (st.overlay_scale if st.overlay else 1.0)))
		var w := font.get_string_size(st.character, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var baseline := (font.get_ascent(fsz) - font.get_descent(fsz)) * 0.5
		var col := Color(INK.r * st.tint.r, INK.g * st.tint.g, INK.b * st.tint.b, st.alpha * clampf(st.clip, 0.0, 1.0))
		draw_set_transform(origin + st.pos * s, st.rotation, st.scale)
		draw_string(font, Vector2(-w * 0.5, baseline), st.character, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
