extends RefCounted
## 원본 연출 대조로 추가된 타이밍의 의미·경계·결정론 회귀 검사.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Timeline := preload("res://addons/text_fx/core/fx_timeline.gd")


func _doc(text: String = "AB") -> Dictionary:
	var d := Doc.defaults()
	d["text"] = text
	d["timeline"]["enter"] = {"effect": "fade", "order": "forward", "duration": 0.4,
		"stagger": 0.1, "easing": "linear", "params": {}}
	d["timeline"]["hold"]["duration"] = 1.0
	d["timeline"]["exit"]["duration"] = 0.3
	return d


func _visible(ev, time: float) -> int:
	return ev.evaluate(time).filter(func(st) -> bool: return st.visible).size()


func _cursor(ev, time: float) -> Array:
	return ev.evaluate_frame(time)["decorations"].filter(func(d: Dictionary) -> bool: return d["type"] == "cursor")


func run(t) -> void:
	_blank_and_pages(t)
	_sub(t)
	_order(t)
	_decorations(t)
	_stamp_and_spread(t)
	_scroll(t)
	_cursor_and_scope(t)
	_decoration_follow(t)


func _blank_and_pages(t) -> void:
	var d := _doc("A")
	d["timeline"]["lead_in"] = 0.2
	d["timeline"]["lead_out"] = 0.5
	var ev := Evaluator.new(d)
	t.near(ev.get_duration(), 2.4, 0.0001, "document blanks extend total duration")
	t.eq(_visible(ev, 0.1), 0, "lead in is transparent")
	t.ok(_visible(ev, 0.3) > 0, "text enters after lead in")
	t.eq(ev.timeline.sample(2.0)["phase"], "gap", "lead out is a transparent gap")
	t.eq(_visible(ev, 2.0), 0, "lead out has no glyphs")
	d = _doc("A\n\nB")
	d["mode"] = "trailer"
	d["timeline"]["split_pages"] = false
	t.eq(Evaluator.new(d).layout["page_count"], 1, "blank-line page split can be disabled")
	d["timeline"]["split_pages"] = true
	d["timeline"]["exit_between_pages"] = false
	d["timeline"]["exit"]["enabled"] = false
	ev = Evaluator.new(d)
	t.eq(ev.timeline.pages[0]["exit_performed"], false, "disabled exit also skips intermediate page exit")
	t.near(ev.timeline.pages[1]["start"], ev.timeline.pages[0]["hold_end"] + d["timeline"]["page_gap"], 0.0001, "next page starts after hold and gap")


func _sub(t) -> void:
	var d := _doc()
	d["sub_text"] = "Z"
	d["timeline"]["sub_enter"] = {"effect": "slide", "order": "all", "duration": 0.3,
		"stagger": 0.0, "easing": "linear", "delay": 0.2, "params": {"dir": "left", "distance": 1.0}}
	var ev := Evaluator.new(d)
	t.near(ev.timeline.pages[0]["main_enter_len"], 0.5, 0.0001, "sub does not extend main glyph timing")
	t.near(ev.timeline.enter_delay[2], 0.7, 0.0001, "sub delay is relative to main completion")
	t.near(ev.timeline.pages[0]["enter_len"], 1.0, 0.0001, "hold waits for independent sub")
	t.ok(not ev.evaluate(0.6)[2].visible, "sub hidden before its signed start")
	t.ok(ev.evaluate(0.8)[2].visible, "independent sub appears")
	t.ok(ev.evaluate(0.8)[2].pos.x > ev.layout["glyphs"][2]["pos"].x, "sub uses its own slide effect")
	d["timeline"]["sub_enter"]["delay"] = -10.0
	t.near(Evaluator.new(d).timeline.enter_delay[2], 0.0, 0.0001, "negative sub delay clamps to page text start")
	d["timeline"]["enter"]["effect"] = "block_zoom"
	d["timeline"]["sub_enter"]["effect"] = "same"
	d["timeline"]["sub_enter"]["delay"] = 2.0
	ev = Evaluator.new(d)
	t.near(ev.timeline.enter_delay[2], 0.0, 0.0001, "same block sub moves simultaneously")
	t.near(ev.evaluate(0.2)[0].scale.x, ev.evaluate(0.2)[2].scale.x, 0.0001, "same block sub shares block timing")
	d = _doc("A")
	d["sub_text"] = "AAA"
	d["layout"]["letter_spacing"] = 0.5
	d["layout"]["sub"]["letter_spacing"] = 0.0
	var a := Layout.compute(Doc.normalize(d))
	d["layout"]["sub"]["letter_spacing"] = 0.4
	var b := Layout.compute(Doc.normalize(d))
	t.ok((b["pages"][0]["sub_rect"] as Rect2).size.x > (a["pages"][0]["sub_rect"] as Rect2).size.x, "sub letter spacing independently expands sub text")


