class_name TextFxEffectsBlock
extends RefCounted
## 페이지 중심을 공유하는 전체 연출. 렌더 노드 없이 글자 상태만 바꾼다.
## 서로 다른 글자/크기도 같은 affine transform과 결정론적 노이즈를 사용한다.

const Hash := preload("res://addons/text_fx/core/fx_hash.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")


static func apply(id: String, st: GlyphState, k: float, ctx: Dictionary) -> void:
	var params: Dictionary = ctx.get("params", {})
	var kc := clampf(k, 0.0, 1.0)
	var em := float(ctx.get("block_em", ctx.get("em", 32.0)))
	var center: Vector2 = ctx.get("block_center", Vector2.ZERO)
	match id:
		"block_zoom", "emerge":
			var def_scale := 2.0 if id == "block_zoom" else 0.25
			var amount := maxf(0.0, lerpf(1.0, float(params.get("from_scale", def_scale)), k))
			scale_around(st, center, Vector2.ONE * amount)
			st.alpha *= 1.0 - kc
			if id == "block_zoom":
				st.ghost = maxf(st.ghost, maxf(0.0, float(params.get("blur", 0.16))) * em * kc)
		"shutter":
			var amount := maxf(0.0, 1.0 - k)
			var axis := str(params.get("axis", "vertical"))
			var factor := Vector2(amount, 1.0) if axis == "horizontal" else Vector2(1.0, amount)
			scale_around(st, center, factor)
			st.alpha *= clampf((1.0 - kc) * 2.0, 0.0, 1.0)
		"flash":
			st.alpha *= clampf((1.0 - kc) * 3.0, 0.0, 1.0)
			st.brightness = maxf(st.brightness, clampf(float(params.get("brightness", 1.0)) * kc, 0.0, 1.0))
			st.glow_multiplier *= 1.0 + maxf(0.0, float(params.get("glow", 1.8))) * kc
		"slam":
			_slam(st, k, ctx)
		"block_wipe":
			_wipe(st, kc, ctx)
		"block_glitch":
			var time := float(ctx.get("local", 0.0))
			var strength := maxf(0.0, float(params.get("intensity", 1.0)))
			glitch(st, params, time, kc * strength, ctx)
			var step := int(floor(time * 24.0))
			var n := Hash.f(int(ctx.get("seed", 0)), step, 4401)
			st.alpha *= 0.0 if kc >= 0.999 else (1.0 if n >= kc * 0.8 else 0.1)


static func scale_around(st: GlyphState, center: Vector2, factor: Vector2) -> void:
	st.pos = center + (st.pos - center) * factor
	st.scale *= factor


static func _slam(st: GlyphState, k: float, ctx: Dictionary) -> void:
	var params: Dictionary = ctx.get("params", {})
	var em := float(ctx.get("block_em", ctx.get("em", 32.0)))
	var center: Vector2 = ctx.get("block_center", Vector2.ZERO)
	var large := maxf(1.0, float(params.get("from_scale", 2.4)))
	var blur := maxf(0.0, float(params.get("blur", 0.08))) * em
	var kc := clampf(k, 0.0, 1.0)
	if bool(ctx.get("is_exit", false)):
		scale_around(st, center, Vector2.ONE * lerpf(1.0, large, kc))
		st.alpha *= 1.0 - kc
		st.ghost = maxf(st.ghost, blur * kc)
		return
	var duration := maxf(0.0001, float(ctx.get("duration", 1.0)))
	var p := clampf(float(ctx.get("local", 0.0)) / duration, 0.0, 1.0)
	var impact := clampf(float(params.get("impact", 0.4)), 0.05, 0.95)
	if p < impact:
		var q := p / impact
		scale_around(st, center, Vector2.ONE * lerpf(large, 1.0, q * q))
		st.alpha *= clampf(q * 3.0, 0.0, 1.0)
		st.ghost = maxf(st.ghost, blur * (1.0 - q))
	else:
		var q := (p - impact) / (1.0 - impact)
		var decay := (1.0 - q) * (1.0 - q)
		var amplitude := maxf(0.0, float(params.get("shake", 0.06))) * em * decay
		var step := int(floor(float(ctx.get("local", 0.0)) * 32.0))
		var seed := int(ctx.get("seed", 0))
		st.pos += Vector2(Hash.signed(seed, step, 4501), Hash.signed(seed, step, 4502)) * amplitude
		scale_around(st, center, Vector2.ONE * (1.0 + sin(q * TAU * 1.5) * 0.04 * decay))
		st.brightness = maxf(st.brightness, clampf(float(params.get("brightness", 0.7)) * decay, 0.0, 1.0))


static func _wipe(st: GlyphState, hidden: float, ctx: Dictionary) -> void:
	var params: Dictionary = ctx.get("params", {})
	var em := float(ctx.get("block_em", ctx.get("em", 32.0)))
	var area: Rect2 = ctx.get("block_rect", Rect2(Vector2.ZERO, ctx.get("canvas", Vector2(1280, 720))))
	# 외곽선·그림자까지 마스크 경계 밖에서 자연스럽게 나타나도록 여백을 둔다.
	area = area.grow(em * 0.5)
	var rect := area
	var dir := str(params.get("dir", "right"))
	var is_exit := bool(ctx.get("is_exit", false))
	var shown := 1.0 - hidden
	if dir == "center":
		var fraction := hidden if is_exit else shown
		rect.size.x = area.size.x * fraction
		rect.position.x = area.get_center().x - rect.size.x * 0.5
		st.clip_invert = is_exit
	else:
		var horizontal := dir == "left" or dir == "right"
		var keep_end := (dir == "left" or dir == "up") != is_exit
		if horizontal:
			rect.size.x = area.size.x * shown
			if keep_end:
				rect.position.x = area.end.x - rect.size.x
		else:
			rect.size.y = area.size.y * shown
			if keep_end:
				rect.position.y = area.end.y - rect.size.y
	st.clip_enabled = hidden > 0.00001
	st.clip_rect = rect
	st.clip_feather = maxf(0.0, float(params.get("feather", 0.12))) * em
	if hidden >= 0.99999:
		st.alpha = 0.0


## 전체 글자가 공유하는 캔버스 y 구간별 x 어긋남. 글자 크기와 무관하게 같은 띠로 자른다.
static func glitch(st: GlyphState, params: Dictionary, time: float, strength: float, ctx: Dictionary) -> void:
	if strength <= 0.00001:
		return
	var em := float(ctx.get("block_em", ctx.get("em", 32.0)))
	var seed := int(ctx.get("seed", 0))
	var step := int(floor(time * 24.0))
	var n := clampi(int(params.get("slices", 5)), 1, 32)
	var rect: Rect2 = ctx.get("block_rect", Rect2(Vector2.ZERO, ctx.get("canvas", Vector2(1280, 720))))
	st.slices_global = true
	st.slice_origin_y = rect.position.y - em * 0.5
	st.slice_height = maxf(1.0, (rect.size.y + em) / float(n))
	st.slices.resize(n)
	for i in n:
		var hit := Hash.f(seed, step * 37 + i, 4601) < 0.55
		st.slices[i] = Hash.signed(seed, step * 37 + i, 4602) * em * 0.25 * strength if hit else 0.0
	st.pos.x += Hash.signed(seed, step, 4603) * em * 0.06 * strength
	st.split = maxf(st.split, strength * em * 0.065)
	st.split_color_a = Color.from_string(str(params.get("color_a", "#FF2A6DFF")), st.split_color_a)
	st.split_color_b = Color.from_string(str(params.get("color_b", "#2AE0FFFF")), st.split_color_b)
