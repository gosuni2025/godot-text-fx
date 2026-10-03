class_name TextFxCenterStamp
extends RefCounted
## center_stamp 등장 시퀀스(DESIGN §2.2):
##   1) 본문 글자를 하나씩 화면 중앙(블록 기준점)에 크게 표시(hold_each초씩, 오버레이 글자)
##   2) pause초 쉼
##   3) 전체 문장이 slam_scale배에서 1배로 내려찍힘(enter.duration, enter.easing). 보조 문구도 함께.
## 오버레이 글자는 overlay=true, overlay_scale=big_scale인 별도 상태로 결과 끝에 덧붙는다.

const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")


## states: 전체 글자 상태(제자리 기본값). 현재 페이지 글자만 바꾸고, 오버레이 상태 배열을 돌려준다.
static func apply(states: Array, layout: Dictionary, doc: Dictionary, page_info: Dictionary, page: int, te: float) -> Array:
	var overlays: Array = []
	var enter: Dictionary = doc["timeline"]["enter"]
	var params: Dictionary = enter["params"]
	var hold_each := maxf(0.0001, float(params.get("hold_each", 0.28)))
	var big := maxf(0.1, float(params.get("big_scale", 3.0)))
	var slam := float(params.get("slam_scale", 2.2))
	var seq: float = page_info["stamp_seq"]
	var n: int = page_info["stamp_count"]
	var pg: Dictionary = layout["pages"][page]
	var first: int = pg["glyph_first"]
	var count: int = pg["glyph_count"]
	var L: Dictionary = doc["layout"]
	var canvas: Vector2 = layout["canvas"]
	var center := canvas * Vector2(float(L["anchor"][0]), float(L["anchor"][1])) + Vector2(float(L["offset"][0]), float(L["offset"][1]))
	if te < seq:
		for i in range(first, first + count):
			(states[i] as GlyphState).alpha = 0.0
		var slot := int(floor(te / hold_each))
		if slot < n:
			var u := (te - float(slot) * hold_each) / hold_each
			var main_i := -1
			var seen := 0
			for i in range(first, first + count):
				if layout["glyphs"][i]["role"] == "main":
					if seen == slot:
						main_i = i
						break
					seen += 1
			if main_i >= 0:
				var src: GlyphState = states[main_i]
				var o := src.copy() as GlyphState
				o.overlay = true
				o.overlay_scale = big
				o.pos = center
				o.rotation = 0.0
				o.alpha = 1.0
				var s_in := lerpf(1.35, 1.0, Easing.apply("cubic_out", clampf(u / 0.25, 0.0, 1.0)))
				o.scale = Vector2.ONE * s_in
				o.alpha = clampf(u / 0.12, 0.0, 1.0) * clampf((1.0 - u) / 0.18, 0.0, 1.0)
				o.visible = o.alpha > 0.0005
				overlays.append(o)
		return overlays
	var dur := maxf(0.0, float(enter["duration"]))
	var p := 1.0 if dur <= 0.0 else clampf((te - seq) / dur, 0.0, 1.0)
	var e := Easing.apply(str(enter["easing"]), p)
	var s := lerpf(slam, 1.0, e)
	var a := clampf(p * 3.0, 0.0, 1.0)
	var c: Vector2 = (pg["rect"] as Rect2).get_center()
	for i in range(first, first + count):
		var st: GlyphState = states[i]
		st.pos = c + (st.pos - c) * s
		st.scale *= s
		st.alpha *= a
	return overlays
