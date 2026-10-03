extends RefCounted
## 공개 효과 감사에서 찾은 서로 다른 동작들을 수치와 결정론으로 검증한다.

const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const State := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")


func _state(index: int = 0) -> State:
	var st := State.new()
	st.index = index
	st.pos = Vector2(150.0 + index * 60.0, 180.0)
	return st


func _context(id: String, time: float = 0.5) -> Dictionary:
	return {"params": Enter.default_params(id), "local": time, "duration": 1.0, "em": 60.0,
		"block_em": 60.0, "seed": 678, "is_exit": false, "vertical": false,
		"block_center": Vector2(200, 180), "block_rect": Rect2(100, 150, 200, 60), "canvas": Vector2(400, 360)}


func run(t) -> void:
	# auto는 효과에 어울리는 곡선을 고르되 기존 명시 곡선을 바꾸지 않는다.
	t.eq(Enter.resolve_easing("pop", "auto"), "back_out", "auto pop overshoot")
	t.eq(Enter.resolve_easing("bounce", "auto"), "bounce_out", "auto falling bounce")
	t.eq(Enter.resolve_easing("shutter", "auto", true), "expo_in", "auto fold exit")
	t.eq(Enter.resolve_easing("pop", "linear"), "linear", "explicit easing preserved")

	# 같은 축척이라도 전체 효과는 글자 사이의 거리를 바꿔야 한다.
	var a := _state(0)
	var b := _state(1)
	var ctx := _context("block_zoom")
	Enter.apply("block_zoom", a, 0.5, {}, ctx)
	Enter.apply("block_zoom", b, 0.5, {}, ctx)
	t.ok(b.pos.x - a.pos.x > 60.0, "whole zoom changes spacing")
	t.near(a.scale, b.scale, 0.0001, "whole zoom shares scale")
	t.ok(a.ghost > 0.0, "whole zoom blurs")
	t.near(a.ghost, b.ghost, 0.0001, "whole zoom shares blur")
	var local_zoom := _state()
	Enter.apply("zoom", local_zoom, 0.5, {}, _context("zoom"))
	t.near(local_zoom.pos, _state().pos, 0.0001, "glyph zoom preserves center")

	# 글자 flip은 한 축만, shutter는 좌표까지 함께 접는다.
	var flip := _state()
	Enter.apply("flip", flip, 0.5, {}, _context("flip"))
	t.near(flip.scale.x, 1.0, 0.0001, "horizontal text flip leaves x axis")
	t.ok(flip.scale.y < 1.0, "horizontal text flip opens y axis")
	var vctx := _context("flip")
	vctx["vertical"] = true
	var vflip := _state()
	Enter.apply("flip", vflip, 0.5, {}, vctx)
	t.ok(vflip.scale.x < 1.0 and vflip.scale.y == 1.0, "vertical text flip changes x axis")
	var fold := _state()
	var fctx := _context("shutter")
	fctx["params"]["axis"] = "horizontal"
	Enter.apply("shutter", fold, 0.5, {}, fctx)
	t.ok(fold.pos.x > _state().pos.x and fold.scale.x < 1.0, "shutter folds position toward center")

	# 섬광과 발광은 본체 불투명도에만 묶인 효과가 아니다.
	var flash := _state()
	Enter.apply("flash", flash, 0.5, {}, _context("flash"))
	t.ok(flash.brightness > 0.0 and flash.glow_multiplier > 1.0, "flash emits whiteness and glow")
	var glow0 := _state()
	var glow1 := _state()
	Hold.apply(Hold.default_params("glow_pulse"), glow0, 0.0, {}, {})
	Hold.apply(Hold.default_params("glow_pulse"), glow1, 0.9, {}, {})
	t.ok(glow0.glow_multiplier > glow1.glow_multiplier, "glow pulse varies independent layer")
	t.eq(glow0.alpha, glow1.alpha, "glow pulse leaves text opacity")

	# 착지 이후 충격은 같은 프레임의 모든 글자에게 일관되게 적용된다.
	var sctx := _context("slam", 0.43)
	var slam_a := _state(0)
	var slam_b := _state(1)
	Enter.apply("slam", slam_a, 0.57, {}, sctx)
	Enter.apply("slam", slam_b, 0.57, {}, sctx)
	t.ok(slam_a.brightness > 0.0, "slam landing has impact light")
	t.near(slam_a.brightness, slam_b.brightness, 0.0001, "slam shares light")
	t.near(slam_a.scale, slam_b.scale, 0.0001, "slam shares settling transform")
	var settled := _state()
	Enter.apply("slam", settled, 0.0, {}, _context("slam", 1.0))
	t.near(settled.pos, _state().pos, 0.0001, "slam returns to base placement")
	t.near(settled.brightness, 0.0, 0.0001, "slam light settles")

	# 중앙 와이프 퇴장은 가운데 구간을 지우는 역마스크다.
	for exiting in [false, true]:
		var wctx := _context("block_wipe")
		wctx["is_exit"] = exiting
		wctx["params"]["dir"] = "center"
		var wipe := _state()
		Enter.apply("block_wipe", wipe, 0.5, {}, wctx)
		t.ok(wipe.clip_enabled, "whole wipe mask enabled")
		t.eq(wipe.clip_invert, exiting, "center exit cuts hole")
		t.near(wipe.clip_rect.get_center().x, 200.0, 0.001, "center wipe stays centered")
		t.ok(wipe.clip_feather > 0.0, "whole wipe has soft edge")

	# 불규칙 명멸은 seed/time에서 재현되며 등장/퇴장 양 끝은 안정적이다.
	var alphas := {}
	for i in 24:
		var flctx := _context("flicker", i / 24.0)
		var fa := _state()
		var fb := _state()
		Enter.apply("flicker", fa, 0.5, {}, flctx)
		Enter.apply("flicker", fb, 0.5, {}, flctx)
		t.eq(fa.to_dict(), fb.to_dict(), "flicker deterministic")
		alphas[fa.alpha] = true
	t.ok(alphas.size() > 1, "flicker toggles across time")
	var off := _state()
	Enter.apply("flicker", off, 1.0, {}, _context("flicker"))
	t.eq(off.alpha, 0.0, "flicker fully hidden endpoint")

	# 전체 글리치는 같은 캔버스 띠를 쓰며 지정한 두 색을 보존한다.
	var gctx := _context("block_glitch")
	gctx["params"]["color_a"] = "#00FF00FF"
	gctx["params"]["color_b"] = "#0000FFFF"
	var ga := _state(0)
	var gb := _state(1)
	Enter.apply("block_glitch", ga, 0.7, {}, gctx)
	Enter.apply("block_glitch", gb, 0.7, {}, gctx)
	t.ok(ga.slices_global and gb.slices_global, "glitch slices use canvas coordinates")
	t.eq(ga.slices, gb.slices, "all glyphs share glitch offsets")
	t.near(ga.slice_origin_y, gb.slice_origin_y, 0.0001, "all glyphs share slice origin")
	t.near(ga.split_color_a, Color.GREEN, 0.0001, "glitch first custom color")
	t.near(ga.split_color_b, Color.BLUE, 0.0001, "glitch second custom color")

	# 심박은 한 주기에 분리된 두 번의 확대, 전체 흔들림은 거리 보존.
	var hb := Hold.default_params("heartbeat")
	var heights: Array[float] = []
	for phase in [0.0, 0.12, 0.25, 0.36, 0.7]:
		var hs := _state()
		Hold.apply(hb, hs, phase * float(hb["period"]), {}, {"block_center": Vector2(200, 180)})
		heights.append(hs.scale.x)
	t.ok(heights[1] > heights[0] and heights[1] > heights[2], "heartbeat first beat")
	t.ok(heights[3] > heights[2] and heights[3] > heights[4], "heartbeat second beat")
	var sa := _state(0)
	var sb := _state(1)
	var shake := Hold.default_params("block_shake")
	Hold.apply(shake, sa, 0.18, {}, {"seed": 45})
	Hold.apply(shake, sb, 0.18, {}, {"seed": 45})
	t.near(sb.pos - sa.pos, Vector2(60, 0), 0.0001, "whole shake preserves relative positions")

	# 실제 문서 정규화와 평가를 거쳐 새 effect/hold 값이 유실되지 않는다.
	var doc := Doc.defaults()
	doc["text"] = "가A"
	doc["timeline"]["enter"]["effect"] = "block_zoom"
	doc["timeline"]["enter"]["easing"] = "auto"
	doc["timeline"]["hold"]["effects"] = [Hold.default_params("heartbeat"), Hold.default_params("glow_pulse")]
	var restored := Doc.normalize(Doc.parse_json(Doc.to_json(doc, "")))
	t.eq(restored["timeline"]["enter"]["effect"], "block_zoom", "new effect round trip")
	t.eq(restored["timeline"]["hold"]["effects"].size(), 2, "new holds round trip")
	var ev := Evaluator.new(restored)
	var states := ev.evaluate(0.2)
	t.ok(states.size() == 2 and states[0].ghost > 0.0, "new effect evaluated through document")
	t.ok(Enter.max_blur_em(restored["timeline"]["enter"]) > 0.0, "renderer can reserve blur extent")
