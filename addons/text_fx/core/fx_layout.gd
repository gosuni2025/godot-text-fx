class_name TextFxLayout
extends RefCounted
## 줄바꿈·금칙·세로쓰기·자동 축소 → 글자 배치(DESIGN §3). 노드·렌더링 없이 동작한다.
##
## compute(doc, fonts) → Dictionary
##   canvas: Vector2, direction, font_size, sub_font_size, shrink(축소 비율), page_count, fit_ratio
##   glyphs: [{ index, char, role, page, line(전체 줄 번호), line_in_page, col(줄 안 순번), word(페이지 안 단어 번호),
##              pos(글자 박스 중심), box(Vector2 가로 기준 글자 박스), advance, font_size,
##              vertical_rotate, base_rotation, punct }]
##   lines:  [{ index, page, role, rect, center, first, count }]
##   pages:  [{ index, rect, main_rect, sub_rect, glyph_first, glyph_count, line_first, line_count }]
## 공백·줄바꿈은 글자로 내보내지 않고 위치만 차지한다(순서 rank에서 빠짐).
## trailer 모드(스크롤 없음)에서 빈 줄은 페이지 구분이다. sub_text도 같은 방식으로 나눠 같은 번호 페이지에 붙인다.

const FontRes := preload("res://addons/text_fx/core/fx_font.gd")
const Rules := preload("res://addons/text_fx/core/fx_text_rules.gd")

const MAX_SHRINK_STEPS := 24


static func resolve_fonts(doc: Dictionary) -> Dictionary:
	var main_spec: Variant = doc.get("font", {})
	var sub_spec: Variant = doc.get("sub_font") if doc.get("sub_font") is Dictionary else main_spec
	return {"main": FontRes.resolve(main_spec), "sub": FontRes.resolve(sub_spec)}


static func split_pages(doc: Dictionary) -> Array:
	var tl: Dictionary = doc.get("timeline", {})
	var paged: bool = doc.get("mode", "message") == "trailer" and not (tl.get("scroll") is Dictionary)
	var mp := _split(str(doc.get("text", "")), paged)
	var sp := _split(str(doc.get("sub_text", "")), paged)
	var n := maxi(1, maxi(mp.size(), sp.size()))
	var out: Array = []
	for i in n:
		out.append([mp[i] if i < mp.size() else "", sp[i] if i < sp.size() else ""])
	return out


static func _split(text: String, paged: bool) -> PackedStringArray:
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	var out := PackedStringArray()
	if text == "":
		return out
	if not paged:
		out.append(text)
		return out
	var cur := PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges() == "":
			if not cur.is_empty():
				out.append("\n".join(cur))
				cur = PackedStringArray()
		else:
			cur.append(line)
	if not cur.is_empty():
		out.append("\n".join(cur))
	return out


static func compute(doc: Dictionary, fonts: Dictionary = {}) -> Dictionary:
	var f: Dictionary = fonts if (fonts.has("main") and fonts.has("sub")) else resolve_fonts(doc)
	var L: Dictionary = doc["layout"]
	var pages := split_pages(doc)
	var base_fs := maxi(1, int(L["font_size"]))
	var base_sub := maxi(1, int(L["sub"]["font_size"]))
	var min_fs := mini(maxi(1, int(L["min_font_size"])), base_fs)
	var fs := base_fs
	var res: Dictionary = {}
	for _i in MAX_SHRINK_STEPS:
		var sub_fs := maxi(1, int(round(float(base_sub) * float(fs) / float(base_fs))))
		res = _layout_at(doc, pages, f, fs, sub_fs)
		if not bool(L["auto_shrink"]) or fs <= min_fs:
			break
		var ratio: float = res["fit_ratio"]
		if ratio >= 0.999:
			break
		var nfs := int(floor(float(fs) * clampf(ratio, 0.5, 0.97)))
		if nfs >= fs:
			nfs = fs - 1
		fs = maxi(min_fs, nfs)
	res["shrink"] = float(fs) / float(base_fs)
	return res


