extends RefCounted
## JSON 모양 값 도우미: 정수→실수 정규화, 정렬된 정규 JSON, 안정 해시.
## Godot JSON 파서는 모든 수를 float으로 돌려주므로, 모델 안의 문서도 같은 모양으로 유지해
## "문서 → JSON → 문서" 왕복 후에도 같은 해시가 나오게 한다.


## int를 float으로 바꾼 깊은 복사본. 사전·배열·문자열·bool·null·수만 남긴다.
static func canon(v):
	match typeof(v):
		TYPE_INT:
			return float(v)
		TYPE_FLOAT, TYPE_BOOL, TYPE_NIL:
			return v
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = canon(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, \
				TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var a := []
			for x in v:
				a.append(canon(x))
			return a
		TYPE_VECTOR2:
			return [float(v.x), float(v.y)]
	return str(v)


## 키 정렬·들여쓰기 없는 정규 JSON.
static func canonical_json(v) -> String:
	return JSON.stringify(canon(v), "", true)


static func stable_hash(v) -> String:
	return canonical_json(v).sha256_text()


static func is_number(v) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) == TYPE_FLOAT:
		return not (is_nan(v) or is_inf(v))
	return false


## JSON 문자열을 파싱한다. 실패하면 null.
static func parse(text: String):
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data
