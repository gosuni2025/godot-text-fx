extends RefCounted
## 예시 연출 JSON의 원본 정의. 실제 편집기 로직(EditorModel)에 명령을 보내 만들고 `export` 명령 결과를 그대로 쓴다.
## 게임 런타임(examples/game_demo)은 이 파일을 쓰지 않는다. 결과 파일만 읽는다.
##   생성: godot --headless --path . --script res://examples/tools/gen_examples.gd
##   검사: tests/example_demo.gd 가 build_all() 결과와 examples/fx/ 파일이 같은지 비교한다(결정론).

const EditorModel := preload("res://app/logic/editor_model.gd")

const OUT_DIR := "res://examples/fx"

## file: 출력 파일명, locale: 편집기 언어, commands: 편집기 명령 목록, export: 내보내기 명령.
const SPECS := [
	{
		"file": "battle_cutin.json",
		"commands": [
			{"op": "apply_template", "id": "msg_battle_engage"},
		],
		"export": {"op": "export", "kind": "doc_json"},
	},
	{
		"file": "battle_cutin.baked.json",
		"commands": [
			{"op": "apply_template", "id": "msg_battle_engage"},
		],
		"export": {"op": "export", "kind": "baked_json", "fps": 30},
	},
	{
		# loop_hold: 게임이 finish()를 부를 때까지 유지 구간을 반복한다.
		"file": "check_result.json",
		"commands": [
			{"op": "apply_template", "id": "msg_check_success"},
			{"op": "set_text", "text": "등화 신호 일치", "sub_text": "주사위 17 / 목표 12"},
			{"op": "set", "path": "layout.sub.font_size", "value": 36},
		],
		"export": {"op": "export", "kind": "doc_json"},
	},
	{
		# 빈 줄로 나뉜 여러 페이지 트레일러.
		"file": "trailer_intro.json",
		"commands": [
			{"op": "apply_template", "id": "trl_line_by_line"},
		],
		"export": {"op": "export", "kind": "doc_json"},
	},
	{
		# 장소명 + 보조 문구(시간). 게임이 set_text()로 장소를 바꾼다.
		"file": "location_caption.json",
		"commands": [
			{"op": "apply_template", "id": "cap_converge"},
			{"op": "set", "path": "layout.anchor", "value": [0.5, 0.3]},
		],
		"export": {"op": "export", "kind": "doc_json"},
	},
	{
		# 캐릭터 머리 위에 띄우는 작은 피해 숫자. 작은 캔버스(320×180)로 만들어 작은 TextFxPlayer에 맞춘다.
		"file": "damage_number.json",
		"commands": [
			{"op": "apply_template", "id": "msg_battle_engage"},
			{"op": "set", "path": "name", "value": "피해 숫자"},
			{"op": "set", "path": "canvas.width", "value": 320},
			{"op": "set", "path": "canvas.height", "value": 180},
			{"op": "set_text", "text": "128", "sub_text": ""},
			{"op": "set", "path": "layout.font_size", "value": 72},
			{"op": "set", "path": "layout.min_font_size", "value": 24},
			{"op": "set", "path": "style.outline.size", "value": 5},
			{"op": "set", "path": "style.outline2.size", "value": 2},
			{"op": "set", "path": "style.shadow.offset", "value": [3, 4]},
			{"op": "list_remove", "path": "decorations", "index": 0},
			{"op": "list_remove", "path": "timeline.hold.effects", "index": 0},
			{"op": "set", "path": "timeline.enter.stagger", "value": 0.04},
			{"op": "set", "path": "timeline.hold.duration", "value": 0.35},
			{"op": "set", "path": "timeline.exit.effect", "value": "slide"},
			{"op": "set", "path": "timeline.exit.params", "value": {"dir": "up", "distance": 0.6}, "merge": false},
			{"op": "set", "path": "timeline.exit.duration", "value": 0.4},
			{"op": "set", "path": "timeline.exit.easing", "value": "cubic_in"},
		],
		"export": {"op": "export", "kind": "doc_json"},
	},
]


## 정의 하나를 새 모델에서 실행해 내보내기 문자열을 만든다. 실패하면 { ok: false, error }.
static func build(spec: Dictionary) -> Dictionary:
	var model := EditorModel.new({}, str(spec.get("locale", "ko")))
	for cmd in spec.commands:
		if not model.apply(cmd):
			return {"ok": false, "error": "%s: %s 거부됨 (%s)" % [spec.file, JSON.stringify(cmd), model.last_error]}
	if not model.apply(spec.export) or not model.last_export.get("ok", false):
		return {"ok": false, "error": "%s: 내보내기 실패 (%s)" % [spec.file, model.last_error]}
	return {"ok": true, "text": str(model.last_export.text)}


## 모든 정의를 만든다. { files: {파일명: 문자열}, errors: PackedStringArray }
static func build_all() -> Dictionary:
	var files := {}
	var errors := PackedStringArray()
	for spec in SPECS:
		var r := build(spec)
		if r.ok:
			files[spec.file] = r.text
		else:
			errors.append(r.error)
	return {"files": files, "errors": errors}