func _order(t) -> void:
	var d := _doc("AB\nAB")
	d["timeline"]["enter"]["order"] = "sweep"
	d["timeline"]["enter"]["stagger"] = 2.0
	d["timeline"]["enter"]["params"] = {"line_stagger": 0.8, "sweep_duration": 0.4}
	var ev := Evaluator.new(d)
	t.near(ev.timeline.enter_delay[2] - ev.timeline.enter_delay[0], 0.8, 0.0001, "sweep line starts use line interval")
	var delta: float = ev.timeline.enter_delay[1] - ev.timeline.enter_delay[0]
	t.ok(delta > 0.0 and delta < 0.4, "sweep staggers glyphs by line position, not character interval")
	d = _doc("A.\nB!")
	d["timeline"]["enter"]["params"] = {"line_pause": 0.4, "punct_pause": 0.2, "punct_long_pause": 0.5}
	ev = Evaluator.new(d)
	t.near(ev.timeline.enter_delay[2], 1.1, 0.0001, "long sentence pause and line pause accumulate")
	var ranks := Timeline.compute_ranks(ev.layout["glyphs"], 0, 4, "center_index", 0)
	t.eq(Array(ranks), [1, 0, 0, 1], "center index order is independent of glyph width")
	t.eq(Array(Timeline.compute_ranks(ev.layout["glyphs"], 0, 4, "edges_index", 0)), [0, 1, 1, 0], "edges index order")
	d["timeline"]["enter"]["effect"] = "block_zoom"
	ev = Evaluator.new(d)
	t.near(ev.timeline.enter_delay[3], 0.0, 0.0001, "block effects ignore glyph staggering")
	d["timeline"]["exit"]["effect"] = "erase"
	t.near(Evaluator.new(d).timeline.pages[0]["text_exit_len"], 0.0, 0.0001, "erase has no transition duration")


func _decorations(t) -> void:
	var d := _doc("A")
	var deco := Doc.default_decoration("underline")
	deco["lead_text"] = true
	deco["delay"] = 0.2
	deco["duration"] = 0.4
	deco["exit_delay"] = 0.1
	deco["exit_duration"] = 0.9
	d["decorations"] = [deco]
	var ev := Evaluator.new(d)
	t.near(ev.timeline.enter_delay[0], 0.6, 0.0001, "leading decoration postpones text")
	t.eq(_visible(ev, 0.5), 0, "text stays hidden until decoration finishes")
	t.ok(_visible(ev, 0.7) > 0, "text enters after decoration")
	t.near(ev.timeline.pages[0]["text_exit_len"], 0.3, 0.0001, "text retains its exit duration")
	t.near(ev.timeline.pages[0]["exit_len"], 1.0, 0.0001, "page waits for decoration exit")


