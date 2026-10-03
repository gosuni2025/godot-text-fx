class_name TextFxTextRules
extends RefCounted
## 문자 분류 규칙: 공백, CJK 판정, 금칙, 세로쓰기 회전·보정, 구두점 쉼.

## 줄머리 금지: 닫는 괄호·구두점·장음·작은 가나 등.
const NO_START := "、。，．,.・：；:;？！?!‼⁇⁈⁉ー－～〜…‥）〕］｝〉》」』】〙〗〟’”)]}ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻゛゜ゝゞヽヾ%％"
## 줄끝 금지: 여는 괄호류.
const NO_END := "（〔［｛〈《「『【〘〖〝‘“([{"
## 세로쓰기에서 90° 회전하는 문자(장음·대시·괄호류). 라틴 계열은 코드 범위로 따로 판정한다.
const VERTICAL_ROTATE := "ー－～〜…‥—―–-=＝（）〔〕［］｛｝〈〉《》「」『』【】〘〙〖〗()[]{}<>＜＞"
const SMALL_KANA := "ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ"
const VERTICAL_PUNCT := "、。，．"
## 구두점 뒤 쉼(params.punct_pause)을 주는 문자.
const PAUSE_PUNCT := "、。，．,.！？!?…‥：；:;"


static func code(c: String) -> int:
	return c.unicode_at(0) if c.length() > 0 else 0


static func is_space(c: String) -> bool:
	return c == " " or c == "\t" or c == "　"


static func is_hangul(c: String) -> bool:
	var u := code(c)
	return (u >= 0xAC00 and u <= 0xD7AF) or (u >= 0x1100 and u <= 0x11FF) or (u >= 0x3130 and u <= 0x318F)


## 글자 단위로 줄을 나눌 수 있는 CJK 문자(한자·가나·CJK 기호·전각). 한글은 단어 단위(keep-all)라 제외.
static func is_cjk(c: String) -> bool:
	var u := code(c)
	return (u >= 0x3000 and u <= 0x30FF) or (u >= 0x3400 and u <= 0x4DBF) or (u >= 0x4E00 and u <= 0x9FFF) \
		or (u >= 0xF900 and u <= 0xFAFF) or (u >= 0xFF00 and u <= 0xFFEF) or (u >= 0x31F0 and u <= 0x31FF) \
		or (u >= 0x20000 and u <= 0x3FFFF)


static func no_start(c: String) -> bool:
	return c != "" and NO_START.contains(c)


static func no_end(c: String) -> bool:
	return c != "" and NO_END.contains(c)


static func is_pause_punct(c: String) -> bool:
	return c != "" and PAUSE_PUNCT.contains(c)


## 세로쓰기에서 옆으로 눕혀(90° 시계 방향) 그리는가.
static func vertical_rotate(c: String) -> bool:
	if c == "" or is_space(c):
		return false
	if VERTICAL_ROTATE.contains(c):
		return true
	var u := code(c)
	return u > 0x20 and u < 0x1100


## 세로쓰기 위치 보정(em 비율). 구두점은 오른쪽 위, 작은 가나는 살짝 오른쪽 위.
static func vertical_offset(c: String) -> Vector2:
	if VERTICAL_PUNCT.contains(c):
		return Vector2(0.5, -0.5)
	if SMALL_KANA.contains(c):
		return Vector2(0.1, -0.1)
	return Vector2.ZERO


## 문자열 → 한 글자 문자열 배열(코드 포인트 단위).
static func chars(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in text.length():
		out.append(text[i])
	return out
