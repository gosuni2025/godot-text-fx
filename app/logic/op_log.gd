extends RefCounted
## 조작 기록: 시작 문서 + 시작 언어 + 시드 + 명령 목록.
## serialize()는 Serialization의 "TFX1:" 한 줄 문자열. 내용 JSON의 format은 "text_fx_oplog".

const Serialization := preload("res://app/logic/serialization.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")
const Self := preload("res://app/logic/op_log.gd")

const FORMAT := "text_fx_oplog"
const FORMAT_VERSION := 1
const MAX_COMMANDS := 100000

var seed := 0
var locale := "ko"
var start_doc: Dictionary = {}
var commands: Array = []


static func create(p_seed: int = 0, p_start_doc: Dictionary = {}, p_locale: String = "ko"):
	var log = Self.new()
	log.seed = p_seed
	log.start_doc = JsonUtil.canon(p_start_doc)
	log.locale = p_locale
	return log


func append(cmd: Dictionary) -> void:
	commands.append(JsonUtil.canon(cmd))


func to_dict() -> Dictionary:
	return {"format": FORMAT, "format_version": FORMAT_VERSION, "seed": seed, "locale": locale,
		"start_doc": start_doc, "commands": commands}


func serialize() -> String:
	return Serialization.encode(to_dict())


## {ok, log, error}
static func from_dict(d) -> Dictionary:
	if not (d is Dictionary):
		return _fail("not a dict")
	if d.get("format") != FORMAT:
		return _fail("not an oplog")
	var ver = d.get("format_version")
	if not JsonUtil.is_number(ver) or int(ver) != FORMAT_VERSION:
		return _fail("unsupported oplog version")
	var s = d.get("seed", 0)
	var loc = d.get("locale", "ko")
	var sd = d.get("start_doc", {})
	var cmds = d.get("commands", [])
	if not JsonUtil.is_number(s) or not (loc is String and loc in DocSchema.LOCALES):
		return _fail("bad seed/locale")
	if not (sd is Dictionary) or not (cmds is Array) or cmds.size() > MAX_COMMANDS:
		return _fail("bad start_doc/commands")
	for c in cmds:
		if not (c is Dictionary) or not (c.get("op") is String):
			return _fail("bad command entry")
	var log = create(int(s), sd, loc)
	for c in cmds:
		log.append(c)
	return {"ok": true, "log": log, "error": ""}


static func parse(text: String) -> Dictionary:
	var dec := Serialization.decode(text)
	if not dec.ok:
		return _fail(dec.error)
	return from_dict(dec.data)


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "log": null, "error": msg}
