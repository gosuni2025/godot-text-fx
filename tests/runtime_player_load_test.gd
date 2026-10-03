extends RefCounted
## 문서 정체성/버전 검사는 정규화보다 먼저 수행하고, 로딩 실패는 진행 중인 재생에 영향을 주지 않는다.

const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")


func run(t) -> void:
	var p := Player.new()
	p.autoplay = false
	t.tree.root.add_child(p)
	t.ok(p.set_document({"text": "기존 문서", "timeline": {"loop": "loop_hold"}}), "partial dictionary remains supported")
	p.play(0.4)
	p.finish()
	var events: Array = []
	p.started.connect(func(): events.append("started"))
	p.finished.connect(func(): events.append("finished"))
	p.page_changed.connect(func(_page): events.append("page"))
	var snapshot := _snapshot(p)
	var invalid := [
		{"format": "other", "text": "교체되면 안 됨"},
		{"format": "text_fx_baked", "format_version": 1, "glyphs": [], "frames": []},
		{"format": "text_fx", "format_version": 999, "text": "미래 문서"},
		{"format_version": 0}, {"format_version": -1}, {"format_version": 1.5},
		{"format_version": "2"}, {"format_version": true}, {"text": 7},
	]
	for doc: Dictionary in invalid:
		t.ok(not p.set_document(doc), "set_document rejects invalid source %s" % str(doc))
		t.eq(_snapshot(p), snapshot, "failed set_document preserves document and playback")
	t.eq(events, [], "failed dictionary loads emit no playback events")
	var path := "user://runtime_player_load_%d.json" % Time.get_ticks_usec()
	for doc: Dictionary in invalid.slice(0, 3):
		_write(path, JSON.stringify(doc))
		t.ok(not p.load_file(path), "load_file rejects invalid identity/version")
		t.eq(_snapshot(p), snapshot, "failed file load preserves document and playback")
	for source in ["{invalid", "[]", "null"]:
		_write(path, source)
		t.ok(not p.load_file(path), "load_file rejects malformed or non-object JSON")
		t.eq(_snapshot(p), snapshot, "failed parse preserves playback")
	DirAccess.remove_absolute(path)
	t.ok(not p.load_file(path), "missing file reports failure")
	t.eq(_snapshot(p), snapshot, "missing file preserves playback")
	t.eq(events, [], "failed file loads emit no playback events")
	var finish_at: float = snapshot["end_time"]
	p.advance(finish_at + 0.1 - p.get_time())
	t.ok(not p.is_playing() and events == ["finished"], "pending finish still completes after rejected loads")
	var old := {"format": "text_fx", "format_version": 1, "text": "이전 포맷", "layout": {"letter_spacing": 0.2},
		"timeline": {"enter": {"effect": "pop", "easing": "elastic_out"}}}
	t.ok(p.set_document(old), "set_document accepts v1")
	t.eq(p.get_document()["format_version"], Doc.FORMAT_VERSION, "v1 document migrates")
	t.near(p.get_document()["layout"]["sub"]["letter_spacing"], 0.2, 0.0001, "v1 sub spacing is retained")
	t.eq(p.get_document()["timeline"]["enter"]["easing"], "elastic_out", "v1 easing is retained")
	t.eq(old["format_version"], 1, "caller dictionary remains unchanged")
	_write(path, JSON.stringify(old))
	t.ok(p.load_file(path), "file loader accepts v1")
	t.eq(p.get_document()["text"], "이전 포맷", "valid file replaces document")
	_write(path, "{}")
	t.ok(p.load_file(path), "empty object follows partial document contract")
	t.eq(p.get_document(), Doc.normalize({}), "empty object loads defaults")
	DirAccess.remove_absolute(path)
	t.ok(p.set_document({}), "empty dictionary remains a valid defaults reset")
	p.stop()
	p.queue_free()


func _snapshot(p: Player) -> Dictionary:
	return {"document": p.get_document(), "evaluator": p.get_evaluator(), "time": p.get_time(),
		"playing": p.is_playing(), "duration": p.get_duration(), "end_time": p.get_evaluator().get_end_time(float(p.get("_finish_at")))}


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
