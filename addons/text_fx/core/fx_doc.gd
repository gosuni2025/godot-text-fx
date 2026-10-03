class_name TextFxDoc
extends RefCounted
## 문서 포맷(DESIGN §2): 기본값, normalize, validate, 색·경로 도우미.
## normalize(doc)는 새 사본을 돌려주며 멱등이다. 누락 필드는 기본값으로 채우고, 알 수 없는 필드는 보존한다.
## 숫자는 기본값의 타입(int/float)으로 맞추고, 허용되지 않는 enum 값은 기본값으로 교정한다.
## validate(doc)는 원본 문서의 문제를 문자열 목록으로 돌려준다(빈 배열 = 정상).

const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")

const FORMAT := "text_fx"
const FORMAT_VERSION := 2
const DEFAULT_FONT_PATH := "res://assets/fonts/pretendard/Pretendard-Regular.otf"

const MODES: PackedStringArray = ["message", "trailer", "caption"]
const DIRECTIONS: PackedStringArray = ["horizontal", "vertical"]
const ALIGNS: PackedStringArray = ["left", "center", "right"]
const VALIGNS: PackedStringArray = ["top", "center", "bottom"]
const WRAPS: PackedStringArray = ["none", "char", "word", "auto"]
const SUB_POSITIONS: PackedStringArray = ["above", "below"]
const ORDERS: PackedStringArray = ["all", "forward", "reverse", "line", "word", "center_out", "edges_in", "random", "center_index", "edges_index", "sweep"]
const LOOPS: PackedStringArray = ["once", "loop_all", "loop_hold"]
const DECORATION_TYPES: PackedStringArray = ["underline", "overline", "band", "side_lines", "frame", "brackets", "tape", "box", "bar", "lines"]
const DECORATION_ANIMS: PackedStringArray = ["none", "fade", "grow_center", "grow_start", "shape"]
const FILL_TYPES: PackedStringArray = ["solid", "gradient"]
const GRADIENT_SPACES: PackedStringArray = ["block", "glyph", "line"]
const FONT_SOURCES: PackedStringArray = ["bundled", "system", "path"]

## path → 허용 값. normalize가 교정하고 validate가 검사한다.
const ENUMS := {
	"mode": MODES, "layout.direction": DIRECTIONS, "layout.align": ALIGNS, "layout.valign": VALIGNS,
	"layout.wrap": WRAPS, "layout.sub.position": SUB_POSITIONS, "timeline.enter.order": ORDERS,
	"timeline.exit.order": ORDERS, "timeline.loop": LOOPS, "font.source": FONT_SOURCES,
	"style.fill.type": FILL_TYPES, "style.fill.gradient.space": GRADIENT_SPACES,
	"timeline.enter.effect": Enter.IDS, "timeline.exit.effect": Enter.IDS,
	"timeline.hold.scope": ["hold", "visible"],
	"background.type": ["none", "solid", "vignette", "bottom", "top"],
	"timeline.enter.easing": Easing.NAMES, "timeline.exit.easing": Easing.NAMES,
}


static func default_font() -> Dictionary:
	return {"source": "bundled", "family": "Pretendard", "path": DEFAULT_FONT_PATH, "weight": 700, "italic": false}


static func default_style() -> Dictionary:
	return {
		"fill": {
			"type": "solid", "color": "#FFFFFFFF",
			"gradient": {"angle": 90.0, "stops": [[0.0, "#FFFFFFFF"], [1.0, "#9FD8FFFF"]], "space": "block"},
		},
		"outline": {"enabled": true, "size": 6.0, "color": "#101018FF"},
		"outline2": {"enabled": false, "size": 4.0, "color": "#FFFFFFFF"},
		"shadow": {"enabled": true, "offset": [4.0, 6.0], "blur": 4.0, "color": "#00000099"},
		"glow": {"enabled": false, "size": 16.0, "color": "#66CCFFFF", "strength": 1.0},
		"opacity": 1.0,
	}


