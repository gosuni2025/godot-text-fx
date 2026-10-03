extends RefCounted
## examples/ 게임 예시 검사(헤드리스: 굽기 없이 타임라인·신호만).
## - examples/fx/*.json 이 TextFxDoc 검사를 통과하고 TextFxPlayer로 끝까지 재생된다.
## - set_text, loop_hold + finish() → finished.
## - 생성기(examples/tools/example_specs.gd)가 같은 JSON을 다시 만든다(결정론).

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const Specs := preload("res://examples/tools/example_specs.gd")

const DOCS := ["battle_cutin.json", "check_result.json", "trailer_intro.json", "location_caption.json", "damage_number.json"]
const STEP := 1.0 / 30.0


func run(t) -> void:
	_check_generator(t)
	var p: Player = Player.new()
	p.autoplay = false
	p.size = Vector2(640, 360)
	t.tree.root.add_child(p)
	var log: Array = []
	p.entered.connect(func() -> void: log.append("entered"))
	p.page_changed.connect(func(pg: int) -> void: log.append("page%d" % pg))
	p.finished.connect(func() -> void: log.append("finished"))
	for file in DOCS:
		_check_doc(t, p, log, file)
	_check_set_text(t, p, log)
	_check_loop_hold(t, p, log)
	_check_baked(t)
	p.queue_free()
	await _check_demo_scene(t)


func _read(file: String) -> String:
	return FileAccess.get_file_as_string(Specs.OUT_DIR.path_join(file))


func _check_generator(t) -> void:
	var a: Dictionary = Specs.build_all()
	var b: Dictionary = Specs.build_all()
	t.eq(a.errors.size(), 0, "generator errors %s" % str(a.errors))
	t.eq(a.files.size(), Specs.SPECS.size(), "generator file count")
	for file in a.files:
		t.eq(a.files[file], b.files.get(file), "generator deterministic %s" % file)
		t.ok(a.files[file] == _read(file), "examples/fx/%s matches generator (re-run gen_examples.gd)" % file)


func _check_doc(t, p: Player, log: Array, file: String) -> void:
	var raw := Doc.parse_json(_read(file))
	t.eq(raw.get("format"), "text_fx", "%s format" % file)
	t.eq(int(raw.get("format_version", 0)), Doc.FORMAT_VERSION, "%s uses current document version" % file)
	t.eq(Doc.validate(Doc.normalize(raw)).size(), 0, "%s validates" % file)
	t.ok(p.load_file(Specs.OUT_DIR.path_join(file)), "%s load_file" % file)
	var loop := str(p.get_document()["timeline"]["loop"])
	log.clear()
	p.play()
	var dur := p.get_duration()
	t.ok(dur > 0.0, "%s duration" % file)
	_run_for(p, dur + 0.5)
	if loop == "loop_hold":
		t.ok(p.is_playing() and not log.has("finished"), "%s loop_hold keeps holding" % file)
		p.finish()
		_run_for(p, 3.0)
	t.ok(log.has("entered"), "%s entered" % file)
	t.eq(log.count("finished"), 1, "%s finished once" % file)
	t.ok(not p.is_playing(), "%s stopped" % file)


func _check_set_text(t, p: Player, log: Array) -> void:
	p.load_file(Specs.OUT_DIR.path_join("location_caption.json"))
	var before := p.get_duration()
	p.set_text("가라앉은 기록관", "다섯째 종, 썰물")
	var d := p.get_document()
	t.eq(d["text"], "가라앉은 기록관", "set_text main")
	t.eq(d["sub_text"], "다섯째 종, 썰물", "set_text sub")
	t.ok(p.get_duration() > before, "longer place name -> longer enter")
	var subs := 0
	for g in p.get_evaluator().evaluate(0.0):
		if g.role == "sub":
			subs += 1
	t.eq(subs, "다섯째 종, 썰물".replace(" ", "").length(), "sub glyphs laid out")
	# 재생 중 set_text는 처음부터 다시 재생한다(피해 숫자 갱신).
	p.load_file(Specs.OUT_DIR.path_join("damage_number.json"))
	log.clear()
	p.play()
	_run_for(p, 0.2)
	p.set_text("9999")
	t.ok(p.is_playing(), "set_text while playing restarts")
	t.near(p.get_time(), 0.0, 0.0001, "restart from 0")
	t.eq(p.get_document()["text"], "9999", "damage text")
	_run_for(p, p.get_duration() + 0.5)
	t.eq(log.count("finished"), 1, "damage finished once")


func _check_loop_hold(t, p: Player, log: Array) -> void:
	p.load_file(Specs.OUT_DIR.path_join("check_result.json"))
	t.eq(p.get_document()["timeline"]["loop"], "loop_hold", "check_result is loop_hold")
	p.set_text("판정 실패", "주사위 4 / 목표 12")
	log.clear()
	p.play()
	_run_for(p, 10.0)
	t.eq(log, ["page0", "entered"], "holds without finishing")
	p.finish()
	_run_for(p, 2.0)
	t.eq(log, ["page0", "entered", "finished"], "finish() -> finished")
	t.ok(not p.is_playing(), "stopped after finish")


func _check_baked(t) -> void:
	var data = JSON.parse_string(_read("battle_cutin.baked.json"))
	t.ok(data is Dictionary and data.get("format") == "text_fx_baked", "baked format")
	if not (data is Dictionary):
		return
	var frames: Array = data.get("frames", [])
	var glyphs: Array = data.get("glyphs", [])
	t.eq(frames.size(), maxi(1, int(round(float(data.duration) * float(data.fps)))), "baked frame count")
	t.ok(not frames.is_empty() and frames[0].size() == glyphs.size(), "baked frame width = glyph count")


## 예시 씬: 물리 키 입력으로 연출을 고르고 set_text·finish가 반영되는지(헤드리스, 굽기 없음).
func _check_demo_scene(t) -> void:
	var scene: PackedScene = load("res://examples/game_demo.tscn")
	var demo: Node = scene.instantiate()
	t.tree.root.add_child(demo)
	await t.tree.process_frame
	var banner: Player = demo.get_node("Banner")
	var dmg: Player = demo.get_node("Damage")
	demo._unhandled_input(_key(KEY_4))
	var place := str(banner.get_document()["text"])
	t.ok(place in ["서리목 등대", "소금시장 거리", "가라앉은 기록관"], "key 4 -> caption set_text (%s)" % place)
	t.ok(banner.is_playing(), "caption playing")
	demo._unhandled_input(_key(KEY_5))
	t.ok(str(dmg.get_document()["text"]).is_valid_int(), "key 5 -> damage number set_text")
	demo._unhandled_input(_key(KEY_2))
	t.eq(banner.get_document()["timeline"]["loop"], "loop_hold", "key 2 -> loop_hold doc")
	var done := [false]
	banner.finished.connect(func() -> void: done[0] = true)
	_run_for(banner, 5.0)
	t.ok(not done[0], "loop_hold holds")
	demo._unhandled_input(_key(KEY_F))
	_run_for(banner, 2.0)
	t.ok(done[0], "key F -> finish() -> finished")
	var log_text: String = demo.get_node("Hud/Log").text
	t.ok(log_text.contains("finished"), "signal log label updated")
	demo.queue_free()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _run_for(p: Player, seconds: float) -> void:
	for i in int(ceil(seconds / STEP)):
		p.advance(STEP)
