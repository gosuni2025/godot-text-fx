class_name TextFxBakePlan
extends RefCounted
## 평가기(레이아웃·문서)에서 굽기 작업(job) 목록과 글자 → 스프라이트 키 표를 만든다.
## 블록 좌표 그라데이션은 글자 인스턴스마다 셀이 달라야 하므로 키에 글자 번호가 들어간다.
## 그 밖에는 (역할, 문자, 픽셀 크기)가 같으면 셀을 공유한다.
## center_stamp를 쓰면 본문 글자를 big_scale배 크기로 따로 굽는 "overlay" job을 추가한다.
##
## build(ev, fonts, bake_scale) → { jobs, glyph_keys: PackedStringArray(글자 번호 → 키), overlay_keys: {글자 번호: 키}, signature }

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Timing := preload("res://addons/text_fx/core/fx_timing_helpers.gd")


static func build(ev: RefCounted, fonts: Dictionary, bake_scale: float) -> Dictionary:
	var doc: Dictionary = ev.doc
	var layout: Dictionary = ev.layout
	var glyphs: Array = layout["glyphs"]
	var keys := PackedStringArray()
	keys.resize(glyphs.size())
	var jobs: Array = []
	var blur_em := maxf(Enter.max_blur_em(doc["timeline"]["enter"]), Enter.max_blur_em(doc["timeline"]["exit"]))
	blur_em = maxf(blur_em, Enter.max_blur_em(Timing.sub_segment(doc)))
	# 블록 효과는 보조 글자에도 본문의 em을 쓴다. 작은 sub 셀도 같은 반경을 수용해야 한다.
	var max_font := 0.0
	for glyph in glyphs:
		max_font = maxf(max_font, float(glyph["font_size"]))
	for role in ["main", "sub"]:
		var style: Dictionary = Doc.style_for(doc, role)
		var fill: Dictionary = style["fill"]
		var gradient: bool = fill["type"] == "gradient"
		var space: String = fill["gradient"]["space"]
		var dir := Vector2.from_angle(deg_to_rad(float(fill["gradient"]["angle"])))
		var entries: Array = []
		for g in glyphs:
			if g["role"] != role:
				continue
			var size_px := maxi(1, int(round(float(g["font_size"]) * bake_scale)))
			var key := "%s|%s|%d" % [role, g["char"], size_px]
			var e := {"char": g["char"], "size_px": size_px}
			if gradient:
				if space in ["block", "line"]:
					key = "%s|#%d|%d" % [role, int(g["index"]), size_px]
					var pg: Dictionary = layout["pages"][int(g["page"])]
					var region: Rect2 = pg["main_rect"] if role == "main" else pg["sub_rect"]
					if space == "line":
						region = layout["lines"][int(g["line"])]["rect"]
					var ab := block_coeffs(region, dir, g["pos"], float(g["base_rotation"]), bake_scale)
					e["grad_a"] = ab[0]
					e["grad_b"] = ab[1]
				else:
					var ab2 := glyph_coeffs(g["box"], dir, bake_scale)
					e["grad_a"] = ab2[0]
					e["grad_b"] = ab2[1]
			e["key"] = key
			keys[int(g["index"])] = key
			entries.append(e)
		if not entries.is_empty():
			jobs.append({"id": role, "font": fonts[role], "style": style, "scale": bake_scale, "gradient": gradient,
				"entries": entries, "blur_em": blur_em, "blur_px": max_font * bake_scale * blur_em})
	var overlay_keys := {}
	if ev.timeline.stamp_enabled:
		var big := float(doc["timeline"]["enter"]["params"].get("big_scale", 3.0))
		var viewport_scale := float(doc["timeline"]["enter"]["params"].get("viewport_scale", 0.0))
		if viewport_scale > 0.0:
			var canvas: Vector2 = layout["canvas"]
			for glyph in glyphs:
				if glyph["role"] == "main":
					big = minf(canvas.x, canvas.y) * viewport_scale / maxf(1.0, float(glyph["font_size"]))
					break
		var style: Dictionary = Doc.style_for(doc, "main")
		var dir := Vector2.from_angle(deg_to_rad(float(style["fill"]["gradient"]["angle"])))
		var entries: Array = []
		var sc := bake_scale * big
		for g in glyphs:
			if g["role"] != "main":
				continue
			var size_px := maxi(1, int(round(float(g["font_size"]) * sc)))
			var key := "ov|%s|%d" % [g["char"], size_px]
			var ab := glyph_coeffs((g["box"] as Vector2) * big, dir, sc / big)
			entries.append({"key": key, "char": g["char"], "size_px": size_px, "grad_a": ab[0], "grad_b": ab[1]})
			overlay_keys[int(g["index"])] = key
		if not entries.is_empty():
			jobs.append({"id": "overlay", "font": fonts["main"], "style": style, "scale": sc,
				"gradient": style["fill"]["type"] == "gradient", "entries": entries, "blur_em": blur_em,
				"blur_px": max_font * sc * blur_em})
	_add_morph_jobs(jobs, ev.text_morph, doc, fonts, bake_scale, blur_em)
	return {"jobs": jobs, "glyph_keys": keys, "overlay_keys": overlay_keys, "signature": signature(doc, layout, bake_scale)}


