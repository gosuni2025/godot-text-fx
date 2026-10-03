extends RefCounted
## 실제 편집기 재생 바: 템플릿 전환, 유한 종료, 전체/유지 반복 표시.

const U := preload("res://tests/_ui_util.gd")


func run(t) -> void:
	var ed: Control = await U.open(t.tree)
	# 실제 프레임 간격 대신 명시적 delta로 종료 경계를 재현한다.
	ed.set_process(false)
	_template_switch(t, ed)
	_once(t, ed)
	_select_after_completion(t, ed)
	_repeats(t, ed)
	await U.close(t.tree, ed)


func _template_switch(t, ed) -> void:
	var pv: Node = ed.preview
	ed.send({"op": "apply_template", "id": "msg_narrator_secret"})
	ed._process(0.0)
	ed.send({"op": "play", "from": 8.63})
	pv.finish()
	t.ok(is_finite(pv.end_time()), "finish schedules the old template's exit")
	ed.panel("mode").card("msg_battle_engage").pressed.emit()
	t.eq(ed.model.time, 0.0, "template card resets time before the next frame")
	t.ok(ed.model.playing, "template card preserves playing")
	ed._process(0.1)
	t.near(ed.model.time, 0.1, 0.00001, "new template advances from zero")
	t.near(pv.player.get_time(), 0.1, 0.00001, "preview player follows restarted clock")
	t.eq(pv.player.get_document().name, ed.model.doc.name, "preview renders the new template")

	ed.send({"op": "apply_template", "id": "msg_narrator_secret"})
	ed._process(0.0)
	ed.send({"op": "seek", "t": 8.63})
	pv.finish()
	ed.panel("mode").apply_template("msg_narrator_secret")
	ed._process(0.1)
	t.near(ed.model.time, 0.1, 0.00001, "same template also restarts")
	t.ok(not is_finite(pv.end_time()), "same template clears the previous finish request")
	t.ok(ed.model.playing, "same template continues playing")
	ed.send({"op": "pause"})
	ed.panel("mode").apply_template("msg_battle_engage")
	ed._process(0.1)
	t.near(ed.model.time, 0.1, 0.00001, "paused template restarts from the beginning")
	t.ok(ed.model.playing, "template selection resumes playback")


func _select_after_completion(t, ed) -> void:
	ed.send({"op": "play", "from": 0.0})
	for id in ["msg_battle_victory", "msg_battle_victory"]:
		ed._process(100.0)
		t.ok(ed.preview.is_ended() and not ed.model.playing, "previous preview completed")
		ed.panel("mode").card(id).pressed.emit()
		t.ok(ed.model.playing and ed.model.time == 0.0, "card starts playback after completion, including reselect")
		t.eq(ed.preview.get_node("%PlayPause").tooltip_text, "Pause (Space)", "transport reflects resumed playback immediately")
		ed._process(0.1)
		t.near(ed.preview.player.get_time(), 0.1, 0.00001, "selected preview advances after completion")


func _once(t, ed) -> void:
	var pv: Node = ed.preview
	for exit_on in [true, false]:
		ed.send({"op": "set", "path": "timeline.loop", "value": "once"})
		ed.send({"op": "set", "path": "timeline.exit.enabled", "value": exit_on})
		ed._process(0.0)
		var end: float = pv.end_time()
		ed.send({"op": "play", "from": end - 0.01})
		ed._process(0.5)
		t.eq(ed.model.time, end, "once stops exactly at its end (exit %s)" % exit_on)
		t.ok(not ed.model.playing, "once pauses at its end")
		t.eq(pv.get_node("%Time").text, "%.2f / %.2f s" % [end, end], "once label never overruns")
		pv.toggle_play()
		t.ok(ed.model.playing and ed.model.time == 0.0, "play after completion restarts")
		ed.send({"op": "pause"})


func _repeats(t, ed) -> void:
	var pv: Node = ed.preview
	ed.send({"op": "set", "path": "timeline.loop", "value": "loop_all"})
	ed._process(0.0)
	var length: float = pv.scrub_length()
	ed.send({"op": "play", "from": length * 3.0 + 0.25})
	ed._process(0.25)
	t.ok(ed.model.playing, "whole loop keeps playing past one cycle")
	t.eq(pv.get_node("%Time").text, "%.2f / %.2f s" % [0.5, length], "whole loop label shows cycle position")
	t.near(pv.scrubber.value, 0.5, 0.001, "whole loop scrubber matches label")

	ed.send({"op": "apply_template", "id": "msg_narrator_secret"})
	ed._process(0.0)
	ed.send({"op": "play", "from": 8.63})
	ed._process(0.1)
	t.ok(ed.model.playing, "hold loop stays active until finish")
	t.eq(pv.get_node("%Time").text, "8.73 / ∞ s", "hold loop shows an unlimited duration")
	pv.finish()
	var end: float = pv.end_time()
	t.ok(is_finite(end), "finish gives hold loop a finite endpoint")
	ed._process(10.0)
	t.eq(ed.model.time, end, "finish clamps exactly to its endpoint")
	t.ok(not ed.model.playing, "finish stops playback")
	t.eq(pv.get_node("%Time").text, "%.2f / %.2f s" % [end, end], "finish label uses the finite endpoint")

	# 스크롤의 loop_hold는 런타임과 동일하게 전체 반복으로 표시한다.
	ed.send({"op": "apply_template", "id": "trl_scroll_log"})
	ed.send({"op": "set", "path": "timeline.loop", "value": "loop_hold"})
	ed._process(0.0)
	length = pv.scrub_length()
	ed.send({"op": "play", "from": length * 2.0 + 0.5})
	t.eq(pv.get_node("%Time").text, "%.2f / %.2f s" % [0.5, length], "scroll hold label follows whole-loop timing")
	ed.send({"op": "pause"})