static func default_decoration(type: String = "underline") -> Dictionary:
	var out := {
		"type": type, "color": "#FFFFFFFF", "thickness": 4.0, "margin": 0.2, "length": 1.1,
		"use_outline": true, "animate": "grow_center", "delay": 0.1, "duration": 0.4,
		"fill_color": "#18243CCC", "fill_opacity": 0.0, "radius": 0.0,
		"softness": 0.0, "end_fade": 0.0, "full_span": false,
		"stripe_width": 24.0, "stripe_speed": 40.0, "blink_period": 0.0, "blink_strength": 1.0, "protect_sub": false, "clamp_canvas": false, "follow_block": false,
		"arm_length": 0.3, "lead_text": false, "exit_delay": 0.0, "exit_duration": 0.0,
	}

	if type in ["tape", "box", "bar", "lines"]:
		out["animate"] = "shape"
	if type in ["tape", "band"]:
		out["full_span"] = true
	if type in ["frame", "underline"]:
		out["protect_sub"] = true
	if type == "frame":
		out["clamp_canvas"] = true
	if type == "box":
		out["fill_opacity"] = 0.75
		out["radius"] = 12.0
	return out


static func default_scroll() -> Dictionary:
	return {"speed": 60.0, "edge_fade": 0.0}


static func default_background() -> Dictionary:
	return {"type": "none", "color": "#101018CC", "opacity": 1.0, "extent": 0.6, "sync_fade": true}


static func default_sub_enter() -> Dictionary:
	return {"effect": "same", "order": "all", "duration": 0.4, "stagger": 0.0,
		"easing": "auto", "params": {}, "delay": 0.0}


static func defaults() -> Dictionary:
	return {
		"format": FORMAT, "format_version": FORMAT_VERSION,
		"name": "",
		"mode": "message",
		"seed": 12345,
		"canvas": {"width": 1280, "height": 720},
		"text": "",
		"sub_text": "",
		"layout": {
			"direction": "horizontal", "align": "center", "valign": "center",
			"anchor": [0.5, 0.5], "offset": [0.0, 0.0],
			"font_size": 96, "letter_spacing": 0.0, "line_height": 1.25,
			"max_width": 0.9, "max_height": 0.8,
			"wrap": "auto", "kinsoku": true,
			"auto_shrink": true, "min_font_size": 24,
			"sub": {"font_size": 40, "position": "below", "gap": 0.35, "letter_spacing": 0.0},
		},
		"font": default_font(),
		"sub_font": null,
		"style": default_style(),
		"sub_style": null,
		"decorations": [],
		"background": default_background(),
		"timeline": {
			"enter": {"effect": "fade", "order": "forward", "duration": 0.45, "stagger": 0.06,
				"easing": "cubic_out", "params": Enter.default_params("fade")},
			"hold": {"duration": 1.6, "effects": [], "scope": "hold"},
			"exit": {"enabled": true, "effect": "fade", "order": "all", "duration": 0.35, "stagger": 0.0,
				"easing": "cubic_in", "params": Enter.default_params("fade")},
			"page_gap": 0.25, "lead_in": 0.0, "lead_out": 0.0,
			"split_pages": true, "exit_between_pages": true, "sub_enter": null,
			"loop": "once",
			"scroll": null,
		},
	}


