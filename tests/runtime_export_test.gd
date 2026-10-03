extends RefCounted
## TextFxBakedExport: 베이크 JSON 형태·결정론·center_stamp 오버레이 슬롯.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Baked := preload("res://addons/text_fx/core/fx_baked_export.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")


func run(t) -> void:
	var d := Doc.defaults()
	d["text"] = "교전 개시"
	d["timeline"]["hold"]["duration"] = 0.5
	var b := Baked.bake(d, 20.0)
	t.eq(b["format"], "text_fx_baked", "format")
	t.eq(b["format_version"], 1, "version")
	t.eq(b["fps"], 20.0, "fps")
	t.eq(b["canvas"], {"width": 1280, "height": 720}, "canvas")
	t.eq(b["glyphs"].size(), 4, "glyph count (no spaces)")
	t.eq(b["frames"].size(), int(round(float(b["duration"]) * 20.0)), "frame count = duration * fps")
	var ok_shape := true
	for fr in b["frames"]:
		if fr.size() != 4:
			ok_shape = false
		for v in fr:
			if v.size() != 6:
				ok_shape = false
	t.ok(ok_shape, "frames [frame][glyph][6]")
	var g0: Dictionary = b["glyphs"][0]
	for k in ["index", "char", "role", "font_size", "base", "rot"]:
		t.ok(g0.has(k), "glyph has " + k)
	t.eq(b["frames"][0][0][5], 0.0, "first glyph hidden at t=0")
	var mid: Array = b["frames"][int(b["frames"].size() / 2)][0]
	t.eq(mid[5], 1.0, "visible in hold")
	t.eq(mid[0], 0.0, "no offset in hold")
	# 3자리 반올림
	var all_rounded := true
	for fr in b["frames"]:
		for v in fr:
			for x in v:
				if absf(float(x) * 1000.0 - round(float(x) * 1000.0)) > 0.001:
					all_rounded = false
	t.ok(all_rounded, "values rounded to 3 decimals")
	t.eq(JSON.stringify(Baked.bake(d, 20.0)), JSON.stringify(b), "bake deterministic")
	var parsed: Variant = JSON.parse_string(JSON.stringify(b))
	t.ok(parsed is Dictionary and parsed["frames"].size() == b["frames"].size(), "json serializable")
	# loop_hold 마커
	d["timeline"]["loop"] = "loop_hold"
	var bh := Baked.bake(d, 10.0)
	t.eq(bh["loop"], "loop_hold", "loop field")
	t.ok(float(bh["markers"]["hold_end"]) > float(bh["markers"]["hold_start"]), "hold markers")
	# center_stamp 오버레이 슬롯
	d["timeline"]["loop"] = "once"
	d["timeline"]["enter"]["effect"] = "center_stamp"
	var bs := Baked.bake(d, 30.0)
	t.eq(bs["glyphs"].size(), 8, "overlay glyph slots appended")
	t.eq(bs["glyphs"][4]["role"], "overlay", "overlay role")
	t.eq(bs["frames"][2][4][5] > 0.0, true, "overlay visible early")
	t.eq(bs["frames"][2][0][5], 0.0, "normal glyph hidden early")
	_overlay_matches_runtime(t, 0.25, 3.0, false)
	_overlay_matches_runtime(t, 0.253, 3.0, true)
	_overlay_matches_runtime(t, 0.0, 3.0, true)
	_overlay_matches_runtime(t, 0.0, 3.123, false)


## 베이크가 지원하는 위치·크기·축척·회전·알파를 같은 시간의 런타임 상태와 비교한다.
func _overlay_matches_runtime(t, viewport_scale: float, big_scale: float, animated: bool) -> void:
	var doc := Doc.defaults()
	doc["text"] = "경계"
	doc["sub_text"] = "OPEN"
	doc["layout"]["font_size"] = 96
	doc["layout"]["anchor"] = [0.25, 0.7]
	doc["layout"]["offset"] = [17.0, -11.0]
	doc["timeline"]["enter"].merge({"effect": "center_stamp", "duration": 0.4,
		"params": {"viewport_scale": viewport_scale, "big_scale": big_scale, "solo_animated": animated,
			"hold_each": 0.3, "pause": 0.1}}, true)
	var runtime := Evaluator.new(doc)
	var baked := Baked.bake(doc, 30.0)
	var name := "overlay viewport=%s big=%s animated=%s" % [viewport_scale, big_scale, animated]
	var slots := {}
	for glyph in baked["glyphs"]:
		if glyph["role"] == "overlay":
			slots[int(glyph["source"])] = int(glyph["index"])
	var first: Dictionary = baked["glyphs"][slots[0]]
	var size := 720.0 * viewport_scale if viewport_scale > 0.0 else 96.0 * big_scale
	t.eq(first["font_size"], roundi(size), name + " metadata size")
	var center := Vector2(640, 360) if viewport_scale > 0.0 else Vector2(337, 493)
	t.eq(first["base"], [center.x, center.y], name + " metadata center")
	var max_position_error := 0.0
	var max_size_error := 0.0
	var max_rotation_error := 0.0
	var max_alpha_error := 0.0
	var visible := 0
	for frame_index in baked["frames"].size():
		var time := float(frame_index) / 30.0
		for state in runtime.evaluate(time):
			if not state.visible:
				continue
			var slot: int = slots[state.index] if state.overlay else state.index
			var glyph: Dictionary = baked["glyphs"][slot]
			var frame: Array = baked["frames"][frame_index][slot]
			var position := Vector2(float(glyph["base"][0]) + float(frame[0]), float(glyph["base"][1]) + float(frame[1]))
			var expected_size: Vector2 = state.scale * float(runtime.layout["glyphs"][state.index]["font_size"])
			if state.overlay:
				visible += 1
				expected_size *= state.overlay_scale
			var actual_size := Vector2(float(frame[2]), float(frame[3])) * float(glyph["font_size"])
			max_position_error = maxf(max_position_error, position.distance_to(state.pos))
			max_size_error = maxf(max_size_error, actual_size.distance_to(expected_size))
			max_rotation_error = maxf(max_rotation_error, absf(float(glyph["rot"]) + float(frame[4]) - state.rotation))
			max_alpha_error = maxf(max_alpha_error, absf(float(frame[5]) - state.alpha))
	t.ok(visible > 0, name + " visible overlay sampled")
	t.ok(max_position_error <= 0.0015, name + " positions match runtime")
	# 프레임 배율은 소수 셋째 자리 포맷이므로 글자 크기에 비례한 양자화 오차만 허용한다.
	t.ok(max_size_error <= maxf(96.0, size) * 0.00072 + 0.001, name + " rendered size/scale match runtime")
	t.ok(max_rotation_error <= 0.001, name + " rotation matches runtime")
	t.ok(max_alpha_error <= 0.00051, name + " alpha matches runtime")
