extends RefCounted
## 문서 필드 규칙(형식·범위·선택지)과 경로 도우미. 명령 검증·봇 값 선택·UI 필드 생성에 쓴다.
## 경로는 "."으로 나눈 키, 배열 원소는 숫자 번호. 패턴은 숫자 번호를 "*"로 바꾼 것.

const JsonUtil := preload("res://app/logic/json_util.gd")
const TextFxDoc := preload("res://addons/text_fx/core/fx_doc.gd")

const MODES: PackedStringArray = TextFxDoc.MODES
const LOCALES := ["ko", "ja", "en"]
const ENTER_EFFECTS: PackedStringArray = TextFxDoc.Enter.IDS
const ORDERS: PackedStringArray = TextFxDoc.ORDERS
const HOLD_EFFECTS: PackedStringArray = TextFxDoc.Hold.TYPES
const DECORATIONS: PackedStringArray = TextFxDoc.DECORATION_TYPES
const DECO_ANIMATE: PackedStringArray = TextFxDoc.DECORATION_ANIMS
const EASINGS: PackedStringArray = TextFxDoc.Easing.NAMES
const LOOPS: PackedStringArray = TextFxDoc.LOOPS

## 목록 명령(list_add/list_remove/list_move)을 허용하는 배열 경로와 최대 길이.
const LISTS := {"decorations": 12, "timeline.hold.effects": 8,
	"style.fill.gradient.stops": 8, "sub_style.fill.gradient.stops": 8}

## 새 키를 set으로 추가할 수 있는 열린 사전(효과 params, 유지 효과, 장식).
const OPEN_DICTS := ["timeline.enter.params", "timeline.exit.params", "timeline.sub_enter.params", "timeline.hold.effects.*", "decorations.*"]

const MAX_TEXT := 4000

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = _build_rules()
	return _rules


static func _n(lo: float, hi: float) -> Dictionary:
	return {"t": "num", "min": lo, "max": hi}


static func _i(lo: int, hi: int) -> Dictionary:
	return {"t": "int", "min": lo, "max": hi}


static func _e(values) -> Dictionary:
	return {"t": "enum", "v": Array(values)}


