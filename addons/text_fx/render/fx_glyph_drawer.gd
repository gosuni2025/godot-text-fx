class_name TextFxGlyphDrawer
extends RefCounted
## TextFxPlayer의 그리기 도우미. 모든 색은 프리멀티플라이드로 넘긴다(플레이어 재질이 PREMULT_ALPHA).
## 스프라이트 = { texture(뒤), texture_front(앞), region, center, inner, scale } (fx_glyph_baker.gd 결과).
## 플레이어는 글자들의 뒤 레이어(front=false)를 모두 그린 뒤 앞 레이어(front=true)를 그린다.
## 로컬 좌표 단위는 스프라이트 픽셀이며, 캔버스 px 값(잔상·조각·색수차)은 sprite.scale을 곱해 바꾼다.

const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")


static func premul(c: Color, a: float) -> Color:
	var aa := clampf(c.a * a, 0.0, 1.0)
	return Color(c.r * aa, c.g * aa, c.b * aa, aa)


static func draw_glyph(ci: CanvasItem, st: GlyphState, spr: Dictionary, origin: Vector2, fit: float, front: bool) -> void:
	var tex: Texture2D = spr["texture_front"] if front else spr["texture"]
	if tex == null:
		return
	var sscale: float = spr["scale"]
	var factor := fit * (st.overlay_scale if st.overlay else 1.0) / sscale
	ci.draw_set_transform(origin + st.pos * fit, st.rotation, st.scale * factor)
	var region: Rect2 = spr["region"]
	var center: Vector2 = spr["center"]
	var local := Rect2(region.position - center, region.size)
	var inner: Rect2 = spr["inner"]
	# 잔상 흐림
	if st.ghost > 0.05:
		var g := st.ghost * sscale
		var offs: Array = []
		if st.ghost_dir == Vector2.ZERO:
			offs = [Vector2(-g, 0), Vector2(g, 0), Vector2(0, -g), Vector2(0, g)]
		else:
			offs = [st.ghost_dir * g, st.ghost_dir * g * 0.5, -st.ghost_dir * g * 0.5, -st.ghost_dir * g]
		var gc := premul(st.tint, st.alpha * 0.22)
		for o: Vector2 in offs:
			ci.draw_texture_rect_region(tex, Rect2(local.position + o, local.size), region, gc)
	# 색수차
	if st.split > 0.05:
		var sp := st.split * sscale
		_draw_body(ci, st, tex, region, local, inner, Vector2(-sp, 0), premul(st.split_color_a, st.alpha * 0.85), sscale)
		_draw_body(ci, st, tex, region, local, inner, Vector2(sp, 0), premul(st.split_color_b, st.alpha * 0.85), sscale)
	_draw_body(ci, st, tex, region, local, inner, Vector2.ZERO, premul(st.tint, st.alpha), sscale)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _draw_body(ci: CanvasItem, st: GlyphState, tex: Texture2D, region: Rect2, local: Rect2, inner: Rect2, shift: Vector2, col: Color, sscale: float) -> void:
	if st.slices.size() > 0:
		var n := st.slices.size()
		var bh := region.size.y / float(n)
		for i in n:
			var src := Rect2(region.position.x, region.position.y + bh * i, region.size.x, bh)
			var dst := Rect2(local.position.x + st.slices[i] * sscale, local.position.y + bh * i, local.size.x, bh)
			dst.position += shift
			ci.draw_texture_rect_region(tex, dst, src, col)
		return
	if st.clip < 0.999:
		var r := clip_rects(region, local, inner, st.clip, st.clip_dir)
		if r.is_empty():
			return
		var dst2: Rect2 = r[1]
		dst2.position += shift
		ci.draw_texture_rect_region(tex, dst2, r[0], col)
		return
	ci.draw_texture_rect_region(tex, Rect2(local.position + shift, local.size), region, col)


## clip(드러난 비율) → [소스 rect, 대상 rect]. inner(글자 박스 + 테두리, 중심 기준) 구간에서 경계를 옮긴다.
static func clip_rects(region: Rect2, local: Rect2, inner: Rect2, clip: float, dir: int) -> Array:
	if clip <= 0.0:
		return []
	var lo := local.position
	var hi := local.end
	if clip < 1.0:
		match dir:
			0:
				hi.x = lerpf(inner.position.x, inner.end.x, clip)
			1:
				lo.x = lerpf(inner.end.x, inner.position.x, clip)
			2:
				hi.y = lerpf(inner.position.y, inner.end.y, clip)
			_:
				lo.y = lerpf(inner.end.y, inner.position.y, clip)
	var dst := Rect2(lo, hi - lo)
	if dst.size.x <= 0.0 or dst.size.y <= 0.0:
		return []
	var src := Rect2(region.position + (dst.position - local.position), dst.size)
	return [src, dst]


## 장식 사각형(캔버스 좌표) 그리기. use_outline이면 테두리 색으로 두껍게 먼저 그린다.
static func draw_decoration(ci: CanvasItem, deco: Dictionary, origin: Vector2, fit: float) -> void:
	ci.draw_set_transform(origin, 0.0, Vector2(fit, fit))
	var a: float = deco["alpha"]
	if deco["outline"]:
		var g: float = deco["outline_size"]
		var oc := premul(deco["outline_color"], a)
		for r: Rect2 in deco["rects"]:
			ci.draw_rect(r.grow(g), oc)
	var c := premul(deco["color"], a)
	for r: Rect2 in deco["rects"]:
		ci.draw_rect(r, c)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
