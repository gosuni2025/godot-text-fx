class_name TextFxEvaluator
extends RefCounted
## evaluate(t) → 글자 상태 배열(DESIGN §3). 순수 계산: 같은 문서·t·finish_at → 같은 결과.
## 노드·Engine 시간·전역 난수를 쓰지 않는다.
##
## evaluate(t, finish_at) → Array[GlyphState]
##   앞쪽 N개는 레이아웃 글자 순서(index)와 같고 현재 페이지가 아닌 글자는 visible=false.
##   center_stamp 오버레이 글자는 그 뒤에 덧붙는다(overlay=true).
## evaluate_frame(t, finish_at) → { time, page, phase, sample, glyphs, decorations, scroll_offset }
## 유지 효과는 hold 구간에서만 적용한다. 스크롤 모드는 처음부터 끝까지 hold로 본다.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Timeline := preload("res://addons/text_fx/core/fx_timeline.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const Stamp := preload("res://addons/text_fx/core/fx_center_stamp.gd")
const Decorations := preload("res://addons/text_fx/core/fx_decorations.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Timing := preload("res://addons/text_fx/core/fx_timing_helpers.gd")
const Cursor := preload("res://addons/text_fx/core/fx_typing_cursor.gd")
const Background := preload("res://addons/text_fx/core/fx_background.gd")
const DecorationMotion := preload("res://addons/text_fx/core/fx_decoration_motion.gd")

var doc: Dictionary
var layout: Dictionary
var timeline: Timeline
var seed := 0
var _opacity := {"main": 1.0, "sub": 1.0}


## p_doc은 정규화한다. layout을 넘기지 않으면 fonts(선택)로 계산한다.
func _init(p_doc: Dictionary, p_layout: Dictionary = {}, fonts: Dictionary = {}) -> void:
	doc = Doc.normalize(p_doc)
	layout = p_layout if not p_layout.is_empty() else Layout.compute(doc, fonts)
	timeline = Timeline.new(doc, layout)
	seed = int(doc["seed"])
	_opacity["main"] = float(Doc.style_for(doc, "main")["opacity"])
	_opacity["sub"] = float(Doc.style_for(doc, "sub")["opacity"])


func get_duration() -> float:
	return timeline.get_duration()


func get_end_time(finish_at: float = -1.0) -> float:
	return timeline.get_end_time(finish_at)


func evaluate(t: float, finish_at: float = -1.0) -> Array:
	return evaluate_frame(t, finish_at)["glyphs"]


func evaluate_frame(t: float, finish_at: float = -1.0) -> Dictionary:
	var s := timeline.sample(t, finish_at)
	var glyphs: Array = layout["glyphs"]
	var states: Array = []
	states.resize(glyphs.size())
	for i in glyphs.size():
		states[i] = _base_state(glyphs[i])
	var phase: String = s["phase"]
	var page: int = s["page"]
	var overlays: Array = []
	var scroll_offset := Vector2.ZERO
	if timeline.scroll_speed > 0.0 and layout["pages"].size() > 0:
		scroll_offset = Timing.scroll_offset(layout, timeline.scroll_speed, float(s["local"]))
	if phase != "end" and phase != "gap" and page < layout["pages"].size():
		var pg: Dictionary = layout["pages"][page]
		var first: int = pg["glyph_first"]
		var count: int = pg["glyph_count"]
		var tl: Dictionary = doc["timeline"]
		var ctx := {"seed": seed, "vertical": layout["direction"] == "vertical",
			"canvas": layout["canvas"], "block_center": (pg["rect"] as Rect2).get_center(),
			"block_rect": pg["rect"], "block_em": float(layout["font_size"]), "phase": phase}
		var independent_sub: bool = tl.get("sub_enter") is Dictionary
		var sub := Timing.sub_segment(doc)
		if phase == "enter" and timeline.stamp_enabled:
			for i in range(first, first + count):
				(states[i] as GlyphState).visible = true
			overlays = Stamp.apply(states, layout, doc, timeline.pages[page], page, float(s["local"]))
			if independent_sub:
				for i in range(first, first + count):
					if glyphs[i]["role"] == "sub":
						var st: GlyphState = states[i]
						st.alpha = 1.0
						st.scale = Vector2.ONE
						st.pos = glyphs[i]["pos"]
						_glyph_context(ctx, glyphs[i], pg)
						_apply_segment(st, glyphs[i], sub, float(s["local"]) - enter_delay_of(i), false, ctx)
		else:
			for i in range(first, first + count):
				var st: GlyphState = states[i]
				var g: Dictionary = glyphs[i]
				st.visible = true
				_glyph_context(ctx, g, pg)
				match phase:
					"enter":
						var segment: Dictionary = sub if independent_sub and st.role == "sub" else tl["enter"]
						_apply_segment(st, g, segment, float(s["local"]) - enter_delay_of(i), false, ctx)
					"exit":
						_apply_segment(st, g, tl["exit"], float(s["local"]) - timeline.exit_delay[i], true, ctx)
		for i in range(first, first + count):
			var st2: GlyphState = states[i]
			_glyph_context(ctx, glyphs[i], pg)
			_apply_hold(st2, glyphs[i], tl["hold"], s, ctx)
			st2.alpha = clampf(st2.alpha * float(_opacity.get(st2.role, 1.0)), 0.0, 1.0)
			st2.pos += scroll_offset
			if timeline.scroll_speed > 0.0:
				st2.alpha *= Timing.edge_alpha(st2.pos, layout, float(tl["scroll"].get("edge_fade", 0.0)))
			st2.visible = st2.visible and st2.alpha > 0.0005 and st2.clip > 0.0
	for o in overlays:
		var os: GlyphState = o
		os.alpha = clampf(os.alpha * float(_opacity.get(os.role, 1.0)), 0.0, 1.0)
		os.visible = os.alpha > 0.0005
		states.append(os)
	var decorations := Decorations.evaluate(doc, layout, timeline, s, scroll_offset)
	DecorationMotion.apply(decorations, doc, layout, timeline, s, scroll_offset)
	decorations.append_array(Cursor.evaluate(doc, layout, timeline, s, states))
	return {
		"time": t, "page": page, "phase": phase, "sample": s, "glyphs": states,
		"decorations": decorations,
		"background": Background.evaluate(doc, layout, timeline, s),
		"scroll_offset": scroll_offset,
	}


func enter_delay_of(i: int) -> float:
	return timeline.enter_delay[i]


func _apply_segment(st: GlyphState, g: Dictionary, seg: Dictionary, local: float, is_exit: bool, ctx: Dictionary) -> void:
	if not is_exit and local < 0.0:
		st.alpha = 0.0
		return
	var dur := maxf(0.0, float(seg["duration"]))
	if seg["effect"] == "erase":
		dur = 0.0
	var elapsed := local - Timing.overlap_hold(seg, is_exit)
	var p: float
	if dur <= 0.0:
		p = 1.0 if elapsed >= 0.0 else 0.0
	else:
		p = clampf(elapsed / dur, 0.0, 1.0)
	var e := Easing.apply(Enter.resolve_easing(str(seg["effect"]), str(seg["easing"]), is_exit), p)
	var k := e if is_exit else 1.0 - e
	ctx["params"] = seg["params"]
	ctx["is_exit"] = is_exit
	ctx["local"] = maxf(0.0, local)
	ctx["duration"] = dur
	Enter.apply(str(seg["effect"]), st, k, g, ctx)
	if is_exit and local >= dur:
		st.alpha = 0.0


func _glyph_context(ctx: Dictionary, g: Dictionary, pg: Dictionary) -> void:
	ctx["em"] = float(g["font_size"])
	ctx["line_center"] = layout["lines"][int(g["line"])]["center"]
	ctx["line_rect"] = layout["lines"][int(g["line"])]["rect"]
	ctx["role_center"] = (pg["sub_rect"] as Rect2).get_center() if g["role"] == "sub" else (pg["main_rect"] as Rect2).get_center()


func _apply_hold(st: GlyphState, g: Dictionary, hold: Dictionary, sample: Dictionary, ctx: Dictionary) -> void:
	var phase: String = sample["phase"]
	var all_visible: bool = hold.get("scope", "hold") == "visible"
	if phase != "hold" and not all_visible:
		return
	for effect in hold["effects"]:
		var blink: bool = effect.get("type", "") == "blink"
		if blink and phase != "hold":
			continue
		var time := float(sample["page_time"]) if all_visible and not blink else float(sample["local"])
		Hold.apply(effect, st, time, g, ctx)


func _base_state(g: Dictionary) -> GlyphState:
	var st := GlyphState.new()
	st.index = g["index"]
	st.character = g["char"]
	st.role = g["role"]
	st.page = g["page"]
	st.pos = g["pos"]
	st.rotation = g["base_rotation"]
	st.visible = false
	return st
