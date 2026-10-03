class_name TextFxBakedExport
extends RefCounted
## 프레임 샘플링 베이크 JSON(DESIGN §5.2). 엔진 비의존: 다른 엔진에서 글자 배치·변환만 재생할 때 쓴다.
## { format:"text_fx_baked", format_version:1, fps, canvas:{width,height}, duration, loop, seed,
##   markers:{ hold_start, hold_end },               # loop_hold 재생용(마지막 페이지 유지 구간)
##   glyphs:[{ index, char, role, font_size, base:[x,y], rot }],
##   frames:[[[dx, dy, sx, sy, rot, alpha], ...], ...] }
## - frames[f][g]는 t = f / fps에서 glyphs[g]의 상태. 위치 = base + (dx, dy), 회전 = glyph.rot + frame rot(라디안).
## - center_stamp 오버레이 글자는 role "overlay"인 추가 글자(base = 중앙, font_size = 크게 그린 크기)로 들어간다.
## - 보이지 않는 글자는 [0, 0, 1, 1, 0, 0]. 값은 소수 셋째 자리 반올림.
## - loop_hold의 duration은 유지 구간을 한 번만 넣은 구조상 길이다.

const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const FORMAT := "text_fx_baked"
const FORMAT_VERSION := 1
const HIDDEN := [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]


static func bake(doc: Dictionary, fps: float = 30.0, fonts: Dictionary = {}) -> Dictionary:
	fps = clampf(fps, 1.0, 240.0)
	var ev := Evaluator.new(doc, {}, fonts)
	var layout := ev.layout
	var tl := ev.timeline
	var duration := tl.get_duration()
	var glyph_list: Array = []
	for g in layout["glyphs"]:
		var p: Vector2 = g["pos"]
		glyph_list.append({"index": g["index"], "char": g["char"], "role": g["role"], "font_size": g["font_size"],
			"base": [_r(p.x), _r(p.y)], "rot": _r(float(g["base_rotation"]))})
	var n := glyph_list.size()
	var overlay_slot := {}
	if tl.stamp_enabled:
		var params: Dictionary = ev.doc["timeline"]["enter"]["params"]
		var big := float(params.get("big_scale", 3.0))
		var L: Dictionary = ev.doc["layout"]
		var canvas: Vector2 = layout["canvas"]
		var center := canvas * Vector2(float(L["anchor"][0]), float(L["anchor"][1])) + Vector2(float(L["offset"][0]), float(L["offset"][1]))
		for g in layout["glyphs"]:
			if g["role"] == "main":
				overlay_slot[int(g["index"])] = glyph_list.size()
				glyph_list.append({"index": glyph_list.size(), "char": g["char"], "role": "overlay", "source": g["index"],
					"font_size": int(round(float(g["font_size"]) * big)), "base": [_r(center.x), _r(center.y)], "rot": 0.0})
	var count := maxi(1, int(round(duration * fps)))
	var frames: Array = []
	for f in count:
		var t := float(f) / fps
		var row: Array = []
		row.resize(glyph_list.size())
		for i in glyph_list.size():
			row[i] = HIDDEN.duplicate()
		for st: GlyphState in ev.evaluate(t):
			var slot := st.index
			if st.overlay:
				if not overlay_slot.has(st.index):
					continue
				slot = overlay_slot[st.index]
			if not st.visible:
				continue
			var gd: Dictionary = glyph_list[slot]
			var bx: float = gd["base"][0]
			var by: float = gd["base"][1]
			row[slot] = [_r(st.pos.x - bx), _r(st.pos.y - by), _r(st.scale.x), _r(st.scale.y),
				_r(st.rotation - float(gd["rot"])), _r(st.alpha)]
		frames.append(row)
	var last: Dictionary = tl.pages[tl.page_count - 1]
	return {
		"format": FORMAT, "format_version": FORMAT_VERSION, "fps": fps,
		"canvas": {"width": ev.doc["canvas"]["width"], "height": ev.doc["canvas"]["height"]},
		"duration": _r(duration), "loop": ev.doc["timeline"]["loop"], "seed": ev.seed,
		"markers": {"hold_start": _r(float(last["enter_end"])), "hold_end": _r(float(last["hold_end"]))},
		"glyphs": glyph_list, "frames": frames, "glyph_count": n,
	}


static func _r(v: float) -> float:
	return snappedf(v, 0.001)