static func normalize(doc: Variant) -> Dictionary:
	var src: Dictionary = doc if doc is Dictionary else {}
	var out: Dictionary = _merge(defaults(), src)
	# v1 보조 자간은 본문 자간을 공유했다.
	if int(src.get("format_version", 1)) < 2 and get_value(src, "layout.sub.letter_spacing") == null:
		out["layout"]["sub"]["letter_spacing"] = float(get_value(src, "layout.letter_spacing", 0.0))
	out["format"] = FORMAT
	out["format_version"] = FORMAT_VERSION
	for path in ENUMS:
		var allowed: PackedStringArray = ENUMS[path]
		if not allowed.has(str(get_value(out, path, ""))):
			set_value(out, path, get_value(defaults(), path))
	out["font"] = _norm_font(out["font"])
	out["sub_font"] = _norm_font(out["sub_font"]) if out.get("sub_font") is Dictionary else null
	out["style"] = _norm_style(out["style"])
	if out.get("sub_style") is Dictionary:
		out["sub_style"] = _norm_style(_merge(out["style"], out["sub_style"]))
	else:
		out["sub_style"] = null
	var decos: Array = []
	for d in (src.get("decorations", []) if src.get("decorations") is Array else []):
		if d is Dictionary:
			var nd: Dictionary = _merge(default_decoration(), d)
			if int(src.get("format_version", 1)) < 2 and not d.has("protect_sub"):
				nd["protect_sub"] = false
			if not DECORATION_TYPES.has(nd["type"]):
				nd["type"] = "underline"
			if not DECORATION_ANIMS.has(nd["animate"]):
				nd["animate"] = "grow_center"
			nd["color"] = color_to_hex(parse_color(nd["color"]))
			nd["fill_color"] = color_to_hex(parse_color(nd["fill_color"]))
			decos.append(nd)
	out["decorations"] = decos
	var tl: Dictionary = out["timeline"]
	for seg in ["enter", "exit"]:
		var s: Dictionary = tl[seg]
		s["params"] = _merge(Enter.default_params(s["effect"]), s.get("params", {}))
	if tl.get("sub_enter") is Dictionary:
		var sub: Dictionary = _merge(default_sub_enter(), tl["sub_enter"])
		if sub["effect"] != "same" and not Enter.IDS.has(str(sub["effect"])):
			sub["effect"] = "same"
		if not ORDERS.has(str(sub["order"])):
			sub["order"] = "all"
		if not Easing.NAMES.has(str(sub["easing"])):
			sub["easing"] = "auto"
		sub["params"] = _merge(Enter.default_params(str(sub["effect"])), sub["params"])
		tl["sub_enter"] = sub
	else:
		tl["sub_enter"] = null
	out["background"]["color"] = color_to_hex(parse_color(out["background"]["color"]))
	var effects: Array = []
	var src_hold: Variant = get_value(src, "timeline.hold.effects", [])
	for e in (src_hold if src_hold is Array else []):
		if e is Dictionary and Hold.TYPES.has(str(e.get("type", ""))):
			var ne: Dictionary = _merge(Hold.default_params(str(e["type"])), e)
			for ck in ["color_a", "color_b"]:
				if ne.has(ck):
					ne[ck] = color_to_hex(parse_color(ne[ck]))
			effects.append(ne)
	tl["hold"]["effects"] = effects
	tl["scroll"] = _merge(default_scroll(), tl["scroll"]) if tl.get("scroll") is Dictionary else null
	out["canvas"]["width"] = maxi(1, int(out["canvas"]["width"]))
	out["canvas"]["height"] = maxi(1, int(out["canvas"]["height"]))
	return out


static func _norm_font(f: Variant) -> Dictionary:
	var nf: Dictionary = _merge(default_font(), f if f is Dictionary else {})
	if not FONT_SOURCES.has(nf["source"]):
		nf["source"] = "bundled"
	return nf


static func _norm_style(s: Variant) -> Dictionary:
	var ns: Dictionary = _merge(default_style(), s if s is Dictionary else {})
	var fill: Dictionary = ns["fill"]
	if not FILL_TYPES.has(fill["type"]):
		fill["type"] = "solid"
	if not GRADIENT_SPACES.has(fill["gradient"]["space"]):
		fill["gradient"]["space"] = "block"
	fill["color"] = color_to_hex(parse_color(fill["color"]))
	var stops: Array = []
	for st in fill["gradient"]["stops"]:
		if st is Array and st.size() >= 2:
			stops.append([clampf(float(st[0]), 0.0, 1.0), color_to_hex(parse_color(st[1]))])
	if stops.is_empty():
		stops = default_style()["fill"]["gradient"]["stops"]
	fill["gradient"]["stops"] = stops
	for k in ["outline", "outline2", "shadow", "glow"]:
		ns[k]["color"] = color_to_hex(parse_color(ns[k]["color"]))
	return ns


