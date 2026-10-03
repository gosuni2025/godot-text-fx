extends RefCounted
## 문서를 바꾸는 명령의 순수 계산. 입력 문서는 바꾸지 않고 새 문서를 돌려준다.
## 결과: { ok, doc, paths: PackedStringArray, key: 합치기 키(""이면 합치지 않음), error, template_id }

const DocApi := preload("res://app/logic/doc_api.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const Templates := preload("res://app/logic/templates.gd")
const Serialization := preload("res://app/logic/serialization.gd")

const OPS := ["set", "unset", "set_text", "set_mode", "list_add", "list_remove", "list_move",
	"apply_template", "load_doc", "select_effect"]


static func is_doc_op(op: String) -> bool:
	return op in OPS


static func run(doc: Dictionary, cmd: Dictionary, locale: String) -> Dictionary:
	var op := str(cmd.get("op", ""))
	match op:
		"select_effect": return _select_effect(doc, cmd)
		"set": return _cmd_set(doc, cmd)
		"unset": return _unset(doc, cmd)
		"set_text": return _set_text(doc, cmd)
		"set_mode": return _set_mode(doc, cmd)
		"list_add": return _list_add(doc, cmd)
		"list_remove": return _list_remove(doc, cmd)
		"list_move": return _list_move(doc, cmd)
		"apply_template": return _apply_template(doc, cmd, locale)
		"load_doc": return _load_doc(cmd)
	return fail("unknown op '%s'" % op)


static func fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}


## 정규화·검증을 거친 성공 결과.
static func finish(candidate: Dictionary, paths: Array, key: String = "", template_id = null) -> Dictionary:
	var out := DocApi.normalize(candidate)
	var errors := DocApi.validate(out)
	if not errors.is_empty():
		return fail("invalid: " + ", ".join(errors))
	var r := {"ok": true, "doc": out, "paths": PackedStringArray(paths), "key": key, "error": ""}
	if template_id != null:
		r["template_id"] = template_id
	return r


static func _path_arg(cmd: Dictionary) -> String:
	var p = cmd.get("path")
	return p if typeof(p) == TYPE_STRING else ""