func _stamp_and_spread(t) -> void:
	var d := _doc("A B\nC")
	d["timeline"]["enter"]["effect"] = "center_stamp"
	d["timeline"]["enter"]["params"] = {"hold_each": 0.2, "pause": 0.3, "space_pause": 0.15,
		"impact_duration": 0.3, "impact_brightness": 1.0, "impact_shake": 8.0}
	var ev := Evaluator.new(d)
	t.near(ev.timeline.pages[0]["stamp_seq"], 1.2, 0.0001, "solo includes whitespace and final pauses")
	t.eq(_visible(ev, 0.25), 0, "solo whitespace beat is blank")
	t.eq(_visible(ev, 1.05), 0, "solo final pause is blank")
	var st: Array = ev.evaluate(1.25)
	t.ok(st[0].brightness > 0.0, "solo impact brightens text")
	var center: Vector2 = (ev.layout["pages"][0]["rect"] as Rect2).get_center()
	var off_a: Vector2 = st[0].pos - (center + (ev.layout["glyphs"][0]["pos"] - center) * st[0].scale.x)
	var off_b: Vector2 = st[1].pos - (center + (ev.layout["glyphs"][1]["pos"] - center) * st[1].scale.x)
	t.near(off_a, off_b, 0.0001, "solo shake moves the entire block together")
	t.eq(st[0].to_dict(), ev.evaluate(1.25)[0].to_dict(), "solo impact is deterministic")
	d["timeline"]["enter"]["params"]["viewport_scale"] = 0.8
	var enlarged := Evaluator.new(d)
	var overlay = enlarged.evaluate(0.1)[-1]
	t.near(overlay.overlay_scale * float(enlarged.layout["glyphs"][0]["font_size"]), 720.0 * 0.8, 0.0001, "solo viewport scale uses the canvas short edge")
	var viewport_doc := d.duplicate(true)
	viewport_doc["layout"]["anchor"] = [0.1, 0.2]
	viewport_doc["layout"]["offset"] = [20.0, 30.0]
	viewport_doc["timeline"]["enter"]["params"]["solo_animated"] = false
	var instant = Evaluator.new(viewport_doc).evaluate(0.0)[-1]
	t.near(instant.pos, Vector2(640, 360), 0.0001, "viewport solo centers independently of text anchor and offset")
	t.ok(instant.visible and instant.scale == Vector2.ONE and instant.alpha == 1.0, "nonanimated solo replaces glyph instantly without scale or alpha envelope")
	d["timeline"]["enter"]["params"]["impact_brightness"] = 0.0
	d["timeline"]["enter"]["params"]["impact_shake"] = 0.0
	t.near(Evaluator.new(d).evaluate(1.25)[0].brightness, 0.0, 0.0001, "solo impact supports zero strength")
	d = _doc()
	d["timeline"]["enter"]["effect"] = "center_split"
	d["timeline"]["enter"]["order"] = "all"
	d["timeline"]["enter"]["params"] = {"overlap_hold": 0.5, "jitter": 0.0}
	ev = Evaluator.new(d)
	t.near(ev.timeline.pages[0]["enter_len"], 0.9, 0.0001, "overlap hold extends spread sequence")
	t.near(ev.evaluate(0.3)[0].pos, ev.evaluate(0.3)[1].pos, 0.0001, "spread holds glyphs overlapped before opening")
	t.ok(ev.evaluate(0.7)[0].pos.distance_to(ev.evaluate(0.7)[1].pos) > 1.0, "spread opens after overlap hold")


func _scroll(t) -> void:
	var d := _doc("AB")
	d["layout"]["direction"] = "vertical"
	d["timeline"]["scroll"] = {"speed": 100.0, "edge_fade": 0.1}
	var ev := Evaluator.new(d)
	var first: Array = ev.evaluate(0.0)
	t.ok(first[0].pos.x < 0.0, "vertical scroll begins left of viewport")
	t.near(ev.evaluate(1.0)[0].pos.x - first[0].pos.x, 100.0, 0.001, "vertical scroll travels right")
	var enter_time: float = (64.0 - first[0].pos.x) / 100.0
	t.near(ev.evaluate(enter_time)[0].alpha, 0.5, 0.001, "scroll feathers alpha at viewport edge")
	t.near(ev.evaluate(enter_time + 1.0)[0].alpha, 1.0, 0.001, "scroll is opaque inside viewport")
	t.eq(_visible(ev, ev.get_duration() + 0.1), 0, "scroll finishes transparent")


