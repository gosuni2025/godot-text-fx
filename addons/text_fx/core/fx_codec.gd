class_name TextFxCodec
extends RefCounted
## 한 줄 클립보드 문자열: "TFX1:" + base64(deflate(JSON)). 문서·조작 기록 모두 같은 방식(DESIGN §5.3).
## JSON은 키를 정렬해 같은 값이면 같은 문자열이 나온다.

const PREFIX := "TFX1:"


static func encode(value: Variant) -> String:
	var raw := JSON.stringify(value, "", true).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return PREFIX + Marshalls.raw_to_base64(packed)


## 실패하면 null.
static func decode(text: String) -> Variant:
	var s := text.strip_edges()
	if not s.begins_with(PREFIX):
		return null
	var body := s.substr(PREFIX.length())
	var re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or re.search(body) == null:
		return null
	var packed := Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return null
	var raw := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return null
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return null
	return json.data
