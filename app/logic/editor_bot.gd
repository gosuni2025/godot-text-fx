extends RefCounted
## 시드로 결정되는 에디터 봇. UI 없이 EditorModel에 명령만 보내고, 보낸 명령을 OpLog에 남긴다.
## 난수는 자체 xorshift32 상태만 쓴다(전역 난수 미사용).

const EditorModel := preload("res://app/logic/editor_model.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")
const Templates := preload("res://app/logic/templates.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")

const TEXT_POOL := [
	"교전 개시", "등불이 꺼졌다", "썰물이 시작된다", "판정 성공", "서리목 등대", "다섯째 종, 썰물",
	"소금시장의 밤", "일곱 번째 등대\n\n아무도 불을 켜지 않았다",
	"交戦開始", "灯が消えた", "引き潮が始まる", "判定成功", "霜木灯台",
	"Engage", "The lamp goes out", "The tide recedes", "Fifth Bell, Ebb Tide", "The Seventh Light",
]
const SUB_POOL := ["", "첫 종, 밀물", "열두째 종, 무풍", "五の鐘、引き潮", "Ninth Bell, Night Market"]

## 무작위 탐색에서 행동별 가중치.
const WEIGHTS := {
	"template": 10, "tweak": 36, "text": 8, "list": 10, "seek": 8, "play": 4, "pause": 3,
	"undo": 6, "redo": 3, "locale": 4, "mode": 2, "export": 4, "select": 2,
}

var seed := 0
var model
var log
var _state := 1


func _init(p_seed: int, start_doc: Dictionary = {}, locale: String = "ko") -> void:
	seed = p_seed & 0x7FFFFFFF
	_state = (seed * 2654435761 + 0x6D2B79F5) & 0xFFFFFFFF
	if _state == 0:
		_state = 0x9E3779B9
	for i in 4:
		_next()
	model = EditorModel.new(start_doc, locale)
	log = OpLog.create(seed, model.doc, model.locale)


# --- 난수 ---------------------------------------------------------------

func _next() -> int:
	var x := _state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	_state = x & 0xFFFFFFFF
	return _state


func rand_float() -> float:
	return float(_next()) / 4294967296.0


func rand_int(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + _next() % (hi - lo + 1)


func pick(items):
	return items[rand_int(0, items.size() - 1)]


# --- 실행 ---------------------------------------------------------------

## 명령 하나를 보내고 기록한다(거부된 명령도 기록해 리플레이 결과까지 같게 한다).
func send(cmd: Dictionary) -> bool:
	log.append(cmd)
	return model.apply(cmd.duplicate(true))


func run_plan(cmds: Array) -> Array:
	var out: Array = []
	for c in cmds:
		out.append(send(c))
	return out


## 시드 기반 무작위 탐색. 첫 명령은 항상 템플릿 적용.
func run_random(steps: int) -> void:
	for i in steps:
		var cmd := random_command() if i > 0 else _cmd_template()
		send(cmd)


func random_command() -> Dictionary:
	var total := 0
	for k in WEIGHTS:
		total += WEIGHTS[k]
	var roll := rand_int(0, total - 1)
	var action := ""
	for k in WEIGHTS:
		roll -= WEIGHTS[k]
		if roll < 0:
			action = k
			break
	match action:
		"template": return _cmd_template()
		"tweak": return _cmd_tweak()
		"text": return {"op": "set_text", "text": pick(TEXT_POOL), "sub_text": pick(SUB_POOL)}
		"list": return _cmd_list()
		"seek": return {"op": "seek", "t": snappedf(rand_float() * 8.0, 0.01)}
		"play": return {"op": "play", "from": snappedf(rand_float() * 2.0, 0.01)}
		"pause": return {"op": "pause"}
		"undo": return {"op": "undo"}
		"redo": return {"op": "redo"}
		"locale": return {"op": "set_locale", "locale": pick(DocSchema.LOCALES)}
		"mode": return {"op": "set_mode", "mode": pick(DocSchema.MODES)}
		"export":
			var kind: String = pick(["doc_json", "doc_string", "baked_json"])
			return {"op": "export", "kind": kind, "fps": 10} if kind == "baked_json" else {"op": "export", "kind": kind}
		"select": return {"op": "select", "path": pick(DocSchema.TWEAKABLE)}
	return {"op": "pause"}


func _cmd_template() -> Dictionary:
	return {"op": "apply_template", "id": pick(Array(Templates.ids()))}


## 문서에 실제로 있는 필드 중 하나를 규칙 범위 안의 값으로 바꾼다.
func _cmd_tweak() -> Dictionary:
	for attempt in 8:
		var pattern: String = pick(DocSchema.TWEAKABLE)
		var path := _resolve(pattern)
		if path == "":
			continue
		var cur := DocSchema.get_at(model.doc, path)
		if not cur.ok:
			continue
		var rule = DocSchema.rules().get(pattern)
		if rule == null:
			continue
		return {"op": "set", "path": path, "value": random_value(rule, cur.value)}
	return {"op": "seek", "t": 0.0}


## "*"를 현재 문서의 실제 번호로 바꾼다. 해당 배열이 비면 "".
func _resolve(pattern: String) -> String:
	var segs := pattern.split(".")
	var cur = model.doc
	for i in segs.size():
		if cur is Array:
			if cur.is_empty():
				return ""
			segs[i] = str(rand_int(0, cur.size() - 1))
			cur = cur[int(segs[i])]
		elif cur is Dictionary and cur.has(segs[i]):
			cur = cur[segs[i]]
		else:
			return ""
	return ".".join(segs)


func random_value(rule: Dictionary, current):
	match rule.t:
		"num", "int":
			var lo: float = rule.min
			var hi: float = rule.max
			# 넓은 범위는 현재 값 주변에서 고른다(쓸 만한 문서를 유지).
			if JsonUtil.is_number(current) and hi - lo > 20.0:
				var span := (hi - lo) * 0.15
				lo = maxf(lo, current - span)
				hi = minf(hi, current + span)
			if rule.t == "int":
				return float(rand_int(int(ceilf(lo)), int(floorf(hi))))
			return snappedf(lo + rand_float() * (hi - lo), 0.01)
		"bool":
			return not current if current is bool else rand_int(0, 1) == 1
		"enum":
			return pick(rule.v)
		"color":
			return "#%02X%02X%02X%02X" % [rand_int(0, 255), rand_int(0, 255), rand_int(0, 255), rand_int(128, 255)]
		"vec2":
			var lo2: float = maxf(rule.min, -64.0)
			var hi2: float = minf(rule.max, 64.0)
			return [snappedf(lo2 + rand_float() * (hi2 - lo2), 0.01), snappedf(lo2 + rand_float() * (hi2 - lo2), 0.01)]
	return current



func _cmd_list() -> Dictionary:
	var path: String = pick(["decorations", "timeline.hold.effects"])
	var items: Array = model.doc.get("decorations", []) if path == "decorations" \
		else model.doc.timeline.hold.effects
	var kind := rand_int(0, 3)
	if items.is_empty() or kind <= 1:
		var types = DocSchema.DECORATIONS if path == "decorations" else DocSchema.HOLD_EFFECTS
		return {"op": "list_add", "path": path, "value": pick(types)}
	if kind == 2 or items.size() < 2:
		return {"op": "list_remove", "path": path, "index": rand_int(0, items.size() - 1)}
	return {"op": "list_move", "path": path, "from": rand_int(0, items.size() - 1), "to": rand_int(0, items.size() - 1)}


func final_hash() -> String:
	return model.doc_hash()
