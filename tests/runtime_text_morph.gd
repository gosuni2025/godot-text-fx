extends RefCounted
## 실제 서로 다른 문장·줄바꿈·공통 글자·독립 보조·베이크 원문 슬롯의 회귀.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Plan := preload("res://addons/text_fx/render/fx_bake_plan.gd")
const Baked := preload("res://addons/text_fx/core/fx_baked_export.gd")
const Model := preload("res://app/logic/editor_model.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const Replay := preload("res://app/logic/replay.gd")


func _doc() -> Dictionary:
	var doc := Doc.defaults()
	doc["text"] = "진실 기억"
	doc["timeline"]["enter"].merge({"effect": "text_morph", "duration": 1.0, "order": "all", "stagger": 0.0,
		"easing": "linear", "params": {"from_text": "거짓된 기억\n달", "readable_ratio": 0.3, "intensity": 1.0}}, true)
	return Doc.normalize(doc)


func _dump(states: Array) -> Array:
	return states.map(func(state): return state.to_dict())


func run(t) -> void:
	_runtime(t)
	_empty_and_sub(t)
	_pages_and_companions(t)
	_opacity_and_overlay(t)
	_bake(t)
	_commands(t)


func _runtime(t) -> void:
	var doc := _doc()
	var ev := Evaluator.new(doc)
	var group: Dictionary = ev.text_morph["groups"][0]
	t.ok(group["layout"]["lines"].size() > ev.layout["lines"].size(), "원문 줄바꿈을 최종 문장과 독립 배치")
	var initial := ev.evaluate(0.0)
	var visible := initial.filter(func(state): return state.visible)
	t.eq(visible.size(), group["sources"].size(), "처음에는 원문의 모든 글자가 읽힘")
	for glyph in group["sources"]:
		var found := visible.any(func(state): return state.character == glyph["char"] and state.pos.distance_to(glyph["pos"]) < 0.001)
		t.ok(found, "원문 실제 글자와 위치: " + str(glyph["char"]))
	t.eq(_dump(initial), _dump(ev.evaluate(0.2)), "읽기 구간에서 원문 유지")
	var middle := ev.evaluate(0.6)
	t.ok(middle.any(func(state): return state.visible and not state.sprite_key.is_empty() and not state.slices.is_empty()), "사라지는 원문 획이 뒤틀림")
	t.ok(middle.any(func(state): return state.visible and state.index < ev.layout["glyphs"].size() and state.alpha < 1.0), "새 실제 글자가 드러남")
	for index in group["pairs"]:
		var source: Dictionary = group["pairs"][index]
		t.near(initial[index].pos, source["pos"], 0.001, "공통 문자는 원문 위치에서 시작")
		t.near(initial[index].alpha, 1.0, 0.001, "공통 문자는 깜빡이지 않음")
		t.ok(middle[index].pos.distance_to(ev.layout["glyphs"][index]["pos"]) < initial[index].pos.distance_to(ev.layout["glyphs"][index]["pos"]), "공통 문자는 최종 위치로 이어 이동")
	var settled := ev.evaluate(1.1)
	t.eq(settled.size(), ev.layout["glyphs"].size(), "유지 단계에서 원문 임시 상태 제거")
	for state in settled:
		t.ok(state.visible and state.sprite_key.is_empty(), "최종 문장 원래 스프라이트만 표시")
		t.near(state.pos, ev.layout["glyphs"][state.index]["pos"], 0.001, "최종 배치 정확 복원")
		t.near(state.scale, Vector2.ONE, 0.001, "최종 크기 정확 복원")
	var other := Evaluator.new(doc)
	for time in [0.8, 0.1, 0.6, 0.0, 1.3, 0.6]:
		t.eq(_dump(ev.evaluate(time)), _dump(other.evaluate(time)), "임의 순서 seek 결정론 @%s" % time)
	t.ok(ev.evaluate(ev.get_duration() + 1.0).all(func(state): return not state.visible), "종료 후 원문도 남지 않음")
	doc["layout"]["direction"] = "vertical"
	doc["text"] = "AB 기억"
	doc["timeline"]["enter"]["params"]["from_text"] = "A의 기록\nB 기억"
	var vertical := Evaluator.new(doc)
	t.ok(vertical.evaluate(0.6).all(func(state): return is_finite(state.pos.x) and is_finite(state.scale.x) and is_finite(state.rotation)), "세로쓰기·라틴 회전도 유한 상태")


func _empty_and_sub(t) -> void:
	var doc := _doc()
	doc["text"] = ""
	var empty := Evaluator.new(doc)
	t.near(empty.timeline.pages[0]["enter_len"], 1.0, 0.001, "빈 최종 문장도 원문 읽기·변이 시간 보존")
	t.ok(empty.evaluate(0.1).any(func(state): return state.visible), "빈 문장으로 변이하기 전 원문 표시")
	t.eq(empty.evaluate(1.1).size(), 0, "빈 최종 문장으로 실제 소멸")
	doc = _doc()
	doc["timeline"]["enter"]["params"]["from_text"] = ""
	var no_source := Evaluator.new(doc)
	t.eq(no_source.text_morph["groups"].size(), 0, "빈 원문은 별도 배치 없이 fade")
	t.ok(no_source.evaluate(0.0).all(func(state): return not state.visible), "빈 원문은 숨김 상태에서 시작")
	t.near(no_source.evaluate(0.5)[0].alpha, 0.5, 0.001, "빈 원문 fallback은 선형 fade")
	doc = _doc()
	doc["timeline"]["enter"] = Doc.defaults()["timeline"]["enter"]
	doc["timeline"]["enter"]["order"] = "all"
	doc["sub_text"] = "새벽"
	doc["timeline"]["sub_enter"] = {"effect": "text_morph", "duration": 1.0, "order": "all", "stagger": 0.0,
		"delay": 0.1, "easing": "linear", "params": {"from_text": "깊은 밤", "readable_ratio": 0.3, "intensity": 1.0}}
	var sub := Evaluator.new(doc)
	var start := float(sub.timeline.pages[0]["sub_enter_start"])
	t.ok(sub.evaluate(start - 0.01).all(func(state): return state.role != "sub" or not state.visible), "독립 보조 시작 전 원문도 숨김")
	var first := sub.evaluate(start + 0.1).filter(func(state): return state.role == "sub" and state.visible)
	t.eq(first.map(func(state): return state.character), ["깊", "은", "밤"], "from_text가 보조 문장에만 적용")
	t.ok(sub.evaluate(start + 1.1).filter(func(state): return state.role == "sub").all(func(state): return state.visible and state.sprite_key.is_empty()), "보조 최종 문장으로 변이 완료")
	doc["sub_text"] = ""
	var vanished_sub := Evaluator.new(doc)
	t.ok(vanished_sub.evaluate(float(vanished_sub.timeline.pages[0]["sub_enter_start"]) + 0.1).any(func(state): return state.role == "sub" and state.visible), "빈 최종 보조 문장도 원문을 먼저 읽음")


func _pages_and_companions(t) -> void:
	var doc := _doc()
	doc["mode"] = "trailer"
	doc["text"] = "기억\n\n진실"
	doc["sub_text"] = "ONE\n\nTWO"
	doc["timeline"]["enter"]["params"]["from_text"] = "낡은 기억"
	var ev := Evaluator.new(doc)
	t.eq(ev.text_morph["groups"].size(), 2, "최종 문장 페이지 수를 유지")
	for group in ev.text_morph["groups"]:
		var text := "".join(group["sources"].map(func(glyph): return glyph["char"]))
		t.eq(text, "낡은기억", "반대 보조문이 여러 페이지여도 단일 원문 반복")
		var page := int(group["page"])
		var frame := ev.evaluate(float(ev.timeline.pages[page]["start"]) + 0.2)
		t.ok(frame.filter(func(state): return state.visible).all(func(state): return state.page == page), "다른 페이지의 원문이 함께 나타나지 않음")
	doc["timeline"]["enter"]["params"]["from_text"] = "하나\n\n둘\n\n셋"
	var extra := Evaluator.new(doc)
	var last: Dictionary = extra.text_morph["groups"][1]
	t.eq("".join(last["sources"].map(func(glyph): return glyph["char"])), "둘셋", "초과 원문 페이지도 마지막 페이지에 보존")
	t.eq(extra.timeline.page_count, 2, "초과 원문이 최종 페이지 재생 순서를 바꾸지 않음")
	doc = _doc()
	doc["sub_text"] = "보조 문구"
	var paired := Evaluator.new(doc)
	var layout: Dictionary = paired.text_morph["groups"][0]["layout"]
	var source_sub: Array = layout["glyphs"].filter(func(glyph): return glyph["role"] == "sub")
	var state_sub: Array = paired.evaluate(0.2).filter(func(state): return state.role == "sub")
	for i in source_sub.size():
		t.near(state_sub[i].pos, source_sub[i]["pos"], 0.001, "긴 원문을 읽는 동안 보조 문구도 원문 배치 유지")
	var final_sub: Array = paired.evaluate(1.1).filter(func(state): return state.role == "sub")
	for state in final_sub:
		t.near(state.pos, paired.layout["glyphs"][state.index]["pos"], 0.001, "완료 후 보조 문구 최종 배치 복원")
	doc = _doc()
	doc["text"] = "긴 문장\n두 번째 줄\n세 번째 줄"
	doc["sub_text"] = "새벽"
	doc["timeline"]["enter"]["params"]["from_text"] = "짧은 글"
	doc["timeline"]["sub_enter"] = {"effect": "text_morph", "duration": 1.0, "order": "all", "stagger": 0.0,
		"delay": 0.0, "easing": "linear", "params": {"from_text": "깊은 밤\n감춰진 별", "readable_ratio": 0.3, "intensity": 1.0}}
	var sequential := Evaluator.new(doc)
	var source_sub_rect: Rect2 = sequential.text_morph["groups"][1]["layout"]["pages"][0]["sub_rect"]
	var target_main_rect: Rect2 = sequential.layout["pages"][0]["main_rect"]
	t.ok(source_sub_rect.position.y > target_main_rect.end.y, "순차 보조 원문이 길어진 최종 본문과 겹치지 않음")
	var after_main := sequential.evaluate(float(sequential.timeline.pages[0]["sub_enter_start"]) + 0.1)
	for state in after_main:
		if state.role == "main":
			t.near(state.pos, sequential.layout["glyphs"][state.index]["pos"], 0.001, "보조 변이 중 완료된 본문 위치 유지")


func _opacity_and_overlay(t) -> void:
	var doc := _doc()
	doc["style"]["opacity"] = 0.35
	var ev := Evaluator.new(doc)
	for state in ev.evaluate(0.1):
		if state.visible:
			t.near(state.alpha, 0.35, 0.001, "원문과 공통 문자 모두 스타일 opacity 적용")
	doc = _doc()
	doc["sub_text"] = "새벽"
	doc["timeline"]["enter"].merge({"effect": "center_stamp", "params": {}, "duration": 0.4}, true)
	doc["timeline"]["sub_enter"] = {"effect": "text_morph", "duration": 1.0, "order": "all", "stagger": 0.0,
		"delay": -30.0, "easing": "linear", "params": {"from_text": "깊은 밤", "readable_ratio": 0.3, "intensity": 1.0}}
	var combined := Evaluator.new(doc)
	var frame := combined.evaluate(0.1)
	t.ok(frame.any(func(state): return state.overlay and state.visible), "본문 중앙 오버레이와 보조 변이 동시 사용")
	t.ok(frame.any(func(state): return not state.sprite_key.is_empty() and state.visible), "동시 사용 중 보조 원문 실제 문자 존재")
	var baked := Baked.bake(doc, 10.0)
	for state in frame:
		if not state.visible:
			continue
		var slot: int = state.index
		if state.overlay:
			for glyph in baked["glyphs"]:
				if glyph["role"] == "overlay" and int(glyph["source"]) == state.index:
					slot = int(glyph["index"])
		t.eq(baked["glyphs"][slot]["char"], state.character, "오버레이/변이 베이크 슬롯 충돌 없음")
		t.near(baked["frames"][1][slot][5], state.alpha, 0.0006, "오버레이/변이 베이크 alpha 보존")


func _bake(t) -> void:
	var doc := _doc()
	var ev := Evaluator.new(doc)
	var plan := Plan.build(ev, Layout.resolve_fonts(doc), 1.0)
	var keys: Array = []
	for job in plan["jobs"]:
		for entry in job["entries"]:
			keys.append(entry["key"])
	for glyph in ev.text_morph["glyphs"]:
		t.ok(keys.has(glyph["sprite_key"]), "원문 실제 글자가 아틀라스 굽기에 포함")
	var baked := Baked.bake(doc, 10.0)
	t.eq(baked["format_version"], 1, "베이크 변환 프레임 포맷 v1 유지")
	t.eq(baked["glyphs"].size(), ev.layout["glyphs"].size() + ev.text_morph["glyphs"].size(), "원문 정적 글자 슬롯 추가")
	for frame in [0, 3, 6, 10]:
		for state in ev.evaluate(float(frame) / 10.0):
			if not state.visible:
				continue
			var glyph: Dictionary = baked["glyphs"][state.index]
			var values: Array = baked["frames"][frame][state.index]
			t.eq(glyph["char"], state.character, "베이크 실제 문자 일치")
			t.near(Vector2(glyph["base"][0] + values[0], glyph["base"][1] + values[1]), state.pos, 0.0015, "베이크 위치 일치")
			t.near(values[5], state.alpha, 0.0006, "베이크 원문·최종 문장 alpha 일치")
	doc["timeline"]["enter"]["params"]["from_text"] = "다른 원문"
	t.ne(plan["signature"], Plan.build(Evaluator.new(doc), Layout.resolve_fonts(doc), 1.0)["signature"], "원문 변경 시 아틀라스 다시 굽기")


func _commands(t) -> void:
	var model := Model.new()
	var log = OpLog.create(123, model.doc, "ko")
	for command in [
		{"op": "set_text", "text": "진실을 마주하다"},
		{"op": "select_effect", "segment": "enter", "effect": "text_morph"},
		{"op": "set", "path": "timeline.enter.params.from_text", "value": "잠들어 있던 기억"},
		{"op": "set", "path": "timeline.enter.params.readable_ratio", "value": 0.4},
		{"op": "undo"}, {"op": "redo"},
		{"op": "export", "kind": "doc_string"},
	]:
		log.append(command)
		t.ok(model.apply(command), "변이 명령 지원: %s (%s)" % [str(command), model.last_error])
	var replay := Replay.run_string(log.serialize())
	t.ok(replay["ok"] and replay["rejected"] == 0, "변이 명령 기록 리플레이")
	t.eq(replay["hash"], model.doc_hash(), "변이 리플레이 문서 해시 일치")
	var restored := Model.new()
	t.ok(restored.apply({"op": "load_doc", "string": model.last_export["text"]}), "변이 문서 한 줄 불러오기")
	t.eq(restored.doc_hash(), model.doc_hash(), "변이 원문과 읽기 비율 저장 보존")