static func _layout_at(doc: Dictionary, pages: Array, fonts: Dictionary, fs: int, sfs: int) -> Dictionary:
	var L: Dictionary = doc["layout"]
	var canvas := Vector2(float(doc["canvas"]["width"]), float(doc["canvas"]["height"]))
	var vertical: bool = L["direction"] == "vertical"
	var scrolling: bool = doc["timeline"].get("scroll") is Dictionary
	var wrap: String = L["wrap"]
	var kinsoku: bool = L["kinsoku"]
	var max_w := float(L["max_width"]) * canvas.x
	var max_h := float(L["max_height"]) * canvas.y
	var limit := 0.0
	if wrap != "none":
		limit = max_h if vertical else max_w
		if vertical and scrolling:
			limit = max_h
	var font_m: Font = fonts["main"]
	var font_s: Font = fonts["sub"]
	var ls := float(L["letter_spacing"])
	var lh := float(L["line_height"])
	var anchor := _vec(L["anchor"], Vector2(0.5, 0.5))
	var offset := _vec(L["offset"], Vector2.ZERO)
	var anchor_pt := canvas * anchor + offset
	var res := {
		"canvas": canvas, "direction": L["direction"], "font_size": fs, "sub_font_size": sfs,
		"page_count": pages.size(), "glyphs": [], "lines": [], "pages": [], "fit_ratio": 1.0,
	}
	var fit := INF
	for p in pages.size():
		var main_lines := _break_role(str(pages[p][0]), font_m, fs, ls * fs, limit, wrap, kinsoku, vertical)
		var sub_lines := _break_role(str(pages[p][1]), font_s, sfs, ls * sfs, limit, wrap, kinsoku, vertical)
		var step_m := lh * fs
		var step_s := lh * sfs
		var main_len := _max_len(main_lines)
		var sub_len := _max_len(sub_lines)
		var main_cross := main_lines.size() * step_m
		var sub_cross := sub_lines.size() * step_s
		var gap := float(L["sub"]["gap"]) * fs if (main_lines.size() > 0 and sub_lines.size() > 0) else 0.0
		var block_len := maxf(main_len, sub_len)
		var block_cross := main_cross + gap + sub_cross
		var size := Vector2(block_cross, block_len) if vertical else Vector2(block_len, block_cross)
		var block := Rect2(anchor_pt.x - size.x * _frac(L["align"]), anchor_pt.y - size.y * _vfrac(L["valign"]), size.x, size.y)
		var sub_first: bool = L["sub"]["position"] == "above"
		var main_off := (sub_cross + gap) if sub_first else 0.0
		var sub_off := 0.0 if sub_first else (main_cross + gap)
		var page := {"index": p, "rect": block, "glyph_first": res["glyphs"].size(), "line_first": res["lines"].size()}
		var ctx := {"res": res, "page": p, "block": block, "block_len": block_len, "vertical": vertical, "L": L, "word": -1, "line_first": res["lines"].size()}
		page["main_rect"] = _place(ctx, main_lines, "main", font_m, fs, step_m, main_off)
		page["sub_rect"] = _place(ctx, sub_lines, "sub", font_s, sfs, step_s, sub_off)
		if main_lines.is_empty():
			page["main_rect"] = page["sub_rect"] if not sub_lines.is_empty() else block
		if sub_lines.is_empty():
			page["sub_rect"] = Rect2(block.position, Vector2.ZERO)
		page["glyph_count"] = res["glyphs"].size() - int(page["glyph_first"])
		page["line_count"] = res["lines"].size() - int(page["line_first"])
		res["pages"].append(page)
		if size.x > 0.0 and not (scrolling and vertical):
			fit = minf(fit, max_w / size.x)
		if size.y > 0.0 and not (scrolling and not vertical):
			fit = minf(fit, max_h / size.y)
	res["fit_ratio"] = 1.0 if fit == INF else fit
	return res


## 줄들을 블록 안에 배치하고 그 역할 영역 rect를 돌려준다.
static func _place(ctx: Dictionary, lines: Array, role: String, font: Font, size: int, step: float, cross_off: float) -> Rect2:
	var res: Dictionary = ctx["res"]
	var block: Rect2 = ctx["block"]
	var block_len: float = ctx["block_len"]
	var vertical: bool = ctx["vertical"]
	var L: Dictionary = ctx["L"]
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var box_h := asc + desc
	var area := Rect2()
	var have := false
	for k in lines.size():
		var line: Dictionary = lines[k]
		var length: float = line["length"]
		var rect: Rect2
		var origin: Vector2
		if vertical:
			var cx := block.end.x - cross_off - (float(k) + 0.5) * step
			var top := block.position.y + (block_len - length) * _vfrac(L["valign"])
			rect = Rect2(cx - step * 0.5, top, step, length)
			origin = Vector2(cx, top)
		else:
			var top := block.position.y + cross_off + float(k) * step
			var left := block.position.x + (block_len - length) * _frac(L["align"])
			rect = Rect2(left, top, length, step)
			origin = Vector2(left, top + step * 0.5)
		var line_index: int = res["lines"].size()
		var first: int = res["glyphs"].size()
		var col := 0
		for gl in line["glyphs"]:
			var c: String = gl["c"]
			if bool(gl["wb"]):
				ctx["word"] = int(ctx["word"]) + 1
			var hadv := font.get_char_size(Rules.code(c), size).x
			var adv: float = gl["adv"]
			var rot := vertical and Rules.vertical_rotate(c)
			var pos: Vector2
			if vertical:
				pos = origin + Vector2(0.0, float(gl["off"]) + adv * 0.5)
				if not rot:
					pos += Rules.vertical_offset(c) * float(size)
			else:
				pos = origin + Vector2(float(gl["off"]) + adv * 0.5, 0.0)
			res["glyphs"].append({
				"index": res["glyphs"].size(), "char": c, "role": role, "page": ctx["page"],
				"line": line_index, "line_in_page": line_index - int(ctx["line_first"]),
				"col": col, "word": ctx["word"], "pos": pos, "box": Vector2(hadv, box_h), "advance": adv,
				"font_size": size, "vertical_rotate": rot, "base_rotation": PI * 0.5 if rot else 0.0,
				"punct": Rules.is_pause_punct(c),
			})
			col += 1
		res["lines"].append({
			"index": line_index, "page": ctx["page"], "role": role, "rect": rect, "center": rect.get_center(),
			"first": first, "count": col,
		})
		area = rect if not have else area.merge(rect)
		have = true
	return area


