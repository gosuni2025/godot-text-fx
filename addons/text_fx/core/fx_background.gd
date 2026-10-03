class_name TextFxBackground
extends RefCounted
## 결과물 배경. 첫 등장·마지막 퇴장에만 동기화하며 페이지 사이에서는 유지한다.
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")

static func evaluate(doc: Dictionary, layout: Dictionary, timeline: RefCounted, sample: Dictionary) -> Dictionary:
	var bg: Dictionary = doc.get("background", Doc.default_background())
	var page := int(sample["page"])
	if bg.get("type", "none") == "none" or sample["phase"] == "end" or page >= timeline.pages.size():
		return {}
	var p: Dictionary = timeline.pages[page]
	var time := float(p["start"]) + float(sample["page_time"])
	if time < timeline.lead_in or (timeline.lead_out > 0.0 and time >= timeline.content_end):
		return {}
	var alpha := float(bg.get("opacity", 1.0))
	if bg.get("sync_fade", true):
		if page == 0 and sample["phase"] == "enter":
			alpha *= clampf(float(sample["local"]) / maxf(0.001, float(p["enter_len"])), 0.0, 1.0)
		elif sample["phase"] == "exit" and sample.get("final", false):
			alpha *= 1.0 - clampf(float(sample["local"]) / maxf(0.001, float(p["exit_len"])), 0.0, 1.0)
	return {"type": bg["type"], "color": Doc.parse_color(bg["color"]), "opacity": alpha,
		"extent": float(bg.get("extent", 0.6)), "canvas": layout["canvas"]}
