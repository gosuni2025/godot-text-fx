extends RefCounted
## 에디터 로직: 봇 결정론, 리플레이 재현, 스크립트 계획 실행.

const EditorBot := preload("res://app/logic/editor_bot.gd")
const Replay := preload("res://app/logic/replay.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const DocApi := preload("res://app/logic/doc_api.gd")

const STEPS := 150


func run(t) -> void:
	var a = EditorBot.new(1234)
	a.run_random(STEPS)
	var b = EditorBot.new(1234)
	b.run_random(STEPS)
	var c = EditorBot.new(98765)
	c.run_random(STEPS)
	var sa: String = a.log.serialize()
	t.eq(b.log.serialize(), sa, "same seed → same oplog string")
	t.eq(b.final_hash(), a.final_hash(), "same seed → same final hash")
	t.ne(c.log.serialize(), sa, "different seed → different oplog")
	t.ne(c.final_hash(), a.final_hash(), "different seed → different final hash")
	t.ok(DocApi.validate(a.model.doc).is_empty(), "bot final doc valid")
	t.ok(a.model.can_undo(), "bot made document edits")

	# 리플레이: 객체와 문자열 모두
	var r := Replay.run(a.log)
	t.eq(r.hash, a.final_hash(), "replay reproduces final hash")
	t.eq(r.export_hash, str(a.model.last_export.get("hash", "")), "replay reproduces last export")
	var rs := Replay.run_string(sa)
	t.ok(rs.ok, "replay from string ok")
	t.eq(rs.hash, a.final_hash(), "string replay reproduces final hash")
	t.eq(rs.model.locale, a.model.locale, "locale reproduced")
	t.eq(rs.model.time, a.model.time, "time reproduced")
	t.log("seed 1234: %d cmds, %d rejected, hash %s" % [r.results.size(), r.rejected, r.hash.substr(0, 12)])

	# 여러 시드에서 리플레이 일치
	for s in [1, 2, 3, 77, 2024]:
		var bot = EditorBot.new(s)
		bot.run_random(80)
		t.eq(Replay.run_string(bot.log.serialize()).hash, bot.final_hash(), "replay seed %d" % s)

	# 스크립트 계획
	var p = EditorBot.new(5)
	var res: Array = p.run_plan([
		{"op": "apply_template", "id": "cap_rise_market"},
		{"op": "set_text", "text": "소금시장 거리", "sub_text": "열째 종, 밤시장"},
		{"op": "set", "path": "layout.font_size", "value": 72},
		{"op": "list_add", "path": "timeline.hold.effects", "value": "float"},
		{"op": "set", "path": "style.fill.color", "value": "not a color"},
		{"op": "play", "from": 0},
		{"op": "seek", "t": 1.2},
		{"op": "export", "kind": "doc_json"},
	])
	t.eq(res, [true, true, true, true, false, true, true, true], "plan results")
	t.eq(p.model.doc.layout.font_size, 72.0, "plan applied")
	var rp := Replay.run(p.log)
	t.eq(rp.results, res, "replay reproduces per-command results")
	t.eq(rp.hash, p.final_hash(), "plan replay hash")