## def 구조를 기준으로 src를 합친다. def에 없는 키는 그대로 보존한다.
static func _merge(def: Variant, src: Variant) -> Variant:
	if def is Dictionary:
		var out: Dictionary = (def as Dictionary).duplicate(true)
		if src is Dictionary:
			for k in src:
				if out.has(k):
					out[k] = _merge(out[k], src[k])
				else:
					out[k] = src[k].duplicate(true) if (src[k] is Dictionary or src[k] is Array) else src[k]
		return out
	if def == null:
		if src is Dictionary or src is Array:
			return src.duplicate(true)
		return src
	if def is Array:
		if not (src is Array):
			return (def as Array).duplicate(true)
		var da: Array = def
		var sa: Array = src
		if da.size() > 0 and sa.size() == da.size() and _all_numbers(da) and _all_numbers(sa):
			var v: Array = []
			for i in sa.size():
				v.append(float(sa[i]))
			return v
		return sa.duplicate(true)
	if def is int:
		return int(src) if (src is int or src is float) else def
	if def is float:
		return float(src) if (src is int or src is float) else def
	if def is bool:
		if src is bool:
			return src
		return bool(src) if (src is int or src is float) else def
	if def is String:
		return str(src) if (src is String or src is StringName) else def
	return src if typeof(src) == typeof(def) else def


static func _all_numbers(a: Array) -> bool:
	for v in a:
		if not (v is int or v is float):
			return false
	return true


static func validate(doc: Variant) -> PackedStringArray:
	var errs := PackedStringArray()
	if not (doc is Dictionary):
		errs.append("문서가 객체가 아님")
		return errs
	var d: Dictionary = doc
	if d.has("format") and d["format"] != FORMAT:
		errs.append("format이 text_fx가 아님: %s" % str(d["format"]))
	if d.has("format_version") and int(d["format_version"]) > FORMAT_VERSION:
		errs.append("지원하지 않는 format_version: %s" % str(d["format_version"]))
	for path in ENUMS:
		var v: Variant = get_value(d, path, null)
		if v != null and not (ENUMS[path] as PackedStringArray).has(str(v)):
			errs.append("%s 값이 허용되지 않음: %s" % [path, str(v)])
	for path in ["canvas.width", "canvas.height", "layout.font_size", "layout.min_font_size", "layout.sub.font_size"]:
		var v: Variant = get_value(d, path, null)
		if v != null and (not (v is int or v is float) or float(v) <= 0.0):
			errs.append("%s는 양수여야 함" % path)
	for path in ["timeline.enter.duration", "timeline.enter.stagger", "timeline.exit.duration", "timeline.exit.stagger",
			"timeline.hold.duration", "timeline.page_gap", "timeline.lead_in", "timeline.lead_out",
			"timeline.sub_enter.duration", "timeline.sub_enter.stagger", "layout.line_height", "layout.max_width", "layout.max_height"]:
		var v: Variant = get_value(d, path, null)
		if v != null and (not (v is int or v is float) or float(v) < 0.0):
			errs.append("%s는 0 이상이어야 함" % path)
	for path in ["text", "sub_text", "name"]:
		var v: Variant = d.get(path)
		if v != null and not (v is String):
			errs.append("%s는 문자열이어야 함" % path)
	for sp in ["style", "sub_style"]:
		if d.get(sp) is Dictionary:
			for cp in ["fill.color", "outline.color", "outline2.color", "shadow.color", "glow.color"]:
				var c: Variant = get_value(d[sp], cp, null)
				if c != null and not is_color(c):
					errs.append("%s.%s 색 형식 오류: %s" % [sp, cp, str(c)])
	var decos: Variant = d.get("decorations", [])
	if decos is Array:
		for i in (decos as Array).size():
			var de: Variant = decos[i]
			if not (de is Dictionary):
				errs.append("decorations[%d]가 객체가 아님" % i)
				continue
			if de.has("type") and not DECORATION_TYPES.has(str(de["type"])):
				errs.append("decorations[%d].type 허용되지 않음: %s" % [i, str(de["type"])])
			if de.has("animate") and not DECORATION_ANIMS.has(str(de["animate"])):
				errs.append("decorations[%d].animate 허용되지 않음: %s" % [i, str(de["animate"])])
			if de.has("color") and not is_color(de["color"]):
				errs.append("decorations[%d].color 색 형식 오류" % i)
	elif decos != null:
		errs.append("decorations는 배열이어야 함")
	var effects: Variant = get_value(d, "timeline.hold.effects", [])
	if effects is Array:
		for i in (effects as Array).size():
			var e: Variant = effects[i]
			if not (e is Dictionary) or not Hold.TYPES.has(str(e.get("type", ""))):
				errs.append("timeline.hold.effects[%d].type 허용되지 않음" % i)
	var scroll: Variant = get_value(d, "timeline.scroll", null)
	if scroll != null and (not (scroll is Dictionary) or float(scroll.get("speed", 1.0)) <= 0.0):
		errs.append("timeline.scroll은 null 또는 speed > 0 객체여야 함")
	var sub_enter: Variant = get_value(d, "timeline.sub_enter")
	if sub_enter != null:
		if not sub_enter is Dictionary:
			errs.append("timeline.sub_enter는 null 또는 객체여야 함")
		else:
			var sub_effect := str(sub_enter.get("effect", "same"))
			if sub_effect != "same" and not Enter.IDS.has(sub_effect):
				errs.append("timeline.sub_enter.effect 허용되지 않음")
			if not ORDERS.has(str(sub_enter.get("order", "all"))) or not Easing.NAMES.has(str(sub_enter.get("easing", "auto"))):
				errs.append("timeline.sub_enter order/easing 허용되지 않음")
	for path in ["background.color", "timeline.enter.params.color_a", "timeline.enter.params.color_b",
			"timeline.exit.params.color_a", "timeline.exit.params.color_b", "timeline.enter.params.cursor_color",
			"timeline.sub_enter.params.cursor_color"]:
		var color: Variant = get_value(d, path)
		if color != null and not is_color(color):
			errs.append(path + " 색 형식 오류")
	for path in ["background.opacity", "background.extent", "timeline.scroll.edge_fade"]:
		var number: Variant = get_value(d, path)
		if number != null and (not (number is int or number is float) or float(number) < 0.0 or float(number) > 1.0):
			errs.append(path + "는 0~1 숫자여야 함")
	return errs


