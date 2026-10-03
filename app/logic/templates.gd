extends RefCounted
## 템플릿 등록부. app/logic/templates/*.json 을 읽는다(한 모드를 여러 파일로 나눌 수 있음, 각 파일 20KB 미만).
## 파일 형식: { mode, groups[], locale_patch{loc: patch}, templates[] }
## 템플릿: { id, group, icon, loop, name{ko,ja,en}, text{..}, sub_text{..}?, patch{}, locale_patch{loc: patch}? }
## 문서 = normalize(defaults ⊕ 파일 locale_patch[loc] ⊕ patch ⊕ 템플릿 locale_patch[loc] ⊕ {mode,name,text,sub_text,loop})

const DocApi := preload("res://app/logic/doc_api.gd")

const FILES := [
	"res://app/logic/templates/message_action.json",
	"res://app/logic/templates/message_story.json",
	"res://app/logic/templates/message_cinematic.json",
	"res://app/logic/templates/trailer.json",
	"res://app/logic/templates/caption.json",
]
const FALLBACK_LOCALES := ["en", "ko", "ja"]

static var _list: Array = []
static var _by_id: Dictionary = {}
static var _groups: Dictionary = {}       # mode -> PackedStringArray
static var _file_patch: Dictionary = {}   # template id -> 파일의 {loc: patch}
static var _errors: PackedStringArray = PackedStringArray()


static func _ensure() -> void:
	if not _list.is_empty() or not _errors.is_empty():
		return
	for path in FILES:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_errors.append("missing %s" % path)
			continue
		var j := JSON.new()
		if j.parse(f.get_as_text()) != OK or not (j.data is Dictionary):
			_errors.append("bad json %s: %s" % [path, j.get_error_message()])
			continue
		var data: Dictionary = j.data
		var mode := str(data.get("mode", ""))
		var groups: PackedStringArray = _groups.get(mode, PackedStringArray())
		for g in data.get("groups", []):
			if not g in groups:
				groups.append(g)
		_groups[mode] = groups
		var file_patch = data.get("locale_patch", {})
		for t in data.get("templates", []):
			if not (t is Dictionary) or not t.has("id"):
				_errors.append("bad template in %s" % path)
				continue
			var tpl: Dictionary = t.duplicate(true)
			tpl["mode"] = mode
			if _by_id.has(tpl.id):
				_errors.append("duplicate id %s" % tpl.id)
				continue
			_by_id[tpl.id] = tpl
			_file_patch[tpl.id] = file_patch if file_patch is Dictionary else {}
			_list.append(tpl)


static func load_errors() -> PackedStringArray:
	_ensure()
	return _errors


static func all() -> Array:
	_ensure()
	return _list


static func ids() -> PackedStringArray:
	_ensure()
	var out := PackedStringArray()
	for t in _list:
		out.append(t.id)
	return out


static func has(id: String) -> bool:
	_ensure()
	return _by_id.has(id)


static func get_template(id: String) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func modes() -> PackedStringArray:
	_ensure()
	return PackedStringArray(_groups.keys())


static func groups(mode: String) -> PackedStringArray:
	_ensure()
	return _groups.get(mode, PackedStringArray())


static func by_mode(mode: String, group: String = "") -> Array:
	_ensure()
	var out: Array = []
	for t in _list:
		if t.mode == mode and (group == "" or t.group == group):
			out.append(t)
	return out


## 다국어 필드({ko,ja,en})에서 locale 값을 고른다. 없으면 en → ko → ja 순.
static func localized(tpl: Dictionary, field: String, locale: String) -> String:
	var m = tpl.get(field)
	if m is String:
		return m
	if not (m is Dictionary):
		return ""
	if m.has(locale):
		return str(m[locale])
	for loc in FALLBACK_LOCALES:
		if m.has(loc):
			return str(m[loc])
	return ""


## 템플릿을 적용한 정규화 문서. keep은 유지할 기존 문서 필드(canvas, seed 등)를 담은 사전.
static func build_doc(id: String, locale: String, keep: Dictionary = {}) -> Dictionary:
	var tpl := get_template(id)
	if tpl.is_empty():
		return {}
	var doc: Dictionary = DocApi.defaults()
	var fp: Dictionary = _file_patch.get(id, {})
	if fp.get(locale) is Dictionary:
		doc = DocApi.merge(doc, fp[locale])
	doc = DocApi.merge(doc, tpl.get("patch", {}))
	var lp = tpl.get("locale_patch", {})
	if lp is Dictionary and lp.get(locale) is Dictionary:
		doc = DocApi.merge(doc, lp[locale])
	doc["mode"] = tpl.mode
	doc["name"] = localized(tpl, "name", locale)
	doc["text"] = localized(tpl, "text", locale)
	doc["sub_text"] = localized(tpl, "sub_text", locale)
	doc["timeline"]["loop"] = str(tpl.get("loop", "once"))
	for k in keep:
		doc[k] = keep[k]
	return DocApi.normalize(doc)
