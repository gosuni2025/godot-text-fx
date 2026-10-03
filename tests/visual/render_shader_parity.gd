extends SceneTree
## 실제 GPU 창 테스트: godot --audio-driver Dummy --path . --script res://tests/visual/render_shader_parity.gd -- --capture=/tmp/text-fx-gpu
## 작은 원시 도형으로 블러 에너지·atlas 혼입·마스크·전역 조각·밝기·독립 glow를 검증하고 종료한다.

const State := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Renderer := preload("res://addons/text_fx/render/fx_glyph_renderer.gd")
const Blur := preload("res://addons/text_fx/render/fx_sprite_blur.gd")
const Helper := preload("res://tests/test_helper.gd")

var viewport: SubViewport
var canvas: Control
var renderer := Renderer.new()
var state := State.new()
var sprite: Dictionary
var front := true
var capture := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := Helper.new()
	t.test_name = "render_shader_parity"
	if DisplayServer.get_name() == "headless":
		push_error("이 검사는 실제 GPU 창이 필요합니다.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture = arg.substr(10)
	if capture != "":
		DirAccess.make_dir_recursive_absolute(capture)
	root.size = Vector2i(512, 512)
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	canvas = Control.new()
	canvas.size = Vector2(256, 256)
	viewport.add_child(canvas)
	canvas.draw.connect(_draw_sample)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.size = Vector2(512, 512)
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(display)
	_make_sprite()
	state.visible = true
	state.pos = Vector2(128, 128)
	var sharp := await _frame("sharp")
	var sharp_stats := _stats(sharp)
	t.ok(sharp_stats["mass"] > 60.0, "기본 셰이더가 원시 도형을 표시")
	state.ghost = 12.0
	var blurred := await _frame("blur")
	var blur_stats := _stats(blurred)
	t.ok(blur_stats["mass"] > sharp_stats["mass"] * 0.90 and blur_stats["mass"] < sharp_stats["mass"] * 1.10, "블러가 alpha 에너지를 보존")
	t.ok(blur_stats["peak"] < sharp_stats["peak"] * 0.65, "블러가 선명한 본체·4복제 대신 peak를 낮춤")
	t.ok(blur_stats["variance"] > sharp_stats["variance"] * 3.0, "블러가 양 축으로 연속 확산")
	t.ok(blur_stats["red"] < blur_stats["green"] * 0.02, "다른 atlas 셀의 빨강이 섞이지 않음")
	t.near(blur_stats["x"], sharp_stats["x"], 0.6, "대칭 블러 중심 보존")
	var repeat := await _frame("blur_repeat")
	t.eq(repeat.get_data(), blurred.get_data(), "같은 상태를 다시 그리면 동일 픽셀")
	state.ghost_dir = Vector2.DOWN
	state.rotation = PI * 0.5
	var directional := _stats(await _frame("rise"))
	t.ok(directional["var_y"] > directional["var_x"] * 3.0, "회전한 세로쓰기 글자도 rise 운동 축만 흐림")
	state.rotation = 0.0
	state.ghost = 0.0
	state.brightness = 1.0
	state.tint = Color(0.3, 0.6, 0.2, 1.0)
	var white := await _frame("flash")
	var pixel := white.get_pixel(128, 128)
	t.near(pixel.r, pixel.a, 0.02, "플래시 premult 빨강")
	t.near(pixel.b, pixel.a, 0.02, "플래시 premult 파랑")
	state.brightness = 0.0
	state.tint = Color.WHITE
	state.clip_enabled = true
	state.clip_rect = Rect2(0, 0, 128, 256)
	var left := await _frame("wipe")
	t.ok(left.get_pixel(125, 128).a > 0.9 and left.get_pixel(130, 128).a < 0.01, "캔버스 좌표 wipe 경계")
	state.clip_invert = true
	var right := await _frame("wipe_inverse")
	t.ok(right.get_pixel(125, 128).a < 0.01 and right.get_pixel(130, 128).a > 0.9, "중앙 지우기용 inverse mask")
	state.clip_enabled = false
	state.slices_global = true
	state.slice_origin_y = 0.0
	state.slice_height = 256.0
	state.slices = PackedFloat32Array([20.0])
	var shifted := await _frame("global_glitch")
	t.ok(shifted.get_pixel(148, 128).a > 0.9 and shifted.get_pixel(128, 128).a < 0.01, "전체 블록 조각이 world x만큼 이동")
	state.slices_global = false
	state.slices.clear()
	front = false
	state.glow_multiplier = 0.0
	var dark := _stats(await _frame("glow_off"))
	state.glow_multiplier = 1.0
	var glow := _stats(await _frame("glow_on"))
	t.ok(dark["mass"] < 0.01 and glow["mass"] > 60.0, "glow를 뒤 텍스처와 독립적으로 조절")
	front = true
	var fill_with_glow := await _frame("fill_with_glow")
	state.glow_multiplier = 0.0
	var fill_without_glow := await _frame("fill_without_glow")
	t.eq(fill_with_glow.get_data(), fill_without_glow.get_data(), "glow pulse가 앞 채우기를 깜빡이지 않음")
	for failure in t.failures:
		printerr("FAIL ", failure)
	print("GPU render: %d checks, %d failed" % [t.checks, t.failures.size()])
	renderer.clear()
	quit(0 if t.passed() else 1)


func _make_sprite() -> void:
	var atlas := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	atlas.fill_rect(Rect2i(12, 12, 8, 8), Color(0, 1, 0.5, 1))
	atlas.fill_rect(Rect2i(32, 0, 32, 32), Color.RED)
	var blank := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0, 0, 0, 0))
	sprite = {"texture_front": ImageTexture.create_from_image(atlas), "texture": ImageTexture.create_from_image(blank),
		"texture_glow": ImageTexture.create_from_image(atlas), "region": Rect2(0, 0, 32, 32),
		"center": Vector2(16, 16), "inner": Rect2(-4, -4, 8, 8), "scale": 1.0}
	sprite["blur"] = Blur.isolate(sprite, {"texture_front": atlas, "texture": blank, "texture_glow": atlas}, 16.0)


func _draw_sample() -> void:
	renderer.begin(canvas.get_canvas_item())
	if not sprite.is_empty():
		renderer.draw_glyph(state, sprite, Vector2.ZERO, 1.0, front)
	renderer.end()


func _frame(label: String) -> Image:
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if capture != "":
		image.save_png("%s/%s.png" % [capture, label])
	return image


func _stats(image: Image) -> Dictionary:
	var mass := 0.0
	var peak := 0.0
	var red := 0.0
	var green := 0.0
	var x_sum := 0.0
	var y_sum := 0.0
	var x2 := 0.0
	var y2 := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			mass += pixel.a
			peak = maxf(peak, pixel.a)
			red += pixel.r
			green += pixel.g
			x_sum += float(x) * pixel.a
			y_sum += float(y) * pixel.a
			x2 += float(x * x) * pixel.a
			y2 += float(y * y) * pixel.a
	var cx := x_sum / maxf(0.0001, mass)
	var cy := y_sum / maxf(0.0001, mass)
	var vx := x2 / maxf(0.0001, mass) - cx * cx
	var vy := y2 / maxf(0.0001, mass) - cy * cy
	return {"mass": mass, "peak": peak, "red": red, "green": green, "x": cx, "var_x": vx, "var_y": vy, "variance": vx + vy}
