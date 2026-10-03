extends RefCounted
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Shapes := preload("res://addons/text_fx/core/fx_decoration_shapes.gd")

func run(t) -> void:
	var d := Doc.defaults()
	d["text"] = "TITLE"
	d["sub_text"] = "Subtitle"
	d["timeline"]["enter"]["duration"] = 0.6
	d["timeline"]["enter"]["order"] = "all"
	d["timeline"]["hold"]["duration"] = 1.0
	var deco := Doc.default_decoration("box")
	deco["animate"] = "shape"
	deco["delay"] = 0.0
	deco["duration"] = 0.4
	deco["use_outline"] = true
	d["style"]["outline2"]["enabled"] = true
	d["decorations"] = [deco]
	var ev := Evaluator.new(d)
	var box: Dictionary = ev.evaluate_frame(0.6)["decorations"][0]
	t.ok((box["rects"][0] as Rect2).encloses(ev.layout["pages"][0]["rect"]), "box encloses main and sub")
	t.ok(box["outline2"], "second outline propagates")
	t.ok(box["fill_opacity"] > 0.0 and box["radius"] > 0.0, "rounded fill available")
	var growing: Rect2 = ev.evaluate_frame(0.08)["decorations"][0]["rects"][0]
	t.ok(growing.size.x < box["rects"][0].size.x and growing.size.y == box["rects"][0].size.y, "box grows in one axis")
	for vertical in [false, true]:
		d["layout"]["direction"] = "vertical" if vertical else "horizontal"
		deco = Doc.default_decoration("band")
		deco["animate"] = "shape"
		deco["softness"] = 0.5
		deco["end_fade"] = 0.4
		d["decorations"] = [deco]
		ev = Evaluator.new(d)
		var band: Dictionary = ev.evaluate_frame(0.7)["decorations"][0]
		var r: Rect2 = band["rects"][0]
		t.near(r.size.y if vertical else r.size.x, 720.0 if vertical else 1280.0, 0.001, "band spans canvas")
		t.eq(band["softness"], 0.5, "band feather preserved")
		deco = Doc.default_decoration("frame")
		deco["animate"] = "shape"
		deco["length"] = 4.0
		deco["fill_opacity"] = 0.4
		d["decorations"] = [deco]
		ev = Evaluator.new(d)
		var frame: Dictionary = ev.evaluate_frame(0.7)["decorations"][0]
		for fr: Rect2 in frame["rects"]:
			t.ok(Rect2(Vector2.ZERO, ev.layout["canvas"]).encloses(fr), "frame clamped to canvas")
			t.ok(not fr.intersects(ev.layout["pages"][0]["sub_rect"]), "frame protects subtitle")
		var partial: Dictionary = ev.evaluate_frame(0.11)["decorations"][0]
		t.ok(partial["rects"].size() < 4, "frame traces continuous path")
		var first: Rect2 = partial["rects"][0]
		t.ok(first.size.y > first.size.x if vertical else first.size.x > first.size.y, "trace start follows writing direction")
	var tapes := [Rect2(0, 0, 100, 10), Rect2(0, 50, 100, 10)]
	var before := Shapes.animate(tapes, "tape", 0.5, 0, false, Rect2())
	var after := Shapes.animate(tapes, "tape", 1, 0.5, false, Rect2())
	t.ok(before[0].position.x < 0 and after[0].position.x > 0, "tape exits in movement direction")
	t.ok(before[1].position.x > 0 and after[1].position.x < 0, "paired tape moves oppositely")
	_background(t)

func _background(t) -> void:
	var d := Doc.defaults()
	d["mode"] = "trailer"
	d["text"] = "A\n\nB"
	d["timeline"]["lead_in"] = 0.2
	d["timeline"]["lead_out"] = 0.3
	d["background"] = {"type": "solid", "color": "#112233FF", "opacity": 0.8, "sync_fade": true, "extent": 0.5}
	var ev := Evaluator.new(d)
	t.eq(ev.evaluate_frame(0.1)["background"], {}, "leading blank hides background")
	var first: Dictionary = ev.timeline.pages[0]
	var last: Dictionary = ev.timeline.pages[1]
	t.near(ev.evaluate_frame(float(first["start"]) + float(first["enter_len"]) * 0.5)["background"]["opacity"], 0.4, 0.001, "first enter fades background")
	t.near(ev.evaluate_frame(float(first["exit_end"]) + 0.05)["background"]["opacity"], 0.8, 0.001, "page gap keeps background")
	t.near(ev.evaluate_frame(float(last["start"]) + 0.05)["background"]["opacity"], 0.8, 0.001, "later page does not refade")
	t.near(ev.evaluate_frame(float(last["hold_end"]) + float(last["exit_len"]) * 0.5)["background"]["opacity"], 0.4, 0.001, "final exit fades background")
	t.eq(ev.evaluate_frame(ev.timeline.content_end + 0.1)["background"], {}, "trailing blank hides background")
	for pair in [["timeline.lead_in", -1.0], ["timeline.sub_enter.effect", "missing"], ["background.opacity", 2.0], ["background.color", "red"]]:
		var invalid := d.duplicate(true)
		Doc.set_value(invalid, pair[0], pair[1])
		t.ok(not Doc.validate(invalid).is_empty(), "runtime rejects invalid " + str(pair[0]))
	for type in ["solid", "vignette", "bottom", "top"]:
		d["background"]["type"] = type
		t.eq(Evaluator.new(d).evaluate_frame(float(first["enter_end"]) + 0.1)["background"]["type"], type, "background type " + type)