func _cursor_and_scope(t) -> void:
	var d := _doc()
	d["timeline"]["enter"]["effect"] = "typewriter"
	d["timeline"]["enter"]["duration"] = 0.1
	d["timeline"]["enter"]["stagger"] = 0.2
	d["timeline"]["enter"]["params"] = {"pop": 0.0, "cursor": true, "cursor_blink": 0.6, "cursor_color": "#FF0000FF"}
	var ev := Evaluator.new(d)
	t.eq(_cursor(ev, 0.05).size(), 1, "typing shows one cursor")
	var a: Rect2 = _cursor(ev, 0.05)[0]["rects"][0]
	var b: Rect2 = _cursor(ev, 0.25)[0]["rects"][0]
	t.ok(b.position.x > a.position.x, "cursor follows latest revealed glyph")
	t.eq(_cursor(ev, 0.35).size(), 1, "completed typing starts cursor blink on")
	t.eq(_cursor(ev, 0.65).size(), 0, "completed typing cursor blinks off")
	t.eq(_cursor(ev, 1.4).size(), 0, "cursor is hidden in exit")
	d["timeline"]["enter"]["effect"] = "fade"
	t.eq(_cursor(Evaluator.new(d), 0.05).size(), 1, "cursor also accompanies per-glyph fade flow")
	d = _doc("A")
	d["timeline"]["hold"]["scope"] = "visible"
	d["timeline"]["hold"]["effects"] = [{"type": "float", "amplitude": 10.0, "period": 1.0}]
	ev = Evaluator.new(d)
	t.near(ev.evaluate(0.25)[0].pos.y - ev.layout["glyphs"][0]["pos"].y, 10.0, 0.001, "visible scope applies motion during entrance")
	d["timeline"]["hold"]["scope"] = "hold"
	ev = Evaluator.new(d)
	t.near(ev.evaluate(0.25)[0].pos.y, ev.layout["glyphs"][0]["pos"].y, 0.001, "legacy hold scope leaves entrance unchanged")


func _decoration_follow(t) -> void:
	var d := _doc()
	d["decorations"] = [Doc.default_decoration("underline"), Doc.default_decoration("box")]
	for deco: Dictionary in d["decorations"]:
		deco["animate"] = "none"
		deco["follow_block"] = false
	d["timeline"]["hold"]["effects"] = [{"type": "float", "amplitude": 10.0, "period": 1.0},
		{"type": "shake", "amplitude": 50.0, "frequency": 18.0}]
	var before := Evaluator.new(d).evaluate_frame(0.75)
	for deco: Dictionary in d["decorations"]:
		deco["follow_block"] = true
	var after := Evaluator.new(d).evaluate_frame(0.75)
	var r0: Rect2 = before["decorations"][0]["rects"][0]
	var r1: Rect2 = after["decorations"][0]["rects"][0]
	t.near(r1.position - r0.position, Vector2(0.0, 10.0), 0.001, "decoration follows block float but ignores per-glyph shake")
	t.near(r1.size, r0.size, 0.001, "line decoration keeps size while following motion")
	d["timeline"]["hold"]["effects"] = []
	d["timeline"]["enter"]["effect"] = "block_zoom"
	d["timeline"]["enter"]["params"] = {"from_scale": 2.0, "blur": 0.0}
	var ev := Evaluator.new(d)
	var frame := ev.evaluate_frame(0.2)
	var full := ev.evaluate_frame(0.5)
	var box: Rect2 = frame["decorations"][1]["rects"][0]
	var full_box: Rect2 = full["decorations"][1]["rects"][0]
	t.near(box.size, full_box.size * 1.5, 0.001, "box follows whole-block zoom")
	t.near(frame["decorations"][0]["rects"][0].size, full["decorations"][0]["rects"][0].size, 0.001, "underline does not inherit block scale")
	t.near(frame["decorations"][1]["fill_rect"].size, box.size, 0.001, "box fill follows the same transform")
	d["timeline"]["enter"]["effect"] = "shutter"
	d["timeline"]["enter"]["params"] = {"axis": "vertical"}
	ev = Evaluator.new(d)
	frame = ev.evaluate_frame(0.2)
	full = ev.evaluate_frame(0.5)
	t.near(frame["decorations"][1]["rects"][0].size.y, full["decorations"][1]["rects"][0].size.y * 0.5, 0.001, "box follows shutter on the selected axis")
	d["timeline"]["enter"]["effect"] = "fade"
	d["timeline"]["hold"]["effects"] = [{"type": "block_glitch", "interval": 1.0, "duration": 1.0, "intensity": 1.0}]
	ev = Evaluator.new(d)
	frame = ev.evaluate_frame(0.75)
	var glyph_shift: Vector2 = frame["glyphs"][0].pos - ev.layout["glyphs"][0]["pos"]
	for deco: Dictionary in d["decorations"]:
		deco["follow_block"] = false
	before = Evaluator.new(d).evaluate_frame(0.75)
	t.near(frame["decorations"][0]["rects"][0].position - before["decorations"][0]["rects"][0].position,
		glyph_shift, 0.001, "decoration follows shared glitch translation")
