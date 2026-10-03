class_name TextFxCenterStamp
extends RefCounted
## center_stamp 등장 시퀀스(DESIGN §2.2):
##   1) 본문 글자를 하나씩 화면 중앙(블록 기준점)에 크게 표시(hold_each초씩, 오버레이 글자)
##   2) pause초 쉼
##   3) 전체 문장이 slam_scale배에서 1배로 내려찍힘(enter.duration, enter.easing). 보조 문구도 함께.
## 오버레이 글자는 overlay=true, overlay_scale=big_scale인 별도 상태로 결과 끝에 덧붙는다.

const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hash := preload("res://addons/text_fx/core/fx_hash.gd")


## states: 전체 글자 상태(제자리 기본값). 현재 페이지 글자만 바꾸고, 오버레이 상태 배열을 돌려준다.
static func apply(states: Array, layout: Dictionary, doc: Dictionary, page_info: Dictionary, page: int, te: float) -> Array:
	var overlays: Array = []
	var enter: Dictionary = doc["timeline"]["enter"]
	var params: Dictionary = enter["params"]
	var hold_each := maxf(0.0001, float(params.get("hold_each", 0.28)))
	var big := maxf(0.1, float(params.get("big_scale", 3.0)))
	var seq: float = page_info["stamp_seq"]
	var pg: Dictionary = layout["pages"][page]
	var first: int = pg["glyph_first"]
	var count: int = pg["glyph_count"]
	var L: Dictionary = doc["layout"]
	var canvas: Vector2 = layout["canvas"]
	var viewport_scale := maxf(0.0, float(params.get("viewport_scale", 0.0)))
	var center := canvas * Vector2(float(L["anchor"][0]), float(L["anchor"][1])) + Vector2(float(L["offset"][0]), float(L["offset"][1]))
	if viewport_scale > 0.0:
		center = canvas * 0.5
	if te < seq:
		for i in range(first, first + count):
			(states[i] as GlyphState).alpha = 0.0
		var time := te - float(page_info.get("text_start", 0.0))
		for slot in page_info.get("stamp_slots", []):
			var start := float(slot["start"])
			if time >= start and time < start + float(slot["duration"]):
				var u := (time - start) / hold_each
				var src: GlyphState = states[int(slot["index"])]
				var o := src.copy() as GlyphState
				o.overlay = true
				o.overlay_scale = big
				if viewport_scale > 0.0:
					o.overlay_scale = minf(canvas.x, canvas.y) * viewport_scale / maxf(1.0, float(layout["glyphs"][src.index]["font_size"]))
				o.pos = center
				o.rotation = 0.0
				o.alpha = 1.0
				var s_in := lerpf(1.35, 1.0, Easing.apply("cubic_out", clampf(u / 0.25, 0.0, 1.0)))
				o.scale = Vector2.ONE * s_in
				o.alpha = clampf(u / 0.12, 0.0, 1.0) * clampf((1.0 - u) / 0.18, 0.0, 1.0)
				if not bool(params.get("solo_animated", true)):
					o.scale = Vector2.ONE
					o.alpha = 1.0
				o.visible = o.alpha > 0.0005
				overlays.append(o)
				break
		return overlays
	var motion := block_motion(doc, page_info, page, te)
	var s: float = motion["scale"]
	var c: Vector2 = (pg["rect"] as Rect2).get_center()
	for i in range(first, first + count):
		var st: GlyphState = states[i]
		st.pos = c + (st.pos - c) * s + motion["offset"]
		st.scale *= s
		st.alpha *= float(motion["alpha"])
		st.brightness = maxf(st.brightness, float(motion["brightness"]))
	return overlays


## 장식도 같은 내려찍기/충격을 재사용한다. 개별 글자의 잔상·이동으로부터 역산하지 않는다.
static func block_motion(doc: Dictionary, page_info: Dictionary, page: int, te: float) -> Dictionary:
	var enter: Dictionary = doc["timeline"]["enter"]
	var params: Dictionary = enter["params"]
	var seq := float(page_info["stamp_seq"])
	if te < seq:
		return {"scale": 1.0, "offset": Vector2.ZERO, "alpha": 0.0, "brightness": 0.0}
	var dur := maxf(0.0, float(enter["duration"]))
	var p := 1.0 if dur <= 0.0 else clampf((te - seq) / dur, 0.0, 1.0)
	var e := Easing.apply(Enter.resolve_easing("center_stamp", str(enter["easing"])), p)
	var scale := lerpf(float(params.get("slam_scale", 2.2)), 1.0, e)
	var impact_duration := maxf(0.0, float(params.get("impact_duration", 0.0)))
	var impact := 0.0 if impact_duration <= 0.0 else pow(clampf(1.0 - (te - seq) / impact_duration, 0.0, 1.0), 2.0)
	var brightness := clampf(float(params.get("impact_brightness", 0.0)) * impact, 0.0, 1.0)
	var step := int(floor((te - seq) * 60.0))
	var shake := Vector2(Hash.signed(int(doc["seed"]), page, 8201 + step), Hash.signed(int(doc["seed"]), page, 9201 + step)) \
		* maxf(0.0, float(params.get("impact_shake", 0.0))) * impact
	return {"scale": scale, "offset": shake, "alpha": clampf(p * 3.0, 0.0, 1.0), "brightness": brightness}