static func _add_morph_jobs(jobs: Array, morph: Dictionary, doc: Dictionary, fonts: Dictionary, scale: float, blur_em: float) -> void:
	for group in morph.get("groups", []):
		var role: String = group["role"]
		var style := Doc.style_for(doc, role)
		var fill: Dictionary = style["fill"]
		var gradient: bool = fill["type"] == "gradient"
		var space: String = fill["gradient"]["space"]
		var dir := Vector2.from_angle(deg_to_rad(float(fill["gradient"]["angle"])))
		var entries: Array = []
		var largest := 0.0
		var source: Dictionary = group["layout"]
		for glyph in group["sources"]:
			var size := float(glyph["font_size"])
			largest = maxf(largest, size)
			var entry := {"key": glyph["sprite_key"], "char": glyph["char"], "size_px": maxi(1, roundi(size * scale))}
			if gradient:
				var ab: Array
				if space in ["block", "line"]:
					var rect: Rect2 = source["pages"][0]["main_rect" if role == "main" else "sub_rect"]
					if space == "line":
						rect = source["lines"][int(glyph["line"])]["rect"]
					ab = block_coeffs(rect, dir, glyph["pos"], float(glyph["base_rotation"]), scale)
				else:
					ab = glyph_coeffs(glyph["box"], dir, scale)
				entry["grad_a"] = ab[0]
				entry["grad_b"] = ab[1]
			entries.append(entry)
		if not entries.is_empty():
			jobs.append({"id": "morph_%s_%d" % [role, int(group["page"])], "font": fonts[role], "style": style,
				"scale": scale, "gradient": gradient, "entries": entries, "blur_em": blur_em, "blur_px": largest * scale * blur_em})


## 블록 영역 기준: P = pos + R(θ)·(V / s), t = (P·d - tmin) / len → t = V·a + b
static func block_coeffs(region: Rect2, dir: Vector2, pos: Vector2, rot: float, s: float) -> Array:
	var mm := _proj_range(region, dir)
	var length := maxf(0.001, mm.y - mm.x)
	var a := dir.rotated(-rot) / (s * length)
	var b := (pos.dot(dir) - mm.x) / length
	return [a, b]


## 글자 박스 기준(박스 중심 원점, 글자 자신의 좌표계).
static func glyph_coeffs(box: Vector2, dir: Vector2, s: float) -> Array:
	var mm := _proj_range(Rect2(-box * 0.5, box), dir)
	var length := maxf(0.001, mm.y - mm.x)
	return [dir / (s * length), -mm.x / length]


static func _proj_range(r: Rect2, d: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var v: float = (c as Vector2).dot(d)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return Vector2(lo, hi)


## 다시 구워야 하는지 판단하는 서명: 글자·크기·스타일·글꼴·배율이 같으면 같다.
static func signature(doc: Dictionary, layout: Dictionary, bake_scale: float) -> String:
	var parts: Array = [snappedf(bake_scale, 0.001), JSON.stringify(doc.get("style")), JSON.stringify(doc.get("sub_style")),
		JSON.stringify(doc.get("font")), JSON.stringify(doc.get("sub_font")), doc["timeline"]["enter"]["effect"],
		JSON.stringify(doc["timeline"]["enter"]["params"]), doc["timeline"]["exit"]["effect"],
		JSON.stringify(doc["timeline"]["exit"]["params"]), JSON.stringify(doc["timeline"].get("sub_enter")),
		JSON.stringify(doc["canvas"])]
	for g in layout["glyphs"]:
		parts.append("%s%d%s" % [g["char"], int(g["font_size"]), str(g["pos"])])
	return str(hash(parts))
