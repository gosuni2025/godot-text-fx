extends RefCounted
## 포맷 3의 새 연출 입력 검증. 정규화가 잘못된 원본 값을 가리기 전에 검사한다.

const Cinematic := preload("res://addons/text_fx/core/fx_effects_cinematic.gd")
const IDS := Cinematic.IDS
const MAX_TEXT := 4000


static func validate(segment: Variant, name: String, errors: PackedStringArray) -> void:
	if not segment is Dictionary:
		return
	var effect := str(segment.get("effect", ""))
	if effect not in IDS and effect != "text_morph":
		return
	var path := "timeline." + name
	if effect == "text_morph" and name == "exit":
		errors.append(path + ".effect: text_morph는 등장 전용")
	var params: Variant = segment.get("params", {})
	if not params is Dictionary:
		errors.append(path + ".params는 객체여야 함")
		return
	path += ".params."
	_number(params, "intensity", 0.0, 3.0, false, path, errors)
	if effect == "text_morph":
		_number(params, "readable_ratio", 0.0, 0.8, false, path, errors)
		if params.has("from_text") and (not params.from_text is String or params.from_text.length() > MAX_TEXT):
			errors.append(path + "from_text는 4000자 이하 문자열이어야 함")
	else:
		_number(params, "detail", 2.0, 16.0, true, path, errors)
		_number(params, "distance", 0.0, 5.0, false, path, errors)
		if params.has("color") and not _color(params.color):
			errors.append(path + "color 색 형식 오류")


static func _number(params: Dictionary, key: String, low: float, high: float, integer: bool,
		path: String, errors: PackedStringArray) -> void:
	if not params.has(key):
		return
	var value: Variant = params[key]
	if not (value is int or value is float) or not is_finite(float(value)) \
			or float(value) < low or float(value) > high or (integer and float(value) != floorf(float(value))):
		errors.append(path + key + " 값 범위/형식 오류")


static func _color(value: Variant) -> bool:
	return value is String and value.begins_with("#") and value.length() in [7, 9] \
		and value.substr(1).is_valid_hex_number(false)