static func is_color(v: Variant) -> bool:
	if not (v is String):
		return false
	var s: String = v
	if not s.begins_with("#") or not (s.length() == 7 or s.length() == 9):
		return false
	return s.substr(1).is_valid_hex_number(false)


static func parse_color(v: Variant, fallback: Color = Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is String and is_color(v):
		return Color.from_string(v, fallback)
	return fallback


static func color_to_hex(c: Color) -> String:
	return "#" + c.to_html(true).to_upper()


static func parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data


static func to_json(doc: Dictionary, indent: String = "\t") -> String:
	return JSON.stringify(doc, indent, false)


## "a.b.c" 경로 읽기. 배열은 숫자 키("decorations.0.color").
static func get_value(doc: Variant, path: String, default: Variant = null) -> Variant:
	var cur: Variant = doc
	for key in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(key):
			cur = cur[key]
		elif cur is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (cur as Array).size():
			cur = cur[int(key)]
		else:
			return default
	return cur


## "a.b.c" 경로 쓰기. 중간 Dictionary가 없으면 만든다. 성공 여부를 돌려준다.
static func set_value(doc: Dictionary, path: String, value: Variant) -> bool:
	var keys := path.split(".")
	var cur: Variant = doc
	for i in keys.size() - 1:
		var key := keys[i]
		if cur is Dictionary:
			if not (cur as Dictionary).has(key) or not (cur[key] is Dictionary or cur[key] is Array):
				cur[key] = {}
			cur = cur[key]
		elif cur is Array and key.is_valid_int() and int(key) < (cur as Array).size():
			cur = cur[int(key)]
		else:
			return false
	var last := keys[keys.size() - 1]
	if cur is Dictionary:
		cur[last] = value
		return true
	if cur is Array and last.is_valid_int() and int(last) < (cur as Array).size():
		cur[int(last)] = value
		return true
	return false


## 역할별 스타일·글꼴(정규화된 문서 기준).
static func style_for(doc: Dictionary, role: String) -> Dictionary:
	if role == "sub" and doc.get("sub_style") is Dictionary:
		return doc["sub_style"]
	return doc.get("style", default_style())


static func font_for(doc: Dictionary, role: String) -> Dictionary:
	if role == "sub" and doc.get("sub_font") is Dictionary:
		return doc["sub_font"]
	return doc.get("font", default_font())