## 한 역할의 텍스트를 줄 목록으로 나눈다. 줄 = { glyphs: [{c, off, adv, wb}], length }.
static func _break_role(text: String, font: Font, size: int, spacing: float, limit: float, wrap: String, kinsoku: bool, vertical: bool) -> Array:
	var lines: Array = []
	if text == "":
		return lines
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	for para in text.split("\n"):
		var chars := Rules.chars(para)
		var n := chars.size()
		if n == 0:
			lines.append({"glyphs": [], "length": 0.0})
			continue
		var adv := PackedFloat32Array()
		adv.resize(n)
		for i in n:
			adv[i] = _advance(font, chars[i], size, vertical)
		var start := 0
		var first := true
		while start < n:
			if not first:
				while start < n and Rules.is_space(chars[start]):
					start += 1
				if start >= n:
					break
			first = false
			var end_i := n
			var w := 0.0
			var i := start
			while i < n:
				var add := adv[i] + (spacing if i > start else 0.0)
				if limit > 0.0 and i > start and not Rules.is_space(chars[i]) and w + add > limit + 0.01:
					end_i = _find_break(chars, start, i, wrap, kinsoku)
					break
				w += add
				i += 1
			lines.append(_make_line(chars, adv, start, end_i, spacing))
			start = end_i
	return lines


static func _find_break(chars: PackedStringArray, start: int, i: int, wrap: String, kinsoku: bool) -> int:
	for j in range(i, start, -1):
		if _can_break(chars, j, wrap, kinsoku):
			return j
	var b := i
	if kinsoku:
		while b > start + 1 and (Rules.no_start(chars[b]) or Rules.no_end(chars[b - 1])):
			b -= 1
	return b


static func _can_break(chars: PackedStringArray, j: int, wrap: String, kinsoku: bool) -> bool:
	var prev := chars[j - 1]
	var cur := chars[j]
	if Rules.is_space(cur):
		return false
	var ok := false
	match wrap:
		"char":
			ok = true
		"word":
			ok = Rules.is_space(prev)
		_:
			ok = Rules.is_space(prev) or Rules.is_cjk(prev) or Rules.is_cjk(cur)
	if ok and kinsoku and (Rules.no_start(cur) or Rules.no_end(prev)):
		ok = false
	return ok


static func _make_line(chars: PackedStringArray, adv: PackedFloat32Array, s: int, e: int, spacing: float) -> Dictionary:
	var e2 := e
	while e2 > s and Rules.is_space(chars[e2 - 1]):
		e2 -= 1
	var off := 0.0
	var glyphs: Array = []
	for i in range(s, e2):
		if not Rules.is_space(chars[i]):
			glyphs.append({"c": chars[i], "off": off, "adv": adv[i], "wb": i == s or Rules.is_space(chars[i - 1])})
		off += adv[i] + spacing
	var length := maxf(0.0, off - spacing) if e2 > s else 0.0
	return {"glyphs": glyphs, "length": length}


static func _advance(font: Font, c: String, size: int, vertical: bool) -> float:
	var h := font.get_char_size(Rules.code(c), size).x
	if not vertical or c == " " or Rules.vertical_rotate(c):
		return h
	return float(size)


static func _max_len(lines: Array) -> float:
	var m := 0.0
	for l in lines:
		m = maxf(m, float(l["length"]))
	return m


static func _frac(align: String) -> float:
	return {"left": 0.0, "center": 0.5, "right": 1.0}.get(align, 0.5)


static func _vfrac(valign: String) -> float:
	return {"top": 0.0, "center": 0.5, "bottom": 1.0}.get(valign, 0.5)


static func _vec(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return fallback
