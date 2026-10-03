extends RefCounted
## 문서 기본값·정규화 창구. 기본값·정규화는 런타임 TextFxDoc(addons/text_fx/core/fx_doc.gd)를 그대로 쓰고,
## 에디터 쪽은 결과를 JSON 모양(수는 float, json_util.canon)으로 맞추고 doc_schema 규칙으로 더 엄격히 검사한다.

const TextFxDoc := preload("res://addons/text_fx/core/fx_doc.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")

const FORMAT_VERSION := TextFxDoc.FORMAT_VERSION


static func defaults() -> Dictionary:
	return JsonUtil.canon(TextFxDoc.defaults())


static func normalize(doc: Dictionary) -> Dictionary:
	return JsonUtil.canon(TextFxDoc.normalize(doc))


static func decoration_defaults(type: String) -> Dictionary:
	return JsonUtil.canon(TextFxDoc.default_decoration(type))


static func hold_effect_defaults(type: String) -> Dictionary:
	return JsonUtil.canon(Hold.default_params(type))


## 정규화된 문서의 오류 목록(비면 유효): 에디터 필드 규칙 + 런타임 검사.
static func validate(doc: Dictionary) -> PackedStringArray:
	var errors := DocSchema.validate_doc(doc)
	errors.append_array(TextFxDoc.validate(doc))
	return errors


## 정규화 전 원본 문서 검사(불러오기용). 런타임이 조용히 교정할 값도 오류로 알린다.
static func validate_source(doc: Dictionary) -> PackedStringArray:
	return TextFxDoc.validate(doc)


## base 위에 over를 깊게 덮는다(사전만 재귀, 배열·값은 교체). 템플릿 패치용. 둘 다 복사한다.
static func merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k in over:
		var v = over[k]
		if v is Dictionary and out.get(k) is Dictionary:
			out[k] = merge(out[k], v)
		elif v is Dictionary or v is Array:
			out[k] = v.duplicate(true)
		else:
			out[k] = v
	return out
