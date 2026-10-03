extends RefCounted
## TextFxPlayer 재생 상태·신호(헤드리스: 굽기 없이 타임라인·신호만 검사).

const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")


func run(t) -> void:
	var p: Player = Player.new()
	p.autoplay = false
	p.size = Vector2(640, 360)
	t.tree.root.add_child(p)
	var log: Array = []
	p.started.connect(func() -> void: log.append("started"))
	p.entered.connect(func() -> void: log.append("entered"))
	p.page_changed.connect(func(pg: int) -> void: log.append("page%d" % pg))
	p.exit_started.connect(func() -> void: log.append("exit"))
	p.finished.connect(func() -> void: log.append("finished"))
	p.looped.connect(func() -> void: log.append("looped"))

	var d := Doc.defaults()
	d["mode"] = "trailer"
	d["text"] = "하나\n\n둘"
	d["timeline"]["loop"] = "loop_hold"
	d["timeline"]["hold"]["duration"] = 0.5
	p.set_document(d)
	t.ok(not p.is_playing(), "autoplay off")
	p.play()
	t.ok(p.is_playing(), "playing")
	for i in 200:
		p.advance(1.0 / 30.0)
	t.eq(log, ["started", "page0", "entered", "page1", "entered"], "signals through pages into loop_hold")
	t.ok(p.is_playing(), "still playing in loop_hold")
	p.finish()
	for i in 60:
		p.advance(1.0 / 30.0)
	t.eq(log.slice(5), ["exit", "finished"], "finish -> exit -> finished")
	t.ok(not p.is_playing(), "stopped after finish")

	# set_text 후 재생, once 모드 finished
	log.clear()
	d["timeline"]["loop"] = "once"
	d["mode"] = "message"
	p.set_document(d)
	p.set_text("새 문장", "보조")
	t.eq(p.get_document()["text"], "새 문장", "set_text applied")
	p.play()
	var dur := p.get_duration()
	t.ok(dur > 0.0, "duration")
	p.advance(dur + 0.1)
	t.eq(log, ["started", "page0", "entered", "exit", "finished"], "once signals with large step")
	# loop_all looped 신호
	log.clear()
	d["timeline"]["loop"] = "loop_all"
	p.set_document(d)
	p.play()
	var total := p.get_duration()
	for i in int(total * 2.5 * 30.0):
		p.advance(1.0 / 30.0)
	t.eq(log.count("looped"), 2, "looped twice")
	t.ok(p.is_playing(), "loop_all keeps playing")
	p.seek(0.3)
	t.near(p.get_time(), 0.3, 0.0001, "seek")
	p.stop()
	t.ok(not p.is_playing(), "stop")
	p.queue_free()
