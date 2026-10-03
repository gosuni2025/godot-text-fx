extends RefCounted
## TextFxEvaluator: 결정론, 모든 효과 id·유지 효과·장식 평가, center_stamp 오버레이, 스크롤.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")


func _doc(patch: Dictionary) -> Dictionary:
	var d := Doc.defaults()
	d["text"] = "교전 개시 ABC"
	d["sub_text"] = "보조"
	for k in patch:
		Doc.set_value(d, k, patch[k])
	return Doc.normalize(d)


func _dump(states: Array) -> Array:
	var out: Array = []
	for s: GlyphState in states:
		out.append(s.to_dict())
	return out


func _sane(t, states: Array, label: String) -> void:
	for s: GlyphState in states:
		if not (is_finite(s.pos.x) and is_finite(s.pos.y) and is_finite(s.alpha) and is_finite(s.rotation) and is_finite(s.scale.x)):
			t.fail("%s: non-finite state %s" % [label, str(s.to_dict())])
			return
		if s.alpha < 0.0 or s.alpha > 1.0:
			t.fail("%s: alpha out of range %f" % [label, s.alpha])
			return


func run(t) -> void:
	var times := [0.0, 0.05, 0.13, 0.3, 0.6, 1.0, 2.0, 2.5, 3.0, 5.0]
	# 모든 등장/퇴장 효과
	for id in Enter.IDS:
		var d := _doc({"timeline.enter.effect": id, "timeline.exit.effect": id, "timeline.enter.easing": Enter.SUGGESTED_EASING.get(id, "cubic_out")})
		var ev := Evaluator.new(d)
		var seen_partial := false
		for tt in times:
			var st := ev.evaluate(tt)
			_sane(t, st, "%s@%s" % [id, str(tt)])
			for s: GlyphState in st:
				if s.index >= ev.layout["glyphs"].size():
					continue
				var base_pos: Vector2 = ev.layout["glyphs"][s.index]["pos"]
				if s.visible and (s.alpha < 0.99 or s.clip < 0.99 or s.scale.x != 1.0 or s.pos.distance_to(base_pos) > 0.5 or s.split > 0.0):
					seen_partial = true
		t.ok(seen_partial or id == "typewriter", "effect %s produced intermediate states" % id)
		var dur := ev.get_duration()
		var mid := ev.evaluate(ev.timeline.pages[0]["enter_end"] + 0.01)
		var all_vis := true
		for s: GlyphState in mid:
			if not s.overlay and not s.visible:
				all_vis = false
		t.ok(all_vis, "%s: all glyphs visible in hold" % id)
		t.eq(ev.evaluate(dur + 0.1).filter(func(s: GlyphState) -> bool: return s.visible).size(), 0, "%s: nothing visible after end" % id)
		var first := ev.evaluate(0.0)
		t.ok(first.filter(func(s: GlyphState) -> bool: return s.visible and not s.overlay and s.alpha > 0.99).size() == 0 or id == "wipe" or id == "typewriter",
			"%s: hidden at t=0" % id)

	# 모든 유지 효과(중첩 포함)
	var effects: Array = []
	for ty in Hold.TYPES:
		effects.append(Hold.default_params(ty))
		var ev2 := Evaluator.new(_doc({"timeline.hold.effects": [Hold.default_params(ty)], "timeline.loop": "loop_hold"}))
		var h0: float = ev2.timeline.pages[0]["enter_end"]
		var changed := false
		var base := _dump(ev2.evaluate(h0))
		for k in 40:
			var st := ev2.evaluate(h0 + 0.037 * k + 0.01)
			_sane(t, st, "hold %s" % ty)
			if _dump(st) != base:
				changed = true
		t.ok(changed, "hold %s changes state over time" % ty)
	var evh := Evaluator.new(_doc({"timeline.hold.effects": effects, "timeline.loop": "loop_hold"}))
	for k in 20:
		_sane(t, evh.evaluate(1.0 + k * 0.31), "hold stack")
	# 글리치 유지 효과가 실제로 조각·색수차를 만든다
	var evg := Evaluator.new(_doc({"timeline.hold.effects": [{"type": "glitch", "interval": 0.5, "duration": 0.5}], "timeline.loop": "loop_hold"}))
	var gs: GlyphState = evg.evaluate(evg.timeline.pages[0]["enter_end"] + 0.2)[0]
	t.ok(gs.slices.size() == 4 and gs.split > 0.0, "glitch slices and split")

	# 결정론: 두 번 평가 동일, 새 평가기도 동일
	var dr := _doc({"timeline.enter.effect": "scatter", "timeline.enter.order": "random", "timeline.hold.effects": [Hold.default_params("shake"), Hold.default_params("flicker")]})
	var e1 := Evaluator.new(dr)
	var e2 := Evaluator.new(dr)
	for tt in [0.1, 0.4, 1.2, 1.9]:
		t.eq(_dump(e1.evaluate(tt)), _dump(e1.evaluate(tt)), "evaluate twice equal @%s" % str(tt))
		t.eq(_dump(e1.evaluate(tt)), _dump(e2.evaluate(tt)), "new evaluator equal @%s" % str(tt))
	# 시드가 다르면 random/scatter 결과가 다름
	for id in ["scatter", "glitch"]:
		var a := Evaluator.new(_doc({"seed": 1, "timeline.enter.effect": id}))
		var b := Evaluator.new(_doc({"seed": 2, "timeline.enter.effect": id}))
		t.ne(_dump(a.evaluate(0.2)), _dump(b.evaluate(0.2)), "%s differs by seed" % id)
	var ra := Evaluator.new(_doc({"seed": 1, "timeline.enter.order": "random"}))
	var rb := Evaluator.new(_doc({"seed": 99, "timeline.enter.order": "random"}))
	t.ne(_dump(ra.evaluate(0.3)), _dump(rb.evaluate(0.3)), "random order differs by seed")

	# center_stamp: 오버레이 → 쉼 → 내려찍기
	var ds := _doc({"timeline.enter.effect": "center_stamp", "timeline.enter.duration": 0.3,
		"timeline.enter.params": {"hold_each": 0.2, "pause": 0.4, "big_scale": 3.0, "slam_scale": 2.0}})
	var es := Evaluator.new(ds)
	var n_glyph: int = es.layout["glyphs"].size()
	var st0 := es.evaluate(0.1)
	t.eq(st0.size(), n_glyph + 1, "one overlay glyph during stamp")
	var ov: GlyphState = st0[n_glyph]
	t.ok(ov.overlay and ov.visible, "overlay visible")
	t.eq(ov.character, "교", "first overlay char")
	t.near(ov.overlay_scale, 3.0, 0.0001, "overlay scale")
	t.near(ov.pos, Vector2(640, 360), 0.01, "overlay at center")
	t.eq(st0.slice(0, n_glyph).filter(func(s: GlyphState) -> bool: return s.visible).size(), 0, "normal glyphs hidden during stamp")
	t.eq((es.evaluate(0.25)[n_glyph] as GlyphState).character, "전", "second overlay char")
	var main_count: int = es.timeline.pages[0]["stamp_count"]
	var pause_t := main_count * 0.2 + 0.2
	t.eq(es.evaluate(pause_t).size(), n_glyph, "no overlay during pause")
	var slam: Array = es.evaluate(main_count * 0.2 + 0.4 + 0.05)
	t.ok((slam[0] as GlyphState).scale.x > 1.2, "slam starts big")
	var settled: Array = es.evaluate(main_count * 0.2 + 0.4 + 0.31)
	t.near((settled[0] as GlyphState).scale.x, 1.0, 0.001, "slam settles")

	# 장식
	var deco_types := Doc.DECORATION_TYPES
	var decos: Array = []
	for ty in deco_types:
		decos.append(Doc.default_decoration(ty))
	var dd := _doc({"decorations": decos})
	var ed := Evaluator.new(dd)
	var fr := ed.evaluate_frame(0.3)
	t.eq(fr["decorations"].size(), deco_types.size(), "all decorations evaluated")
	var expect_rects := {"underline": 1, "overline": 1, "band": 1, "side_lines": 2, "frame": 4, "brackets": 8}
	var fr2 := ed.evaluate_frame(1.5)
	for de in fr2["decorations"]:
		t.eq(de["rects"].size(), expect_rects[de["type"]], "rect count " + str(de["type"]))
	var u0: Rect2 = ed.evaluate_frame(0.15)["decorations"][0]["rects"][0]
	var u1: Rect2 = fr2["decorations"][0]["rects"][0]
	t.ok(u0.size.x < u1.size.x, "underline grows")
	t.eq(ed.evaluate_frame(ed.get_duration() + 1.0)["decorations"].size(), 0, "decorations gone after end")
	var dv := _doc({"decorations": decos, "layout.direction": "vertical", "font.path": "res://assets/fonts/galmuri/Galmuri11.ttf"})
	for de in Evaluator.new(dv).evaluate_frame(1.5)["decorations"]:
		t.ok(de["rects"].size() > 0, "vertical decoration " + str(de["type"]))

	# 스크롤: 블록이 아래에서 위로
	var sc := Evaluator.new(_doc({"mode": "trailer", "text": "line1\nline2", "timeline.scroll": {"speed": 100.0}}))
	var y0: float = (sc.evaluate(0.0)[0] as GlyphState).pos.y
	var y1: float = (sc.evaluate(1.0)[0] as GlyphState).pos.y
	t.ok(y0 > 720.0, "scroll starts below canvas")
	t.near(y0 - y1, 100.0, 0.01, "scroll speed")
	# 불투명도
	var eo := Evaluator.new(_doc({"style.opacity": 0.5}))
	var so: GlyphState = eo.evaluate(eo.timeline.pages[0]["enter_end"] + 0.1)[0]
	t.near(so.alpha, 0.5, 0.001, "style opacity applied")
	# wipe clip
	var ew := Evaluator.new(_doc({"timeline.enter.effect": "wipe", "timeline.enter.easing": "linear", "timeline.enter.duration": 1.0, "timeline.enter.stagger": 0.0}))
	t.near((ew.evaluate(0.5)[0] as GlyphState).clip, 0.5, 0.001, "wipe clip half")
