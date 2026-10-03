extends SceneTree
## 실제 GPU 창에서 10종을 캡처·검사하고 종료한다.
## godot --audio-driver Dummy --path . --script res://tests/visual/cinematic_preview.gd -- --capture=/tmp/text-fx-cinematic [--sample=id,...] [--film]

const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const Samples := preload("res://tests/visual/cinematic_samples.gd")
const Helper := preload("res://tests/test_helper.gd")

var player: Player
var view: SubViewport
var title: Label
var capture_dir := ""
var film := false
var only := "all"
var frame_number := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Cinematic GPU validation needs a real window.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.substr(10)
		elif arg.begins_with("--sample="):
			only = arg.substr(9)
		elif arg == "--film":
			film = true
	if capture_dir != "":
		DirAccess.make_dir_recursive_absolute(capture_dir)
	_setup()
	var t := Helper.new()
	t.test_name = "cinematic_gpu"
	var names := Samples.IDS if only == "all" else Array(only.split(","))
	for id: String in names:
		var doc := Samples.sample(id)
		t.ok(player.set_document(doc), id + " loads")
		if not await _ready_to_capture():
			t.fail(id + " bake timed out")
			continue
		var ev = player.get_evaluator()
		var pg: Dictionary = ev.timeline.pages[0]
		var enter_end: float = pg.enter_end
		var exit_start: float = pg.hold_end
		var exit_len: float = pg.exit_len
		var full := await _frame(id, "hold", enter_end + 0.2)
		t.ok(_mass(full) > 100.0, id + " readable hold has visible glyphs")
		var mid := await _frame(id, "enter_50", enter_end * 0.5)
		t.ne(mid.get_data(), full.get_data(), id + " entrance changes rendered pixels")
		t.ok(_mass(mid) > 5.0, id + " middle of entrance is visible")
		await _frame(id, "enter_15", enter_end * 0.15)
		await _frame(id, "enter_75", enter_end * 0.75)
		var repeat := await _frame(id, "repeat", enter_end * 0.5, false)
		t.eq(repeat.get_data(), mid.get_data(), id + " rewind reproduces identical GPU pixels")
		await _frame(id, "exit_30", exit_start + exit_len * 0.3)
		await _frame(id, "exit_65", exit_start + exit_len * 0.65)
		var end := await _frame(id, "end", player.get_duration() + 0.05, false)
		t.ok(_mass(end) < 0.01, id + " endpoint leaves no particles or glyphs")
		if film:
			for frame in int(ceil(player.get_duration() * 20.0)):
				await _frame(id, "film", float(frame) / 20.0, false)
				var screen := root.get_texture().get_image()
				screen.save_png(capture_dir.path_join("frame_%05d.png" % frame_number))
				frame_number += 1
		# 세로쓰기도 같은 효과를 적용해 회전/아틀라스 좌표 결합을 확인한다.
		t.ok(player.set_document(Samples.sample(id, true)), id + " vertical loads")
		if await _ready_to_capture():
			var v := await _frame(id, "vertical", float(player.get_evaluator().timeline.pages[0].enter_end) * 0.65)
			t.ok(_mass(v) > 5.0, id + " vertical entrance is visible")
		else:
			t.fail(id + " vertical bake timed out")
		print("captured ", id)
	for failure in t.failures:
		printerr("FAIL ", failure)
	print("Cinematic GPU: %d checks, %d failed" % [t.checks, t.failures.size()])
	player.queue_free()
	await process_frame
	quit(0 if t.passed() else 1)


func _setup() -> void:
	root.size = Vector2i(1280, 760)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101722")
	backdrop.size = Vector2(1280, 760)
	root.add_child(backdrop)
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	player = Player.new()
	player.autoplay = false
	player.size = Vector2(1280, 720)
	view.add_child(player)
	var screen := TextureRect.new()
	screen.texture = view.get_texture()
	screen.size = Vector2(1280, 720)
	screen.position.y = 40
	root.add_child(screen)
	title = Label.new()
	title.position = Vector2(24, 7)
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)


func _ready_to_capture() -> bool:
	for i in 600:
		if player.is_baked():
			return true
		await process_frame
	return false


func _frame(id: String, label: String, time: float, save := true) -> Image:
	player.seek(time)
	title.text = "%s  /  %s  /  %.2f s" % [id, label, time]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	if save and capture_dir != "":
		root.get_texture().get_image().save_png(capture_dir.path_join(id + "_" + label + ".png"))
	return image


func _mass(image: Image) -> float:
	var mass := 0.0
	# 알파 질량 검사는 2px 간격으로 충분하다. 배경·제목은 별도 viewport라 포함되지 않는다.
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			mass += image.get_pixel(x, y).a
	return mass