static func _cmd_set(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var path := _path_arg(cmd)
	if path == "" or not cmd.has("value"):
		return fail("set needs path and value")
	if path in ["format", "format_version"]:
		return fail("read-only path")
	var value = JsonUtil.canon(cmd.value)
	var rule = DocSchema.rule_for(path)
	if rule != null and not DocSchema.check_value(rule, value):
		return fail("bad value for %s" % path)
	var next: Dictionary = doc.duplicate(true)
	if not DocSchema.set_at(next, path, value):
		return fail("no such path %s" % path)
	var key := "" if cmd.get("merge", true) == false else "set:" + path
	return finish(next, [path], key)


static func _unset(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var path := _path_arg(cmd)
	var segs := DocSchema.split_path(path)
	if segs.size() < 2:
		return fail("unset needs a nested path")
	var parent_path := ".".join(segs.slice(0, segs.size() - 1))
	if not (DocSchema.pattern_of(parent_path) in DocSchema.OPEN_DICTS):
		return fail("unset only in open dicts")
	var next: Dictionary = doc.duplicate(true)
	var pr := DocSchema.get_at(next, parent_path)
	var key := segs[segs.size() - 1]
	if not pr.ok or not (pr.value is Dictionary) or not pr.value.has(key) or key == "type":
		return fail("no such key %s" % path)
	pr.value.erase(key)
	return finish(next, [path])


static func _set_text(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	if not (cmd.has("text") or cmd.has("sub_text")):
		return fail("set_text needs text or sub_text")
	var next: Dictionary = doc.duplicate(true)
	var paths: Array = []
	for k in ["text", "sub_text"]:
		if cmd.has(k):
			if typeof(cmd[k]) != TYPE_STRING or cmd[k].length() > DocSchema.MAX_TEXT:
				return fail("bad %s" % k)
			next[k] = cmd[k]
			paths.append(k)
	var key := "" if cmd.get("merge", true) == false else "set_text"
	return finish(next, paths, key)


static func _set_mode(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var mode = cmd.get("mode")
	if not (mode is String and mode in DocSchema.MODES):
		return fail("bad mode")
	var next: Dictionary = doc.duplicate(true)
	next["mode"] = mode
	return finish(next, ["mode"])


static func _list_ref(next: Dictionary, path: String) -> Dictionary:
	if not DocSchema.LISTS.has(path):
		return fail("not a list path: %s" % path)
	var r := DocSchema.get_at(next, path)
	if not r.ok or not (r.value is Array):
		return fail("list not present: %s" % path)
	return {"ok": true, "list": r.value, "max": DocSchema.LISTS[path]}


static func _make_item(path: String, value):
	if path == "decorations":
		var t = value.get("type") if value is Dictionary else value
		if not (t is String and t in DocSchema.DECORATIONS):
			return null
		return DocApi.merge(DocApi.decoration_defaults(t), value) if value is Dictionary else DocApi.decoration_defaults(t)
	if path == "timeline.hold.effects":
		var t = value.get("type") if value is Dictionary else value
		if not (t is String and t in DocSchema.HOLD_EFFECTS):
			return null
		return DocApi.merge(DocApi.hold_effect_defaults(t), value) if value is Dictionary else DocApi.hold_effect_defaults(t)
	if path.ends_with("gradient.stops"):
		var v = JsonUtil.canon(value)
		return v if DocSchema.is_stop(v) else null
	return null


static func _int_arg(cmd: Dictionary, name: String, lo: int, hi: int):
	var v = cmd.get(name)
	if not JsonUtil.is_number(v) or float(v) != floorf(v):
		return null
	var i := int(v)
	return i if i >= lo and i <= hi else null


static func _list_add(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var path := _path_arg(cmd)
	var next: Dictionary = doc.duplicate(true)
	var ref := _list_ref(next, path)
	if not ref.ok:
		return ref
	var list: Array = ref.list
	if list.size() >= ref.max:
		return fail("list full")
	var item = _make_item(path, cmd.get("value"))
	if item == null:
		return fail("bad item for %s" % path)
	var index = list.size()
	if cmd.has("index"):
		index = _int_arg(cmd, "index", 0, list.size())
		if index == null:
			return fail("bad index")
	list.insert(index, JsonUtil.canon(item))
	return finish(next, [path])


static func _list_remove(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var path := _path_arg(cmd)
	var next: Dictionary = doc.duplicate(true)
	var ref := _list_ref(next, path)
	if not ref.ok:
		return ref
	var list: Array = ref.list
	var index = _int_arg(cmd, "index", 0, list.size() - 1)
	if index == null:
		return fail("bad index")
	if path.ends_with("gradient.stops") and list.size() <= 2:
		return fail("gradient needs 2 stops")
	list.remove_at(index)
	return finish(next, [path])


static func _list_move(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var path := _path_arg(cmd)
	var next: Dictionary = doc.duplicate(true)
	var ref := _list_ref(next, path)
	if not ref.ok:
		return ref
	var list: Array = ref.list
	var from = _int_arg(cmd, "from", 0, list.size() - 1)
	var to = _int_arg(cmd, "to", 0, list.size() - 1)
	if from == null or to == null:
		return fail("bad from/to")
	var item = list[from]
	list.remove_at(from)
	list.insert(to, item)
	return finish(next, [path])


static func _apply_template(doc: Dictionary, cmd: Dictionary, locale: String) -> Dictionary:
	var id = cmd.get("id")
	if not (id is String and Templates.has(id)):
		return fail("unknown template")
	var keep := {"canvas": doc.get("canvas"), "seed": doc.get("seed")}
	if cmd.get("keep_text", false) == true:
		keep["text"] = doc.get("text", "")
		keep["sub_text"] = doc.get("sub_text", "")
	return finish(Templates.build_doc(id, locale, keep), ["*"], "", id)


static func _load_doc(cmd: Dictionary) -> Dictionary:
	var src = cmd.get("doc")
	if src == null and cmd.get("string") is String:
		var dec := Serialization.decode(cmd["string"])
		if not dec.ok:
			return fail("decode: " + dec.error)
		src = dec.data
	if not (src is Dictionary):
		return fail("load_doc needs doc (dict) or string")
	if src.get("format", "text_fx") != "text_fx":
		return fail("not a text_fx document")
	var ver = src.get("format_version", 1)
	if not JsonUtil.is_number(ver) or ver > DocApi.FORMAT_VERSION or ver < 1:
		return fail("unsupported format_version")
	var src_errors := DocApi.validate_source(src)
	if not src_errors.is_empty():
		return fail("invalid: " + ", ".join(src_errors))
	return finish(src, ["*"], "", "")


## 효과 선택은 params와 권장 이징을 한 번에 바꾼다. 명령 기록·undo도 한 단계다.
static func _select_effect(doc: Dictionary, cmd: Dictionary) -> Dictionary:
	var segment := str(cmd.get("segment", "enter"))
	var effect := str(cmd.get("effect", ""))
	if segment not in ["enter", "exit", "sub_enter"] or (not effect in DocSchema.ENTER_EFFECTS and not (segment == "sub_enter" and effect == "same")):
		return fail("bad effect selection")
	var next := doc.duplicate(true)
	if not next["timeline"].get(segment) is Dictionary:
		next["timeline"][segment] = DocSchema.TextFxDoc.default_sub_enter()
	var seg: Dictionary = next["timeline"][segment]
	seg["effect"] = effect
	seg["params"] = DocSchema.TextFxDoc.Enter.default_params(effect)
	seg["easing"] = "auto"
	if effect in DocSchema.TextFxDoc.Enter.BLOCK_EFFECTS:
		seg["order"] = "all"
	if effect in ["typewriter", "erase"]:
		seg["duration"] = 0.0
		seg["params"]["pop"] = 0.0
		seg["order"] = "reverse" if segment == "exit" else "forward"
		seg["stagger"] = maxf(0.06, float(seg["stagger"]))
	elif float(seg["duration"]) <= 0.0:
		seg["duration"] = 0.45
	return finish(next, ["timeline." + segment])
