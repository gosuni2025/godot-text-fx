extends RefCounted
## 에디터 로직: TFX1 직렬화 왕복·손상 입력·OpLog 직렬화/파싱.

const Serialization := preload("res://app/logic/serialization.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const DocApi := preload("res://app/logic/doc_api.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const Templates := preload("res://app/logic/templates.gd")
const CODEC_PATH := "res://addons/text_fx/core/fx_codec.gd"


func run(t) -> void:
	_round_trip(t)
	_garbage(t)
	_oplog(t)
	_codec_compat(t)


func _round_trip(t) -> void:
	var doc := Templates.build_doc("trl_typewriter_log", "ja")
	var s := Serialization.encode(doc)
	t.ok(s.begins_with("TFX1:"), "prefix")
	t.ok(s.find("\n") < 0, "single line")
	var r := Serialization.decode(s)
	t.ok(r.ok, "decode ok")
	t.eq(JsonUtil.stable_hash(r.data), JsonUtil.stable_hash(doc), "round trip hash")
	t.eq(Serialization.encode(r.data), s, "re-encode identical")
	var r2 := Serialization.decode("  " + s + "\n")
	t.ok(r2.ok, "whitespace tolerated")
	var odd := {"s": "따옴표\" 역슬래시\\ 줄\n바꿈 😀", "n": [0.1, -3.25, 1e-7], "b": false, "z": null}
	t.eq(JsonUtil.stable_hash(Serialization.decode(Serialization.encode(odd)).data), JsonUtil.stable_hash(odd), "odd values")


func _garbage(t) -> void:
	var valid := Serialization.encode({"a": 1})
	var cases := ["", "hello", "TFX1:", "TFX1:!!!!", "TFX1:abc", "TFX2:" + valid.substr(5), "TFXx:AAAA",
		"TFX1:AAAAAAAA", "TFX1:" + Marshalls.utf8_to_base64("{\"a\":1}"),
		valid.substr(0, valid.length() - 4)]
	for c in cases:
		var r := Serialization.decode(c)
		t.ok(not r.ok and r.error != "", "garbage rejected: '%s' (%s)" % [c, r.error])
	var r3 := Serialization.decode("TFX2:" + valid.substr(5))
	t.ok(r3.error.find("version") >= 0, "version error message")


func _oplog(t) -> void:
	var log = OpLog.create(42, DocApi.defaults(), "en")
	log.append({"op": "apply_template", "id": "cap_converge"})
	log.append({"op": "set", "path": "layout.font_size", "value": 70})
	log.append({"op": "seek", "t": 1.25})
	var s: String = log.serialize()
	var p := OpLog.parse(s)
	t.ok(p.ok, "oplog parse ok")
	t.eq(p.log.seed, 42, "seed kept")
	t.eq(p.log.locale, "en", "locale kept")
	t.eq(p.log.commands.size(), 3, "commands kept")
	t.eq(p.log.serialize(), s, "oplog re-serialize identical")
	t.ok(not OpLog.parse("TFX1:zzzz").ok, "bad oplog string")
	t.ok(not OpLog.parse(Serialization.encode(DocApi.defaults())).ok, "doc string is not an oplog")
	t.ok(not OpLog.from_dict({"format": "text_fx_oplog", "format_version": 2}).ok, "future version rejected")
	t.ok(not OpLog.from_dict({"format": "text_fx_oplog", "format_version": 1, "commands": [5]}).ok, "bad command entry")


## 런타임 TextFxCodec과 같은 형식인지 교차 확인(있을 때만).
func _codec_compat(t) -> void:
	if not ResourceLoader.exists(CODEC_PATH):
		t.log("fx_codec.gd 없음: 교차 확인 생략")
		return
	var Codec = load(CODEC_PATH)
	var doc := Templates.build_doc("msg_check_critical", "ko")
	var from_codec = Serialization.decode(Codec.encode(doc))
	t.ok(from_codec.ok, "decode codec string")
	t.eq(JsonUtil.stable_hash(from_codec.data), JsonUtil.stable_hash(doc), "codec → logic")
	t.eq(JsonUtil.stable_hash(Codec.decode(Serialization.encode(doc))), JsonUtil.stable_hash(doc), "logic → codec")
