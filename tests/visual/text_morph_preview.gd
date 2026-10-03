extends SceneTree
## 실제 GPU: 원문→변이→최종 문장을 캡처하고 최종 픽셀을 일반 텍스트와 비교 후 종료한다.
## godot --audio-driver Dummy --path . --script res://tests/visual/text_morph_preview.gd -- --capture=/tmp/text-fx-morph

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const Helper := preload("res://tests/test_helper.gd")

var player: Player
var capture := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("문장 변이 픽셀 검사는 실제 GPU 창이 필요합니다.")
		quit(1)
		return
	var test := Helper.new()
	test.test_name = "text_morph_gpu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture = arg.substr(10)
	if capture != "":
		DirAccess.make_dir_recursive_absolute(capture)
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("#161927")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	player = Player.new()
	player.autoplay = false
	player.size = Vector2(1280, 720)
	root.add_child(player)
	var doc := Doc.defaults()
	doc["text"] = "진실은 기억 속에"
	doc["style"]["fill"]["color"] = "#DBCBFFFF"
	doc["style"]["outline"]["size"] = 3.0
	doc["style"]["glow"] = {"enabled": true, "size": 12.0, "color": "#A575FFFF", "strength": 0.7}
	doc["timeline"]["enter"].merge({"effect": "text_morph", "order": "all", "stagger": 0.0, "duration": 2.0,
		"easing": "linear", "params": {"from_text": "거짓된 기억\n잿빛 항구", "readable_ratio": 0.3, "intensity": 1.0}}, true)
	test.ok(await _set_doc(doc), "실제 원문/최종문 아틀라스 굽기 완료")
	var source := await _frame(0.2, "source")
	var repeat := await _frame(0.3, "source_repeat")
	test.eq(source.get_data(), repeat.get_data(), "읽기 구간의 원문 픽셀 유지")
	var middle := await _frame(1.15, "morph")
	test.ne(source.get_data(), middle.get_data(), "변이 중 실제 글자 픽셀 변화")
	await _frame(1.6, "arriving")
	var final := await _frame(2.1, "final")
	test.ne(source.get_data(), final.get_data(), "다른 길이의 실제 최종 문장으로 교체")
	doc["timeline"]["enter"].merge({"effect": "fade", "duration": 0.0, "params": {}}, true)
	test.ok(await _set_doc(doc), "비교용 최종 문장 굽기")
	var plain := await _frame(0.1, "plain_target")
	test.eq(final.get_data(), plain.get_data(), "변이 완료 픽셀이 일반 최종 문장과 정확히 동일")
	doc["sub_text"] = "변하지 않는 보조 문구"
	doc["timeline"]["enter"].merge({"effect": "text_morph", "duration": 2.0,
		"params": {"from_text": "거짓된 기억\n잿빛 항구", "readable_ratio": 0.3, "intensity": 1.0}}, true)
	test.ok(await _set_doc(doc), "긴 원문과 보조 문구 동시 굽기")
	await _frame(0.5, "with_sub_source")
	await _frame(1.3, "with_sub_morph")
	var with_sub := await _frame(2.1, "with_sub_final")
	doc["timeline"]["enter"].merge({"effect": "fade", "duration": 0.0, "params": {}}, true)
	test.ok(await _set_doc(doc), "보조 문구 최종 비교 굽기")
	var plain_sub := await _frame(0.1, "with_sub_plain")
	test.eq(with_sub.get_data(), plain_sub.get_data(), "보조 문구 이동도 완료 후 일반 배치와 정확히 동일")
	doc["sub_text"] = ""
	doc["text"] = "AB 기억"
	doc["layout"]["direction"] = "vertical"
	doc["timeline"]["enter"].merge({"effect": "text_morph", "duration": 2.0,
		"params": {"from_text": "A의 기록\nB 기억", "readable_ratio": 0.3, "intensity": 1.0}}, true)
	test.ok(await _set_doc(doc), "세로쓰기 원문 굽기")
	await _frame(0.2, "vertical_source")
	await _frame(1.15, "vertical_morph")
	await _frame(2.1, "vertical_final")
	doc["layout"]["direction"] = "horizontal"
	doc["text"] = "긴 문장\n두 번째 줄\n세 번째 줄"
	doc["sub_text"] = "새벽"
	doc["timeline"]["enter"]["params"]["from_text"] = "짧은 글"
	doc["timeline"]["sub_enter"] = {"effect": "text_morph", "duration": 1.0, "order": "all", "stagger": 0.0,
		"delay": 0.0, "easing": "linear", "params": {"from_text": "깊은 밤\n감춰진 별", "readable_ratio": 0.3, "intensity": 1.0}}
	test.ok(await _set_doc(doc), "본문 완료 후 보조 원문 배치 굽기")
	await _frame(2.1, "sequential_sub_source")
	await _frame(3.1, "sequential_final")
	for failure in test.failures:
		printerr("FAIL ", failure)
	print("Morph GPU: %d checks, %d failed" % [test.checks, test.failures.size()])
	player.queue_free()
	await process_frame
	quit(0 if test.passed() else 1)


func _set_doc(doc: Dictionary) -> bool:
	if not player.set_document(doc):
		return false
	for _frame_index in 600:
		if player.is_baked():
			return true
		await process_frame
	return false


func _frame(time: float, label: String) -> Image:
	player.seek(time)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if capture != "":
		image.save_png("%s/%s.png" % [capture, label])
	return image
