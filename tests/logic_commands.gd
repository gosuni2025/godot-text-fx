extends RefCounted
## 에디터 로직: 명령 검증·실행 취소/다시·합치기·목록 명령·재생 상태·신호.

const EditorModel := preload("res://app/logic/editor_model.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")


func run(t) -> void:
	_validation(t)
	_undo_redo(t)
	_coalescing(t)
	_list_ops(t)
	_play_state(t)
	_signals(t)
	_load_doc(t)
	_baked(t)


func _validation(t) -> void:
	var m = EditorModel.new()
	var h0: String = m.doc_hash()
	var bad := [
		null, {}, {"op": 5}, {"op": "nope"},
		{"op": "set"}, {"op": "set", "path": "style.outline.size"},
		{"op": "set", "path": "style.outline.size", "value": "big"},
		{"op": "set", "path": "style.outline.size", "value": -1},
		{"op": "set", "path": "style.outline.size", "value": NAN},
		{"op": "set", "path": "style.fill.color", "value": "red"},
		{"op": "set", "path": "style.fill.color", "value": "#12345"},
		{"op": "set", "path": "layout.align", "value": "middle"},
		{"op": "set", "path": "layout.nope", "value": 1},
		{"op": "set", "path": "decorations.0.color", "value": "#FFFFFF"},
		{"op": "set", "path": "format_version", "value": 2},
		{"op": "set", "path": "layout", "value": 3},
		{"op": "set", "path": "timeline.enter.effect", "value": "explode"},
		{"op": "set", "path": "timeline.enter.easing", "value": "wobbly"},
		{"op": "set", "path": "layout.anchor", "value": [0.5]},
		{"op": "set", "path": "style.fill.gradient.stops", "value": [[2.0, "#FFFFFF"]]},
		{"op": "set_text"}, {"op": "set_text", "text": 3},
		{"op": "set_mode", "mode": "movie"},
		{"op": "apply_template", "id": "no_such"},
		{"op": "seek", "t": -1}, {"op": "seek", "t": "1"}, {"op": "play", "from": 99999},
		{"op": "set_locale", "locale": "fr"},
		{"op": "export", "kind": "png"},
		{"op": "undo"}, {"op": "redo"},
		{"op": "unset", "path": "layout.font_size"},
		{"op": "list_add", "path": "layout", "value": "x"},
		{"op": "list_add", "path": "decorations", "value": "sparkle"},
		{"op": "list_remove", "path": "decorations", "index": 0},
		{"op": "load_doc", "doc": {"format": "other"}},
		{"op": "load_doc", "doc": {"format_version": 9}},
		{"op": "load_doc", "string": "garbage"},
	]
	for c in bad:
		t.ok(not m.apply(c), "should reject %s" % str(c))
	t.eq(m.doc_hash(), h0, "rejected commands leave doc unchanged")
	t.ok(not m.can_undo(), "no history after rejected commands")
	t.ok(m.last_error != "", "last_error set")
	# 유효한 명령
	t.ok(m.apply({"op": "set", "path": "style.outline.size", "value": 9}), "set number")
	t.eq(m.get_value("style.outline.size"), 9.0, "set value stored as float")
	t.ok(m.apply({"op": "set", "path": "timeline.enter.params.dir", "value": "left"}), "set open param")
	t.ok(m.apply({"op": "unset", "path": "timeline.enter.params.dir"}), "unset open param")
	t.ok(m.apply({"op": "set", "path": "sub_style", "value": {"fill": {"color": "#FF0000FF"}}}), "set nullable dict")
	t.eq(m.get_value("sub_style.outline.size"), 9.0, "nullable sub_style inherits main style")
	t.ok(m.apply({"op": "set", "path": "sub_style", "value": null}), "reset nullable")


func _undo_redo(t) -> void:
	var m = EditorModel.new()
	var h0: String = m.doc_hash()
	m.apply({"op": "set_text", "text": "등불이 꺼졌다"})
	m.apply({"op": "set_mode", "mode": "caption"})
	var h2: String = m.doc_hash()
	t.ok(m.apply({"op": "undo"}), "undo 1")
	t.eq(m.doc.mode, "message", "mode reverted")
	t.ok(m.apply({"op": "undo"}), "undo 2")
	t.eq(m.doc_hash(), h0, "back to start")
	t.ok(not m.apply({"op": "undo"}), "undo empty")
	t.ok(m.apply({"op": "redo"}) and m.apply({"op": "redo"}), "redo twice")
	t.eq(m.doc_hash(), h2, "redo restores")
	m.apply({"op": "undo"})
	m.apply({"op": "set", "path": "layout.font_size", "value": 50})
	t.ok(not m.can_redo(), "new edit clears redo")
	# 재생·탐색은 기록에 들어가지 않는다
	m.apply({"op": "seek", "t": 1.5})
	m.apply({"op": "undo"})
	t.eq(m.get_value("layout.font_size"), 96.0, "seek not in history")
	t.eq(m.time, 1.5, "undo keeps time")


