extends RefCounted
## 타자기 커서를 장식 사각형 상태로 계산한다. 입력창이나 노드를 만들지 않는다.

const Timing := preload("res://addons/text_fx/core/fx_timing_helpers.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")


static func evaluate(doc: Dictionary, layout: Dictionary, timeline: RefCounted, sample: Dictionary, states: Array) -> Array:
	if sample["phase"] not in ["enter", "hold"] or timeline.scroll_speed > 0.0:
		return []
	var out: Array = []
	var tl: Dictionary = doc["timeline"]
	var vertical: bool = layout["direction"] == "vertical"
	for role in ["main", "sub"]:
		var seg: Dictionary = Timing.sub_segment(doc) if role == "sub" else tl["enter"]
		var params: Dictionary = seg.get("params", {})
		if not bool(params.get("cursor", false)) or seg["effect"] in Enter.BLOCK_EFFECTS or seg["effect"] == "center_stamp":
			continue
		var last := -1
		var completed := 0.0
		for i in layout["glyphs"].size():
			var g: Dictionary = layout["glyphs"][i]
			if g["page"] != sample["page"] or g["role"] != role:
				continue
			completed = maxf(completed, float(timeline.enter_delay[i]) + float(seg["duration"]))
			if states[i].visible and states[i].alpha > 0.001:
				last = i
		if last < 0:
			continue
		var page_time := float(sample["page_time"])
		var blink := maxf(0.05, float(params.get("cursor_blink", 0.6)))
		if page_time >= completed and fposmod(page_time - completed, blink) >= blink * 0.5:
			continue
		var g: Dictionary = layout["glyphs"][last]
		var st = states[last]
		var em := float(g["font_size"])
		var thin := maxf(1.0, em * 0.045)
		var pos: Vector2 = st.pos
		var advance := float(g["advance"])
		var rect := Rect2(pos + Vector2(advance * 0.5 + thin, -em * 0.5), Vector2(thin, em))
		if vertical:
			rect = Rect2(pos + Vector2(-em * 0.5, advance * 0.5 + thin), Vector2(em, thin))
		var style: Dictionary = Doc.style_for(doc, role)
		var color: Variant = params.get("cursor_color")
		if not (color is String):
			color = style["fill"]["color"]
		out.append({"type": "cursor", "rects": [rect], "color": Doc.parse_color(color),
			"outline": false, "outline_color": Color.TRANSPARENT, "outline_size": 0.0,
			"alpha": float(style["opacity"])})
	return out
