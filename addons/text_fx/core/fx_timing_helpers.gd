extends RefCounted
## 역할별 타이밍과 글자 순서의 보조 계산. 노드·시계·전역 난수에 의존하지 않는다.

const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")


static func sub_segment(doc: Dictionary) -> Dictionary:
	var tl: Dictionary = doc["timeline"]
	var sub: Variant = tl.get("sub_enter")
	if not (sub is Dictionary):
		return tl["enter"]
	var result: Dictionary = sub.duplicate(true)
	if result.get("effect", "same") == "same":
		result["effect"] = tl["enter"]["effect"]
		result["easing"] = tl["enter"]["easing"]
		result["params"] = tl["enter"]["params"].duplicate(true)
		if result["effect"] in Enter.BLOCK_EFFECTS:
			for key in ["duration", "order", "stagger"]:
				result[key] = tl["enter"][key]
	return result


static func main_count(glyphs: Array, first: int, count: int) -> int:
	var n := 0
	for i in range(first, first + count):
		if glyphs[i]["role"] == "main":
			n += 1
	return n


static func overlap_hold(seg: Dictionary, is_exit: bool = false) -> float:
	if is_exit or seg["effect"] != "center_split":
		return 0.0
	return maxf(0.0, float(seg.get("params", {}).get("overlap_hold", 0.0)))


## sweep은 유효 행 시작 간격 + 글자 중심의 행 길이 비율로 지연한다.
static func sweep_delays(glyphs: Array, lines: Array, first: int, count: int, params: Dictionary, vertical: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var line_rank := {}
	var interval := maxf(0.0, float(params.get("line_stagger", 0.0)))
	var sweep := maxf(0.0, float(params.get("sweep_duration", 0.0)))
	for i in count:
		var g: Dictionary = glyphs[first + i]
		var ln := int(g["line"])
		if not line_rank.has(ln):
			line_rank[ln] = line_rank.size()
		var r: Rect2 = lines[ln]["rect"]
		var p: Vector2 = g["pos"]
		var length := r.size.y if vertical else r.size.x
		var along := p.y - r.position.y if vertical else p.x - r.position.x
		out[i] = float(line_rank[ln]) * interval + clampf(along / maxf(length, 0.001), 0.0, 1.0) * sweep
	return out


static func punctuation_pause(g: Dictionary, params: Dictionary) -> float:
	if not bool(g.get("punct", false)):
		return 0.0
	var short := maxf(0.0, float(params.get("punct_pause", 0.0)))
	var long := maxf(0.0, float(params.get("punct_long_pause", 0.0)))
	return maxf(short, long) if str(g["char"]) in [".", "。", "．", "!", "！", "?", "？", "…", "‥"] else short


## 중앙 한 글자 표시의 시작 시각. 공백/명시적 줄바꿈 묶음은 하나의 쉼을 차지한다.
static func stamp_slots(glyphs: Array, first: int, count: int, params: Dictionary) -> Dictionary:
	var slots: Array = []
	var time := 0.0
	var each := maxf(0.0, float(params.get("hold_each", 0.28)))
	var space := maxf(0.0, float(params.get("space_pause", 0.0)))
	for i in range(first, first + count):
		var g: Dictionary = glyphs[i]
		if g["role"] != "main":
			continue
		if bool(g.get("separator_before", false)):
			time += space
		slots.append({"index": i, "start": time, "duration": each})
		time += each
	return {"slots": slots, "duration": time + maxf(0.0, float(params.get("pause", 0.3)))}


static func scroll_offset(layout: Dictionary, speed: float, local: float) -> Vector2:
	if layout["pages"].is_empty():
		return Vector2.ZERO
	var rect: Rect2 = layout["pages"][0]["rect"]
	var canvas: Vector2 = layout["canvas"]
	if layout["direction"] == "vertical":
		return Vector2(-rect.end.x + speed * local, 0.0)
	return Vector2(0.0, canvas.y - rect.position.y - speed * local)


static func edge_alpha(pos: Vector2, layout: Dictionary, fraction: float) -> float:
	if fraction <= 0.0:
		return 1.0
	var vertical: bool = layout["direction"] == "vertical"
	var canvas: Vector2 = layout["canvas"]
	var extent := canvas.x if vertical else canvas.y
	var along := pos.x if vertical else pos.y
	var width := extent * clampf(fraction, 0.0, 0.5)
	return clampf(minf(along, extent - along) / maxf(0.001, width), 0.0, 1.0)
