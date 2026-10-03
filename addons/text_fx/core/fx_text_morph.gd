extends RefCounted
## 원문과 최종 문장을 독립 배치하고, 공통 글자는 이어 움직이며 나머지는 녹여 교체한다.
## 시간 이력 없이 준비된 글자 대응과 페이지 경과 시각만 사용한다.

const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const State := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Hash := preload("res://addons/text_fx/core/fx_hash.gd")


static func prepare(doc: Dictionary, layout: Dictionary, fonts: Dictionary = {}, timeline: RefCounted = null) -> Dictionary:
	var result := {"groups": [], "glyphs": []}
	var tl: Dictionary = doc["timeline"]
	if tl.get("scroll") is Dictionary:
		return result
	var pages := Layout.split_pages(doc)
	var segments := {}
	var source_pages := {}
	for role in ["main", "sub"]:
		var segment: Variant = tl["enter"] if role == "main" else tl.get("sub_enter")
		if not segment is Dictionary or segment.get("effect") != "text_morph":
			continue
		if str(segment["params"].get("from_text", "")).strip_edges().is_empty():
			continue
		segments[role] = segment
		var field := "text" if role == "main" else "sub_text"
		var source_doc := doc.duplicate(true)
		source_doc[field] = str(segment["params"].get("from_text", ""))
		# 반대 역할의 페이지 수가 원문의 단일 페이지 여부를 바꾸지 않아야 한다.
		source_doc["sub_text" if role == "main" else "text"] = ""
		source_pages[role] = Layout.split_pages(source_doc)
	for role in segments:
		for page in layout["pages"].size():
			var after_main: bool = role == "sub" and segments.has("main") and timeline != null and float(timeline.pages[page]["sub_enter_start"]) >= float(timeline.pages[page]["main_enter_len"])
			var single := doc.duplicate(true)
			single["mode"] = "message"
			single["text"] = pages[page][0]
			single["sub_text"] = pages[page][1]
			for source_role in segments:
				if after_main and source_role == "main":
					continue
				single["text" if source_role == "main" else "sub_text"] = _page_text(source_pages[source_role], source_role, page, layout["pages"].size())
			var source_layout := Layout.compute(single, fonts)
			if after_main:
				_align_sub_to_finished_main(source_layout, layout, doc, page)
			var sources: Array = []
			var targets: Array = []
			var companions: Array = []
			for original in source_layout["glyphs"]:
				if original["role"] != role:
					continue
				var glyph: Dictionary = original.duplicate(true)
				glyph["index"] = layout["glyphs"].size() + result["glyphs"].size()
				glyph["page"] = page
				glyph["sprite_key"] = "morph|%d" % int(glyph["index"])
				glyph["source_index"] = original["index"]
				sources.append(glyph)
				result["glyphs"].append(glyph)
			for glyph in layout["glyphs"]:
				if glyph["role"] == role and int(glyph["page"]) == page:
					targets.append(glyph)
				elif int(glyph["page"]) == page and not segments.has(glyph["role"]):
					companions.append(glyph)
			var pairs := _pair(sources, targets)
			var matched := {}
			for source in pairs.values():
				matched[int(source["index"])] = true
			var companion_sources: Array = source_layout["glyphs"].filter(func(glyph): return glyph["role"] != role)
			result["groups"].append({"role": role, "page": page, "segment": segments[role],
				"layout": source_layout, "sources": sources, "targets": targets,
				"pairs": pairs, "matched_sources": matched, "companions": companions,
				"companion_pairs": _pair(companion_sources, companions)})
	return result


## 순차 보조 변이의 기준은 이미 끝난 본문이다. 원문 높이 때문에 그 본문 위로 올라오지 않게 한다.
static func _align_sub_to_finished_main(source: Dictionary, target: Dictionary, doc: Dictionary, page: int) -> void:
	if not target["glyphs"].any(func(glyph): return glyph["role"] == "main" and int(glyph["page"]) == page):
		return
	var main: Rect2 = target["pages"][page]["main_rect"]
	var sub: Rect2 = source["pages"][0]["sub_rect"]
	var gap := float(doc["layout"]["sub"]["gap"]) * float(target["font_size"])
	var above: bool = doc["layout"]["sub"]["position"] == "above"
	var shift := Vector2.ZERO
	if target["direction"] == "vertical":
		shift.x = main.end.x + gap - sub.position.x if above else main.position.x - gap - sub.end.x
	else:
		shift.y = main.position.y - gap - sub.end.y if above else main.end.y + gap - sub.position.y
	for glyph in source["glyphs"]:
		if glyph["role"] == "sub":
			glyph["pos"] += shift
	for line in source["lines"]:
		if line["role"] == "sub":
			line["rect"].position += shift
			line["center"] += shift
	source["pages"][0]["sub_rect"].position += shift