func _coalescing(t) -> void:
	var m = EditorModel.new()
	for v in [10, 11, 12, 13]:
		m.apply({"op": "set", "path": "style.outline.size", "value": v})
	m.apply({"op": "seek", "t": 0.5})  # 비문서 명령은 합치기를 끊지 않는다
	m.apply({"op": "set", "path": "style.outline.size", "value": 14})
	m.apply({"op": "set", "path": "style.glow.size", "value": 20})
	m.apply({"op": "set", "path": "style.outline.size", "value": 15})
	m.apply({"op": "undo"})
	t.eq(m.get_value("style.outline.size"), 14.0, "undo after path switch")
	m.apply({"op": "undo"})
	t.eq(m.get_value("style.glow.size"), 16.0, "glow undone")
	m.apply({"op": "undo"})
	t.eq(m.get_value("style.outline.size"), 6.0, "coalesced drag undone in one step")
	t.ok(not m.can_undo(), "history fully consumed")
	# merge:false 는 따로 기록
	m.apply({"op": "set", "path": "layout.font_size", "value": 80})
	m.apply({"op": "set", "path": "layout.font_size", "value": 70, "merge": false})
	m.apply({"op": "undo"})
	t.eq(m.get_value("layout.font_size"), 80.0, "merge:false makes own entry")
	# 텍스트 입력도 합친다
	m.apply({"op": "set_text", "text": "등"})
	m.apply({"op": "set_text", "text": "등불"})
	m.apply({"op": "undo"})
	t.eq(m.doc.text, "", "typing coalesced")


func _list_ops(t) -> void:
	var m = EditorModel.new()
	t.ok(m.apply({"op": "list_add", "path": "decorations", "value": "underline"}), "add by type")
	t.ok(m.apply({"op": "list_add", "path": "decorations", "value": {"type": "frame", "color": "#FF0000FF"}}), "add dict")
	t.ok(m.apply({"op": "list_add", "path": "decorations", "value": "band", "index": 0}), "insert at 0")
	t.eq(m.doc.decorations.size(), 3, "3 decorations")
	t.eq(m.doc.decorations[0].type, "band", "inserted first")
	t.eq(m.doc.decorations[2].thickness, 4.0, "defaults filled")
	t.ok(m.apply({"op": "set", "path": "decorations.2.color", "value": "#00FF00"}), "set nested list field")
	t.ok(m.apply({"op": "list_move", "path": "decorations", "from": 2, "to": 0}), "move")
	t.eq(m.doc.decorations[0].type, "frame", "moved to front")
	t.ok(m.apply({"op": "list_remove", "path": "decorations", "index": 1}), "remove")
	t.eq(m.doc.decorations.size(), 2, "2 left")
	t.ok(not m.apply({"op": "list_remove", "path": "decorations", "index": 5}), "remove out of range")
	t.ok(not m.apply({"op": "list_move", "path": "decorations", "from": 0, "to": 9}), "move out of range")
	var fx := "timeline.hold.effects"
	t.ok(m.apply({"op": "list_add", "path": fx, "value": "wave"}), "add hold effect")
	t.ok(m.apply({"op": "list_add", "path": fx, "value": {"type": "shake", "amplitude": 4}}), "add shake")
	t.eq(m.get_value(fx + ".1.frequency"), 18.0, "shake defaults")
	t.ok(m.apply({"op": "set", "path": fx + ".1.amplitude", "value": 3.5}), "set effect param")
	t.ok(not m.apply({"op": "set", "path": fx + ".1.amplitude", "value": 999}), "param out of range")
	t.ok(m.apply({"op": "set", "path": fx + ".0.type", "value": "pulse"}), "change effect type")
	t.eq(m.get_value(fx + ".0.period"), 1.2, "new type defaults filled")
	var stops := "style.fill.gradient.stops"
	t.ok(m.apply({"op": "list_add", "path": stops, "value": [0.5, "#FF8800"], "index": 1}), "add stop")
	t.ok(not m.apply({"op": "list_add", "path": stops, "value": [1.5, "#FF8800"]}), "bad stop")
	t.ok(m.apply({"op": "list_remove", "path": stops, "index": 1}), "remove stop")
	t.ok(not m.apply({"op": "list_remove", "path": stops, "index": 0}), "keep 2 stops")
	for i in 12:
		m.apply({"op": "list_add", "path": "decorations", "value": "overline"})
	t.eq(m.doc.decorations.size(), 12, "decorations capped")
	var before: int = m.doc.decorations.size()
	m.apply({"op": "undo"})
	t.eq(m.doc.decorations.size(), before - 1, "list op undo")