static func _build_rules() -> Dictionary:
	var B := {"t": "bool"}
	var C := {"t": "color"}
	var D := {"t": "dict"}
	var r := {
		"format": _e(["text_fx"]), "format_version": _i(1, TextFxDoc.FORMAT_VERSION), "name": {"t": "str", "max": 200},
		"mode": _e(MODES), "seed": _i(0, 2147483647),
		"canvas": D, "canvas.width": _i(64, 4096), "canvas.height": _i(64, 4096),
		"text": {"t": "str", "max": MAX_TEXT}, "sub_text": {"t": "str", "max": MAX_TEXT},
		"layout": D, "layout.direction": _e(["horizontal", "vertical"]),
		"layout.align": _e(["left", "center", "right"]), "layout.valign": _e(["top", "center", "bottom"]),
		"layout.anchor": {"t": "vec2", "min": 0.0, "max": 1.0},
		"layout.offset": {"t": "vec2", "min": -4096.0, "max": 4096.0},
		"layout.font_size": _i(4, 400), "layout.letter_spacing": _n(-0.5, 2.0),
		"layout.line_height": _n(0.5, 3.0), "layout.max_width": _n(0.05, 1.0), "layout.max_height": _n(0.05, 1.0),
		"layout.wrap": _e(["none", "char", "word", "auto"]), "layout.kinsoku": B,
		"layout.auto_shrink": B, "layout.min_font_size": _i(4, 400),
		"layout.sub": D, "layout.sub.font_size": _i(4, 400), "layout.sub.position": _e(["above", "below"]),
		"layout.sub.gap": _n(0.0, 4.0),
		"font": D, "sub_font": {"t": "null_or_dict"},
		"style": D, "sub_style": {"t": "null_or_dict"},
		"decorations": {"t": "list", "max": LISTS["decorations"]},
		"decorations.*": D, "decorations.*.type": _e(DECORATIONS), "decorations.*.color": C,
		"decorations.*.thickness": _n(0, 128), "decorations.*.margin": _n(-2.0, 4.0),
		"decorations.*.length": _n(0.0, 4.0), "decorations.*.use_outline": B,
		"decorations.*.animate": _e(DECO_ANIMATE), "decorations.*.delay": _n(0, 10), "decorations.*.duration": _n(0, 10),
		"timeline": D, "timeline.hold": D, "timeline.hold.duration": _n(0, 60),
		"timeline.hold.effects": {"t": "list", "max": LISTS["timeline.hold.effects"]},
		"timeline.page_gap": _n(0, 10), "timeline.loop": _e(LOOPS),
		"timeline.scroll": {"t": "null_or_dict"}, "timeline.scroll.speed": _n(1, 2000),
	}
	for pre in ["font", "sub_font"]:
		r[pre + ".source"] = _e(["bundled", "system", "path"])
		r[pre + ".family"] = {"t": "str", "max": 200}
		r[pre + ".path"] = {"t": "str", "max": 1000}
		r[pre + ".weight"] = _n(100, 900)
		r[pre + ".italic"] = B
	for pre in ["style", "sub_style"]:
		r[pre + ".fill"] = D
		r[pre + ".fill.type"] = _e(["solid", "gradient"])
		r[pre + ".fill.color"] = C
		r[pre + ".fill.gradient"] = D
		r[pre + ".fill.gradient.angle"] = _n(-360, 360)
		r[pre + ".fill.gradient.stops"] = {"t": "stops", "max": 8}
		r[pre + ".fill.gradient.space"] = _e(TextFxDoc.GRADIENT_SPACES)
		for o in ["outline", "outline2"]:
			r[pre + "." + o] = D
			r[pre + "." + o + ".enabled"] = B
			r[pre + "." + o + ".size"] = _n(0, 64)
			r[pre + "." + o + ".color"] = C
		r[pre + ".shadow"] = D
		r[pre + ".shadow.enabled"] = B
		r[pre + ".shadow.offset"] = {"t": "vec2", "min": -128.0, "max": 128.0}
		r[pre + ".shadow.blur"] = _n(0, 64)
		r[pre + ".shadow.color"] = C
		r[pre + ".glow"] = D
		r[pre + ".glow.enabled"] = B
		r[pre + ".glow.size"] = _n(0, 128)
		r[pre + ".glow.color"] = C
		r[pre + ".glow.strength"] = _n(0, 4)
		r[pre + ".opacity"] = _n(0, 1)
	for seg in ["enter", "exit", "sub_enter"]:
		var p: String = "timeline." + seg
		r[p] = D
		r[p + ".effect"] = _e(ENTER_EFFECTS)
		r[p + ".order"] = _e(ORDERS)
		r[p + ".duration"] = _n(0, 10)
		r[p + ".stagger"] = _n(0, 3)
		r[p + ".easing"] = _e(EASINGS)
		r[p + ".params"] = D
		var q: String = p + ".params."
		r[q + "dir"] = _e(["up", "down", "left", "right", "center"])
		r[q + "mode"] = _e(["alternate", "role"])
		r[q + "distance"] = _n(0, 20)
		r[q + "from_scale"] = _n(0, 10)
		r[q + "blur"] = _n(0, 2)  # em
		r[q + "radius"] = _n(0, 2)  # em
		r[q + "angle"] = _n(-1080, 1080)
		r[q + "spread"] = _n(0, 10)
		r[q + "jitter"] = _n(0, 4)
		r[q + "pop"] = _n(0, 2)
		r[q + "intensity"] = _n(0, 5)
		r[q + "big_scale"] = _n(0.5, 12)
		r[q + "hold_each"] = _n(0, 3)
		r[q + "pause"] = _n(0, 5)
		r[q + "slam_scale"] = _n(0.5, 12)
		r[q + "punct_pause"] = _n(0, 3)
	r["timeline.exit.enabled"] = B
	var h := "timeline.hold.effects.*."
	r["timeline.hold.effects.*"] = D
	r[h + "type"] = _e(HOLD_EFFECTS)
	r[h + "period"] = _n(0.05, 30)
	r[h + "min_alpha"] = _n(0, 1)
	r[h + "hard"] = B
	r[h + "rate"] = _n(0.1, 60)
	r[h + "amplitude"] = _n(0, 64)
	r[h + "frequency"] = _n(0, 60)
	r[h + "wavelength"] = _n(1, 64)
	r[h + "speed"] = _n(-10, 10)
	r[h + "scale"] = _n(0.5, 2)
	r[h + "interval"] = _n(0.1, 30)
	r[h + "duration"] = _n(0.01, 5)
	r[h + "intensity"] = _n(0, 5)
	r[h + "slices"] = _i(1, 16)
	r[h + "color_a"] = C
	r[h + "color_b"] = C
	r[h + "saturation"] = _n(0, 1)
	r[h + "spread"] = _n(0, 1)
	preload("res://app/logic/doc_schema_fx.gd").extend_rules(r)
	return r


# --- 경로 ---------------------------------------------------------------

static func split_path(path: String) -> PackedStringArray:
	if path.is_empty():
		return PackedStringArray()
	return path.split(".", true)


static func pattern_of(path: String) -> String:
	var segs := split_path(path)
	for i in segs.size():
		if segs[i].is_valid_int():
			segs[i] = "*"
	return ".".join(segs)


static func rule_for(path: String):
	return rules().get(pattern_of(path))


## 경로의 값을 찾는다. {ok, value}
static func get_at(root, path: String) -> Dictionary:
	var cur = root
	for seg in split_path(path):
		if cur is Dictionary:
			if not cur.has(seg):
				return {"ok": false}
			cur = cur[seg]
		elif cur is Array:
			if not seg.is_valid_int():
				return {"ok": false}
			var i := seg.to_int()
			if i < 0 or i >= cur.size():
				return {"ok": false}
			cur = cur[i]
		else:
			return {"ok": false}
	return {"ok": true, "value": cur}