static func _page_text(pages: Array, role: String, page: int, target_count: int) -> String:
	var column := 0 if role == "main" else 1
	if pages.size() == 1:
		return str(pages[0][column])
	if page >= pages.size():
		return ""
	var chunks := PackedStringArray([str(pages[page][column])])
	# 최종 문장 페이지 수를 유지하면서 초과 원문도 마지막 페이지에서 모두 보여 준다.
	if page == target_count - 1:
		for extra in range(page + 1, pages.size()):
			chunks.append(str(pages[extra][column]))
	return "\n\n".join(chunks)


## 동일 문자는 등장 순으로 일대일 대응한다. 반복 글자도 중복 사용하지 않는다.
static func _pair(sources: Array, targets: Array) -> Dictionary:
	var available := {}
	for glyph in sources:
		var character: String = glyph["char"]
		if not available.has(character):
			available[character] = []
		available[character].append(glyph)
	var pairs := {}
	var offsets := {}
	for glyph in targets:
		var options: Array = available.get(glyph["char"], [])
		var offset := int(offsets.get(glyph["char"], 0))
		if offset < options.size():
			pairs[int(glyph["index"])] = options[offset]
			offsets[glyph["char"]] = offset + 1
	return pairs


static func apply(data: Dictionary, states: Array, sample: Dictionary, timeline: RefCounted, seed: int) -> Array:
	var extras: Array = []
	if sample["phase"] != "enter":
		return extras
	var page := int(sample["page"])
	for group in data["groups"]:
		if int(group["page"]) != page:
			continue
		var seg: Dictionary = group["segment"]
		var params: Dictionary = seg["params"]
		var timing: Dictionary = timeline.pages[page]
		var start := float(timing.get("text_start", 0.0)) if group["role"] == "main" else float(timing.get("sub_enter_start", 0.0))
		var elapsed := float(sample["local"]) - start
		var duration := maxf(0.0, float(seg["duration"]))
		var q := clampf(elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0
		var readable := clampf(float(params.get("readable_ratio", 0.3)), 0.0, 0.8)
		var p := clampf((q - readable) / maxf(0.01, 1.0 - readable), 0.0, 1.0)
		var motion := smoothstep(0.0, 1.0, p)
		var strength := clampf(float(params.get("intensity", 1.0)), 0.0, 3.0)
		# 원문이 차지하는 줄 높이에 맞춰 변이하지 않는 반대 문구도 배치를 이어 간다.
		# 기존 등장 효과가 만든 이동·회전은 보존하고 기준 배치의 차이만 더한다.
		if q < 1.0:
			for glyph in group["companions"]:
				var source: Dictionary = group["companion_pairs"].get(int(glyph["index"]), {})
				if source.is_empty():
					continue
				var state: State = states[int(glyph["index"])]
				state.pos += (source["pos"] as Vector2).lerp(glyph["pos"], motion) - (glyph["pos"] as Vector2)
				state.scale *= lerpf(float(source["font_size"]) / maxf(1.0, float(glyph["font_size"])), 1.0, motion)
		for glyph in group["targets"]:
			var state: State = states[int(glyph["index"])]
			if elapsed < 0.0:
				state.alpha = 0.0
				continue
			if q >= 1.0:
				continue
			var source: Dictionary = group["pairs"].get(int(glyph["index"]), {})
			if not source.is_empty():
				state.pos = (source["pos"] as Vector2).lerp(glyph["pos"], motion)
				state.rotation = lerp_angle(float(source["base_rotation"]), float(glyph["base_rotation"]), motion)
				state.scale *= lerpf(float(source["font_size"]) / maxf(1.0, float(glyph["font_size"])), 1.0, motion)
			else:
				state.alpha *= smoothstep(0.25, 0.95, p)
				_distort(state, glyph, 1.0 - p, sin(PI * p) * strength, seed, false)
		for glyph in group["sources"]:
			if elapsed < 0.0 or q >= 1.0 or group["matched_sources"].has(int(glyph["index"])):
				continue
			var state := State.new()
			state.index = int(glyph["index"])
			state.character = glyph["char"]
			state.role = glyph["role"]
			state.page = page
			state.sprite_key = glyph["sprite_key"]
			state.pos = glyph["pos"]
			state.rotation = float(glyph["base_rotation"])
			state.alpha = 1.0 - smoothstep(0.10, 0.78, p)
			_distort(state, glyph, p, sin(PI * p) * strength, seed, true)
			state.visible = state.alpha > 0.0005
			extras.append(state)
	return extras


static func _distort(state: State, glyph: Dictionary, amount: float, wave: float, seed: int, outgoing: bool) -> void:
	var em := float(glyph["font_size"])
	var index := int(glyph["index"])
	var direction := Hash.signed(seed, index, 701)
	state.pos += Vector2(direction * em * wave * 0.10, em * wave * (0.22 if outgoing else -0.18))
	state.scale *= Vector2(maxf(0.15, 1.0 - 0.35 * wave), 1.0 + 0.48 * wave)
	state.rotation += direction * wave * 0.16
	if wave > 0.0001:
		state.slices.resize(7)
		for slice in 7:
			state.slices[slice] = sin(float(slice) * 0.9 + amount * TAU + direction) * em * wave * 0.065