func _play_state(t) -> void:
	var m = EditorModel.new()
	t.ok(m.apply({"op": "play", "from": 0.25}), "play from")
	t.ok(m.playing and m.time == 0.25, "playing at from")
	m.advance(0.5)
	t.near(m.time, 0.75, 0.0001, "advance moves time")
	t.ok(m.apply({"op": "pause"}), "pause")
	m.advance(1.0)
	t.near(m.time, 0.75, 0.0001, "paused does not advance")
	t.ok(m.apply({"op": "seek", "t": 2}), "seek")
	t.eq(m.time, 2.0, "time set")
	t.ok(m.apply({"op": "set_locale", "locale": "ja"}) and m.locale == "ja", "locale set")
	t.ok(m.apply({"op": "select", "path": "style.outline"}) and m.selection == "style.outline", "select")
	t.ok(m.apply({"op": "export", "kind": "doc_json"}), "export doc_json")
	t.eq(JsonUtil.parse(m.last_export.text).get("format"), "text_fx", "doc json content")
	t.ok(m.apply({"op": "export", "kind": "doc_string"}), "export doc_string")
	t.ok(str(m.last_export.text).begins_with("TFX1:"), "doc string prefix")


func _signals(t) -> void:
	var m = EditorModel.new()
	var got: Array = []
	m.changed.connect(func(paths): got.append(paths))
	m.apply({"op": "set", "path": "style.glow.enabled", "value": true})
	t.ok(got.size() == 1 and "style.glow.enabled" in got[0], "set emits path")
	m.apply({"op": "set", "path": "style.glow.enabled", "value": true})
	t.eq(got.size(), 1, "no-op set emits nothing")
	m.apply({"op": "seek", "t": 1})
	t.ok("$time" in got[-1], "seek emits $time")
	m.apply({"op": "undo"})
	t.ok("*" in got[-1], "undo emits *")
	m.apply({"op": "set", "path": "style.glow.enabled", "value": "yes"})
	t.eq(got.size(), 3, "rejected command emits nothing")


func _load_doc(t) -> void:
	var a = EditorModel.new()
	a.apply({"op": "apply_template", "id": "msg_battle_engage"})
	a.apply({"op": "export", "kind": "doc_string"})
	var b = EditorModel.new()
	t.ok(b.apply({"op": "load_doc", "string": a.last_export.text}), "load from string")
	t.eq(b.doc_hash(), a.doc_hash(), "string round trip same hash")
	var c = EditorModel.new()
	t.ok(c.apply({"op": "load_doc", "doc": JsonUtil.parse(JSON.stringify(a.doc))}), "load parsed json")
	t.eq(c.doc_hash(), a.doc_hash(), "json round trip same hash")
	var d = EditorModel.new()
	t.ok(d.apply({"op": "load_doc", "doc": {"text": "x", "extra_field": {"k": 1}}}), "partial doc")
	t.eq(d.doc.extra_field, {"k": 1.0}, "unknown field preserved")
	t.eq(d.doc.layout.font_size, 96.0, "missing filled")
	t.ok(not d.apply({"op": "load_doc", "doc": {"layout": {"font_size": "huge"}}}), "invalid doc rejected")


## 베이크 내보내기: 런타임 fx_baked_export.gd가 있으면 실제 결과를, 없으면 명확한 실패를 확인한다.
func _baked(t) -> void:
	var m = EditorModel.new()
	m.apply({"op": "apply_template", "id": "msg_check_success"})
	var ok: bool = m.apply({"op": "export", "kind": "baked_json", "fps": 12})
	if not ResourceLoader.exists(EditorModel.BAKED_EXPORT_PATH):
		t.ok(not ok and m.last_error.find("unavailable") >= 0, "baked export reports missing runtime")
		t.ok(m.last_export.ok == false, "failed export recorded")
		return
	t.ok(ok, "baked export ok (%s)" % m.last_error)
	if not ok:
		return
	var data: Dictionary = m.last_export.data
	t.eq(data.get("format"), "text_fx_baked", "baked format")
	t.ok(data.get("frames", []).size() > 0, "baked has frames")
	var m2 = EditorModel.new()
	m2.apply({"op": "apply_template", "id": "msg_check_success"})
	m2.apply({"op": "export", "kind": "baked_json", "fps": 12})
	t.eq(m2.last_export.hash, m.last_export.hash, "baked export deterministic")
	t.ok(not m.apply({"op": "export", "kind": "baked_json", "fps": 0}), "bad fps rejected")
