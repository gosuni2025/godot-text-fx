extends RefCounted
## 새 연출의 seek 결정론, 실제 파편/복제 계약, 끝점·순서·문서 왕복 회귀.
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Cinematic := preload("res://addons/text_fx/core/fx_effects_cinematic.gd")
const Codec := preload("res://addons/text_fx/core/fx_codec.gd")
const State := preload("res://addons/text_fx/core/fx_glyph_state.gd")


func _doc(id: String) -> Dictionary:
	var d := Doc.defaults()
	d["text"] = "기억 회복"
	d["timeline"]["enter"] = {"effect": id, "duration": 1.0, "order": "forward", "stagger": 0.08,
		"easing": "linear", "params": Cinematic.default_params(id)}
	d["timeline"]["exit"] = {"effect": id, "enabled": true, "duration": 1.0, "order": "reverse", "stagger": 0.08,
		"easing": "linear", "params": Cinematic.default_params(id)}
	return d


func _dump(states: Array) -> Array:
	var out: Array = []
	for state: State in states:
		out.append(state.to_dict())
	return out


func run(t) -> void:
	for id in Cinematic.IDS:
		var d := _doc(id)
		var ev := Evaluator.new(d)
		var sample := _dump(ev.evaluate(0.42))
		ev.evaluate(100.0)
		t.eq(_dump(ev.evaluate(0.42)), sample, "%s seek backward preserves deterministic state" % id)
		t.eq(_dump(Evaluator.new(Codec.decode(Codec.encode(d))).evaluate(0.42)), sample,
			"%s clipboard round trip preserves visual state" % id)
		t.ok(ev.evaluate(0.01)[0].visible and not ev.evaluate(0.01)[1].visible,
			"%s forward stagger does not reveal later glyphs" % id)
		var mid: State = ev.evaluate(0.42)[0]
		t.eq(mid.copy().to_dict(), mid.to_dict(), "%s renderer copies all visual state" % id)
		var copied: State = mid.copy()
		copied.cinematic["hidden"] = -1.0
		t.ok(mid.cinematic["hidden"] >= 0.0, "%s cinematic copy is independent" % id)
		var hold: State = ev.evaluate(float(ev.timeline.pages[0]["enter_end"]) + 0.02)[0]
		t.ok(hold.visible and hold.cinematic.is_empty() and hold.fragments.is_empty() and hold.echoes.is_empty(),
			"%s restores clean full glyph in hold" % id)
		t.eq(ev.evaluate(ev.get_duration() + 0.01).filter(func(s: State) -> bool: return s.visible).size(), 0,
			"%s no residual particles after exit" % id)
		d["layout"]["direction"] = "vertical"
		var vertical := Evaluator.new(d).evaluate(0.42)
		t.ok(vertical[0].visible and is_finite(vertical[0].pos.y), "%s supports vertical layout" % id)
		for effect_state: State in vertical:
			for fragment: Dictionary in effect_state.fragments:
				t.ok(is_finite(fragment["offset"].x) and is_finite(fragment["rotation"]), "%s finite fragment" % id)
	var fragments: State = Evaluator.new(_doc("fragment_assemble")).evaluate(0.5)[0]
	var area := 0.0
	var displaced := 0
	for fragment: Dictionary in fragments.fragments:
		area += (fragment["rect"] as Rect2).get_area()
		if (fragment["offset"] as Vector2).length() > 1.0:
			displaced += 1
	t.near(area, 1.0, 0.00001, "fragments partition entire glyph texture")
	t.ok(displaced > 1, "multiple actual glyph fragments move independently")
	var echoes: State = Evaluator.new(_doc("afterimage_overtake")).evaluate(0.5)[0]
	t.ok(echoes.echoes.size() >= 2, "afterimage effect emits multiple rendered copies")
	t.ne(echoes.echoes[0]["offset"], echoes.echoes[1]["offset"], "copies overtake at distinct positions")
	for id in ["ember_dissolve", "dimensional_rift", "liquid_merge", "frost_crystal", "thread_stitch", "surface_pressure"]:
		var state: State = Evaluator.new(_doc(id)).evaluate(0.5)[0]
		t.ok(not state.cinematic["marks"].is_empty(), "%s supplies actual geometric detail" % id)
