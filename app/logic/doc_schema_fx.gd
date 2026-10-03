extends RefCounted
## 포맷 2 연출 필드. UI·봇·명령이 같은 범위와 선택지를 공유한다.
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")

static func n(lo: float, hi: float) -> Dictionary:
	return {"t": "num", "min": lo, "max": hi}

static func e(values: Array) -> Dictionary:
	return {"t": "enum", "v": values}

static func extend_rules(r: Dictionary) -> void:
	var b := {"t": "bool"}
	var c := {"t": "color"}
	r["layout.sub.letter_spacing"] = n(-0.5, 2)
	for key in ["lead_in", "lead_out"]:
		r["timeline." + key] = n(0, 60)
	for key in ["split_pages", "exit_between_pages"]:
		r["timeline." + key] = b
	r["timeline.hold.scope"] = e(["hold", "visible"])
	r["timeline.scroll.edge_fade"] = n(0, 0.5)
	r["timeline.sub_enter"] = {"t": "null_or_dict"}
	r["timeline.sub_enter.effect"] = e(["same"] + Array(Doc.Enter.IDS))
	r["timeline.sub_enter.delay"] = n(-30, 30)
	for seg in ["enter", "exit", "sub_enter"]:
		var q: String = "timeline." + seg + ".params."
		for key in ["line_pause", "punct_long_pause", "space_pause", "overlap_hold", "line_stagger", "sweep_duration", "impact_duration"]:
			r[q + key] = n(0, 10)
		for key in ["rate", "cursor_blink"]:
			r[q + key] = n(0, 60)
		for key in ["impact", "brightness", "impact_brightness", "min_alpha", "feather"]:
			r[q + key] = n(0, 1)
		for key in ["shake", "impact_shake", "glow"]:
			r[q + key] = n(0, 10)
		r[q + "axis"] = e(["auto", "horizontal", "vertical"])
		r[q + "slices"] = {"t": "int", "min": 1, "max": 16}
		r[q + "viewport_scale"] = n(0, 1)
		r[q + "cursor"] = b
		r[q + "solo_animated"] = b
		r[q + "cursor_color"] = {"t": "null_or_color"}
		for key in ["color_a", "color_b"]:
			r[q + key] = c
	r["timeline.hold.effects.*.min_strength"] = n(0, 4)
	var d := "decorations.*."
	for key in ["fill_color"]:
		r[d + key] = c
	for key in ["fill_opacity", "softness", "end_fade", "arm_length", "blink_strength"]:
		r[d + key] = n(0, 1)
	for key in ["full_span", "lead_text", "protect_sub", "clamp_canvas", "follow_block"]:
		r[d + key] = b
	r[d + "radius"] = n(0, 128)
	r[d + "stripe_width"] = n(2, 256)
	r[d + "stripe_speed"] = n(-500, 500)
	for key in ["blink_period", "exit_delay", "exit_duration"]:
		r[d + key] = n(0, 30)
	r["background"] = {"t": "dict"}
	r["background.type"] = e(["none", "solid", "vignette", "bottom", "top"])
	r["background.color"] = c
	r["background.opacity"] = n(0, 1)
	r["background.extent"] = n(0.01, 1)
	r["background.sync_fade"] = b
