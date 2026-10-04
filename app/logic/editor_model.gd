extends RefCounted
## 에디터 상태 모델. 문서·재생 상태·언어·선택은 apply(command)로만 바뀐다.
## changed(paths): 문서 경로("style.outline.size"), 문서 전체 "*", 모델 상태 "$time" "$playing"
## "$locale" "$selection" "$export" "$history".

signal changed(paths: PackedStringArray)

const DocApi := preload("res://app/logic/doc_api.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")
const DocCommands := preload("res://app/logic/doc_commands.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const Serialization := preload("res://app/logic/serialization.gd")
const Templates := preload("res://app/logic/templates.gd")
const LlmPrompt := preload("res://app/logic/llm_prompt.gd")

const BAKED_EXPORT_PATH := "res://addons/text_fx/core/fx_baked_export.gd"
const MAX_UNDO := 200
const MAX_TIME := 3600.0
const EXPORT_KINDS := ["doc_json", "baked_json", "doc_string", "llm_prompt"]
## 언어 전환 시 템플릿 견본과 같으면 새 언어 값으로 바꾸는 필드.
const LOCALE_SAMPLE_KEYS := ["name", "text", "sub_text", "font", "sub_font"]

var doc: Dictionary
var time := 0.0
var playing := false
var locale := "ko"
var selection := ""
var template_id := ""          # 마지막으로 적용한 템플릿(언어 전환 견본 교체용)
var last_export: Dictionary = {}  # { ok, kind, text, hash, data? }
var last_error := ""

var _undo: Array = []   # [{before, after, tpl_before, tpl_after}]
var _redo: Array = []
var _coalesce_key := ""


func _init(start_doc: Dictionary = {}, start_locale: String = "ko") -> void:
	doc = DocApi.normalize(start_doc)
	if not DocApi.validate(doc).is_empty():
		doc = DocApi.defaults()
	locale = start_locale if start_locale in DocSchema.LOCALES else "ko"


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func doc_hash() -> String:
	return JsonUtil.stable_hash(doc)


func get_value(path: String):
	var r := DocSchema.get_at(doc, path)
	return r.value if r.ok else null


## UI 재생 시계. 유한한 종료 시각은 넘지 않는다. 명령·조작 기록에는 남지 않는다.
func advance(dt: float, end_time: float = INF) -> void:
	if playing and dt > 0.0:
		time = minf(time + dt, minf(end_time, MAX_TIME))
		changed.emit(PackedStringArray(["$time"]))


func apply(cmd) -> bool:
	last_error = ""
	if not (cmd is Dictionary) or not (cmd.get("op") is String):
		return _reject("command must be a dict with op")
	var op: String = cmd.op
	if DocCommands.is_doc_op(op):
		return _apply_doc(cmd)
	match op:
		"undo": return _undo_redo(true)
		"redo": return _undo_redo(false)
		"seek":
			var t = cmd.get("t")
			if not _valid_time(t):
				return _reject("bad t")
			time = float(t)
			_emit(["$time"])
			return true
		"play":
			if cmd.has("from"):
				if not _valid_time(cmd.from):
					return _reject("bad from")
				time = float(cmd.from)
			playing = true
			_emit(["$playing", "$time"])
			return true
		"pause":
			playing = false
			_emit(["$playing"])
			return true
		"set_locale": return _set_locale(cmd)
		"select":
			var p = cmd.get("path")
			if not (p is String) or p.length() > 200:
				return _reject("bad selection")
			selection = p
			_emit(["$selection"])
			return true
		"export": return _export(cmd)
	return _reject("unknown op '%s'" % op)


func _reject(msg: String) -> bool:
	last_error = msg
	return false


func _emit(paths: Array) -> void:
	changed.emit(PackedStringArray(paths))


func _valid_time(t) -> bool:
	return JsonUtil.is_number(t) and t >= 0.0 and t <= MAX_TIME


func _apply_doc(cmd: Dictionary) -> bool:
	var r := DocCommands.run(doc, cmd, locale)
	if not r.ok:
		return _reject(r.error)
	var tpl_after: String = r.get("template_id", template_id)
	var restart: bool = cmd.op == "apply_template"
	var paths: PackedStringArray = r.paths
	if restart:
		time = 0.0
		playing = true
		paths.append("$time")
		paths.append("$playing")
	var committed := _commit(r.doc, tpl_after, r.key, paths)
	if restart and not committed:
		# 같은 템플릿을 다시 눌러도 시계·미리보기의 종료 예약을 초기화한다.
		changed.emit(paths)
	return true


## 문서 교체 + 실행 취소 기록. key가 직전 기록과 같으면 하나로 합친다.
func _commit(next: Dictionary, tpl_after: String, key: String, paths: PackedStringArray) -> bool:
	var same := JsonUtil.canonical_json(next) == JsonUtil.canonical_json(doc) and tpl_after == template_id
	if same:
		return false
	if key != "" and key == _coalesce_key and not _undo.is_empty():
		var top: Dictionary = _undo[-1]
		top.after = next
		top.tpl_after = tpl_after
	else:
		_undo.append({"before": doc, "after": next, "tpl_before": template_id, "tpl_after": tpl_after})
		if _undo.size() > MAX_UNDO:
			_undo.pop_front()
	_coalesce_key = key
	_redo.clear()
	doc = next
	template_id = tpl_after
	var out := Array(paths)
	out.append("$history")
	_emit(out)
	return true


func _undo_redo(is_undo: bool) -> bool:
	var src: Array = _undo if is_undo else _redo
	var dst: Array = _redo if is_undo else _undo
	if src.is_empty():
		return _reject("nothing to " + ("undo" if is_undo else "redo"))
	var e: Dictionary = src.pop_back()
	dst.append(e)
	doc = e.before if is_undo else e.after
	template_id = e.tpl_before if is_undo else e.tpl_after
	_coalesce_key = ""
	_emit(["*", "$history"])
	return true


func _set_locale(cmd: Dictionary) -> bool:
	var loc = cmd.get("locale")
	if not (loc is String and loc in DocSchema.LOCALES):
		return _reject("bad locale")
	if loc == locale:
		return true
	var old := locale
	locale = loc
	_emit(["$locale"])
	if template_id != "" and Templates.has(template_id):
		var keep := {"canvas": doc.get("canvas"), "seed": doc.get("seed")}
		var was := Templates.build_doc(template_id, old, keep)
		var now := Templates.build_doc(template_id, loc, keep)
		var next: Dictionary = doc.duplicate(true)
		var paths: Array = []
		for k in LOCALE_SAMPLE_KEYS:
			if JsonUtil.canonical_json(doc.get(k)) == JsonUtil.canonical_json(was.get(k)):
				next[k] = now.get(k)
				paths.append(k)
		# 변이 전 문장도 템플릿 견본일 때만 언어를 바꾼다. 사용자가 쓴 문장은 유지한다.
		for segment in ["enter", "sub_enter"]:
			var path: String = "timeline." + segment + ".params.from_text"
			var current := DocSchema.get_at(doc, path)
			var previous := DocSchema.get_at(was, path)
			var translated := DocSchema.get_at(now, path)
			if current.ok and previous.ok and translated.ok and current.value == previous.value:
				next["timeline"][segment]["params"]["from_text"] = translated.value
				paths.append(path)
		if not paths.is_empty():
			var r := DocCommands.finish(next, paths)
			if r.ok:
				_coalesce_key = ""
				_commit(r.doc, template_id, "", r.paths)
	return true


func _export(cmd: Dictionary) -> bool:
	var kind = cmd.get("kind")
	if not (kind is String and kind in EXPORT_KINDS):
		return _reject("bad export kind")
	var text := ""
	var data = null
	match kind:
		"doc_json":
			text = JSON.stringify(doc, "\t", true)
		"doc_string":
			text = Serialization.encode(doc)
		"llm_prompt":
			var prompt := LlmPrompt.build(doc)
			if not prompt.ok:
				last_export = {"ok": false, "kind": kind, "text": "", "hash": "", "error": prompt.error}
				_emit(["$export"])
				return _reject(prompt.error)
			text = prompt.text
		"baked_json":
			var fps = cmd.get("fps", 30)
			if not JsonUtil.is_number(fps) or fps < 1 or fps > 120:
				return _reject("bad fps")
			var baked := _bake(int(fps))
			if not baked.ok:
				last_export = {"ok": false, "kind": kind, "text": "", "hash": "", "error": baked.error}
				_emit(["$export"])
				return _reject(baked.error)
			data = baked.data
			# 정규 JSON에서 프레임마다 줄을 나눠 텍스트 영역에서도 가볍게 보이게 한다(공백만 다름).
			text = JsonUtil.canonical_json(data).replace("]],[[", "]],\n[[")
	last_export = {"ok": true, "kind": kind, "text": text, "hash": text.sha256_text()}
	if data != null:
		last_export["data"] = data
	_emit(["$export"])
	return true


func _bake(fps: int) -> Dictionary:
	# 런타임 애드온이 없거나 깨져도 에디터 로직은 동작하도록 동적으로 불러온다.
	if not ResourceLoader.exists(BAKED_EXPORT_PATH):
		return {"ok": false, "error": "baked export unavailable: %s missing" % BAKED_EXPORT_PATH}
	var Baked = load(BAKED_EXPORT_PATH)
	if Baked == null or not Baked.has_method("bake"):
		return {"ok": false, "error": "baked export unavailable: bake() not found"}
	var data = Baked.bake(doc.duplicate(true), float(fps))
	if not (data is Dictionary) or data.get("format") != "text_fx_baked" or not (data.get("frames") is Array):
		return {"ok": false, "error": "baked export failed"}
	return {"ok": true, "data": data}