## root(제자리)에 값을 쓴다. 부모가 있어야 하며, 새 키는 열린 사전에서 규칙이 있을 때만 허용.
static func set_at(root: Dictionary, path: String, value) -> bool:
	var segs := split_path(path)
	if segs.is_empty():
		return false
	var parent_path := ".".join(segs.slice(0, segs.size() - 1))
	var key := segs[segs.size() - 1]
	var pr := get_at(root, parent_path)
	if not pr.ok:
		return false
	var parent = pr.value
	if parent is Dictionary:
		if not parent.has(key):
			if not (pattern_of(parent_path) in OPEN_DICTS and rule_for(path) != null):
				return false
		parent[key] = value
		return true
	if parent is Array and key.is_valid_int():
		var i := key.to_int()
		if i < 0 or i >= parent.size():
			return false
		parent[i] = value
		return true
	return false


# --- 검증 ---------------------------------------------------------------

static func check_value(rule: Dictionary, v) -> bool:
	match rule.t:
		"num":
			return JsonUtil.is_number(v) and v >= rule.min and v <= rule.max
		"int":
			return JsonUtil.is_number(v) and float(v) == floorf(v) and v >= rule.min and v <= rule.max
		"bool":
			return typeof(v) == TYPE_BOOL
		"str":
			return typeof(v) == TYPE_STRING and v.length() <= rule.max
		"enum":
			return typeof(v) == TYPE_STRING and v in rule.v
		"color":
			return is_color(v)
		"null_or_color":
			return v == null or is_color(v)
		"vec2":
			return v is Array and v.size() == 2 and JsonUtil.is_number(v[0]) and JsonUtil.is_number(v[1]) \
				and v[0] >= rule.min and v[0] <= rule.max and v[1] >= rule.min and v[1] <= rule.max
		"stops":
			if not (v is Array) or v.size() < 1 or v.size() > rule.max:
				return false
			for s in v:
				if not is_stop(s):
					return false
			return true
		"dict":
			return v is Dictionary
		"null_or_dict":
			return v == null or v is Dictionary
		"list":
			return v is Array and v.size() <= rule.max
	return false


static func is_stop(s) -> bool:
	return s is Array and s.size() == 2 and JsonUtil.is_number(s[0]) and s[0] >= 0.0 and s[0] <= 1.0 \
		and is_color(s[1])


static func is_color(v) -> bool:
	if typeof(v) != TYPE_STRING or not v.begins_with("#"):
		return false
	var hex: String = v.substr(1)
	return (hex.length() == 6 or hex.length() == 8) and hex.is_valid_hex_number(false)


## 정규화된 문서 전체를 검사한다. 오류 문자열 배열(비면 통과).
static func validate_doc(doc: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (doc.get("format", "text_fx") == "text_fx"):
		errors.append("format")
	_walk(doc, "", errors)
	return errors


static func _walk(v, path: String, errors: PackedStringArray) -> void:
	if errors.size() > 20:
		return
	if path != "":
		var rule = rule_for(path)
		if rule != null:
			if not check_value(rule, v):
				errors.append(path)
				return
			if rule.t in ["vec2", "stops"]:
				return
	if v is Dictionary:
		for k in v:
			_walk(v[k], str(k) if path == "" else path + "." + str(k), errors)
	elif v is Array:
		for i in v.size():
			_walk(v[i], path + "." + str(i), errors)
	# 규칙 없는 값(알 수 없는 필드)은 보존·무시한다.


## 봇이 값을 바꿀 수 있는 필드 패턴. 규칙은 rules()에서 찾는다.
const TWEAKABLE := [
	"layout.font_size", "layout.letter_spacing", "layout.line_height", "layout.align", "layout.valign",
	"layout.anchor", "layout.offset", "layout.direction", "layout.wrap", "layout.sub.font_size",
	"layout.sub.position", "font.weight", "font.italic",
	"style.fill.type", "style.fill.color", "style.fill.gradient.angle", "style.fill.gradient.space",
	"style.outline.enabled", "style.outline.size", "style.outline.color",
	"style.outline2.enabled", "style.outline2.size", "style.outline2.color",
	"style.shadow.enabled", "style.shadow.offset", "style.shadow.blur", "style.shadow.color",
	"style.glow.enabled", "style.glow.size", "style.glow.color", "style.glow.strength", "style.opacity",
	"decorations.*.color", "decorations.*.thickness", "decorations.*.margin", "decorations.*.length",
	"decorations.*.animate", "decorations.*.use_outline", "decorations.*.delay",
	"timeline.enter.effect", "timeline.enter.order", "timeline.enter.duration", "timeline.enter.stagger",
	"timeline.enter.easing", "timeline.hold.duration", "timeline.exit.enabled", "timeline.exit.effect",
	"timeline.exit.order", "timeline.exit.duration", "timeline.exit.easing", "timeline.page_gap", "timeline.loop",
	"timeline.hold.effects.*.amplitude", "timeline.hold.effects.*.period", "timeline.hold.effects.*.min_alpha",
	"seed",
]
