extends RefCounted
## 장식의 선택적 블록 추종. 가상의 중심 글자를 평가해 개별 글자 연출이 섞이지 않게 한다.

const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Stamp := preload("res://addons/text_fx/core/fx_center_stamp.gd")

const SHARED_HOLD := ["float", "block_shake", "block_glitch", "heartbeat"]


static func apply(decorations: Array, doc: Dictionary, layout: Dictionary, timeline: RefCounted, sample: Dictionary, scroll_offset: Vector2) -> void:
	if decorations.is_empty() or sample["phase"] not in ["enter", "hold", "exit"]:
		return
	var page := int(sample["page"])
	if page >= layout["pages"].size():
		return
	var area: Rect2 = layout["pages"][page]["rect"]
	var center := area.get_center()
	var st := GlyphState.new()
	st.pos = center
	var ctx := {"seed": int(doc["seed"]), "canvas": layout["canvas"], "vertical": layout["direction"] == "vertical",
		"em": float(layout["font_size"]), "block_em": float(layout["font_size"]),
		"block_center": center, "block_rect": area, "line_center": center, "phase": sample["phase"]}
	var tl: Dictionary = doc["timeline"]
	if sample["phase"] == "enter" and timeline.stamp_enabled:
		var motion := Stamp.block_motion(doc, timeline.pages[page], page, float(sample["local"]))
		st.pos += motion["offset"]
		st.scale *= float(motion["scale"])
	elif sample["phase"] in ["enter", "exit"]:
		var is_exit: bool = sample["phase"] == "exit"
		var seg: Dictionary = tl["exit"] if is_exit else tl["enter"]
		if seg["effect"] in Enter.BLOCK_EFFECTS:
			var local := float(sample["local"]) - (0.0 if is_exit else float(timeline.pages[page].get("text_start", 0.0)))
			if local >= 0.0:
				var duration := maxf(0.0, float(seg["duration"]))
				var p := 1.0 if duration <= 0.0 else clampf(local / duration, 0.0, 1.0)
				var e := Easing.apply(Enter.resolve_easing(str(seg["effect"]), str(seg["easing"]), is_exit), p)
				ctx.merge({"params": seg["params"], "local": local, "duration": duration, "is_exit": is_exit}, true)
				Enter.apply(str(seg["effect"]), st, e if is_exit else 1.0 - e, {}, ctx)
	var visible_scope: bool = tl["hold"].get("scope", "hold") == "visible"
	if sample["phase"] == "hold" or visible_scope:
		var time := float(sample["page_time"]) if visible_scope else float(sample["local"])
		for effect: Dictionary in tl["hold"]["effects"]:
			if effect.get("type", "") in SHARED_HOLD:
				Hold.apply(effect, st, time, {}, ctx)
	var origin := center + scroll_offset
	var shift := st.pos - center
	for decoration: Dictionary in decorations:
		if not bool(decoration.get("follow_block", false)):
			continue
		var factor := st.scale if decoration["type"] == "box" else Vector2.ONE
		var rects: Array = decoration["rects"]
		for i in rects.size():
			rects[i] = _transform(rects[i], origin, shift, factor)
		if decoration.get("fill_rect") is Rect2:
			decoration["fill_rect"] = _transform(decoration["fill_rect"], origin, shift, factor)


static func _transform(rect: Rect2, origin: Vector2, shift: Vector2, factor: Vector2) -> Rect2:
	return Rect2(origin + (rect.position - origin) * factor + shift, rect.size * factor)
