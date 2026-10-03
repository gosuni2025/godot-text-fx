extends RefCounted
## 클립보드용 한 줄 문자열: "TFX1:" + base64(deflate(JSON)).
## 접두사의 숫자가 컨테이너 버전이다. 내용(JSON)의 종류·버전은 각 사용처(문서/조작 기록)가 검사한다.

const JsonUtil := preload("res://app/logic/json_util.gd")

const PREFIX := "TFX"
const VERSION := 1
const HEADER := "TFX1:"
const MAX_DECOMPRESSED := 16 * 1024 * 1024


static func encode(data) -> String:
	var json := JsonUtil.canonical_json(data)
	var packed := json.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return HEADER + Marshalls.raw_to_base64(packed)


## {ok: bool, data, error: String}
static func decode(text: String) -> Dictionary:
	var s := text.strip_edges()
	if not s.begins_with(PREFIX):
		return _fail("not a TFX string")
	var colon := s.find(":")
	if colon < 0:
		return _fail("missing ':'")
	var ver_str := s.substr(PREFIX.length(), colon - PREFIX.length())
	if not ver_str.is_valid_int():
		return _fail("bad version")
	if ver_str.to_int() != VERSION:
		return _fail("unsupported version %s" % ver_str)
	var body := s.substr(colon + 1)
	if not _is_base64(body):
		return _fail("bad base64")
	var raw := Marshalls.base64_to_raw(body)
	if raw.size() < 2 or not _looks_like_zlib(raw):
		return _fail("bad compressed data")
	var bytes := raw.decompress_dynamic(MAX_DECOMPRESSED, FileAccess.COMPRESSION_DEFLATE)
	if bytes.is_empty():
		return _fail("decompression failed")
	var json := bytes.get_string_from_utf8()
	var data = JsonUtil.parse(json)
	if data == null:
		return _fail("bad json")
	return {"ok": true, "data": data, "error": ""}


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "data": null, "error": msg}


static func _is_base64(s: String) -> bool:
	if s.is_empty() or s.length() % 4 != 0:
		return false
	var re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	return re.search(s) != null


## zlib 헤더(CMF/FLG) 검사로 손상된 문자열을 엔진 오류 전에 대부분 걸러낸다.
static func _looks_like_zlib(raw: PackedByteArray) -> bool:
	var cmf := raw[0]
	var flg := raw[1]
	return (cmf & 0x0F) == 8 and ((cmf << 8) | flg) % 31 == 0
