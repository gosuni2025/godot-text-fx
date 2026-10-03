extends RefCounted
## 템플릿 재적용의 재생 상태·실행 취소·직렬화 리플레이 회귀 검사.

const Bot := preload("res://app/logic/editor_bot.gd")
const Replay := preload("res://app/logic/replay.gd")


func run(t) -> void:
	var bot = Bot.new(7)
	bot.run_plan([
		{"op": "apply_template", "id": "msg_narrator_secret"},
		{"op": "play", "from": 8.63},
		{"op": "apply_template", "id": "msg_battle_engage"},
	])
	t.eq(bot.model.time, 0.0, "template switch restarts the clock")
	t.ok(bot.model.playing, "template switch keeps playback running")
	var replay := Replay.run_string(bot.log.serialize())
	t.eq(replay.model.time, 0.0, "serialized replay also restarts at zero")
	t.ok(replay.model.playing, "serialized replay preserves playing")
	t.eq(replay.hash, bot.final_hash(), "serialized replay preserves the document")

	bot.send({"op": "seek", "t": 2.0})
	bot.send({"op": "apply_template", "id": "msg_battle_engage"})
	t.eq(bot.model.time, 0.0, "reapplying the same template also restarts")
	bot.send({"op": "undo"})
	t.eq(bot.model.template_id, "msg_narrator_secret", "reapplying adds no redundant document undo")
	bot.send({"op": "redo"})
	t.eq(bot.model.template_id, "msg_battle_engage", "redo still restores the switched template")

	bot.send({"op": "pause"})
	bot.send({"op": "seek", "t": 1.5})
	bot.send({"op": "set_text", "text": "내 문장"})
	bot.send({"op": "apply_template", "id": "msg_narrator_secret", "keep_text": true})
	t.eq(bot.model.time, 0.0, "paused template switch returns to the beginning")
	t.ok(not bot.model.playing, "paused template switch stays paused")
	t.eq(bot.model.doc.text, "내 문장", "restart respects keep_text")

	bot.send({"op": "play", "from": 1.25})
	t.ok(not bot.send({"op": "apply_template", "id": "missing_template"}), "invalid template is rejected")
	t.eq(bot.model.time, 1.25, "rejected template preserves time")
	t.ok(bot.model.playing, "rejected template preserves playing")
	bot.send({"op": "set", "path": "layout.font_size", "value": 90})
	t.eq(bot.model.time, 1.25, "ordinary document edits preserve time")
	bot.model.advance(10.0, 2.0)
	t.eq(bot.model.time, 2.0, "large frame delta clamps exactly to the end")
	bot.model.advance(0.5)
	t.eq(bot.model.time, 2.5, "unbounded repeat playback keeps advancing")
