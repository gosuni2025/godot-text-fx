class_name TextFxEffectsHold
extends RefCounted
## 유지 중 효과 표(DESIGN §2.3). 여러 개를 순서대로 중첩 적용한다.
## ht는 유지 구간 시작 후 경과 초(loop_hold에서는 끝없이 증가).

const Hash := preload("res://addons/text_fx/core/fx_hash.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")

const TYPES: PackedStringArray = ["blink", "flicker", "shake", "wave", "float", "pulse", "glitch", "color_cycle"]

## amplitude 단위는 px(캔버스), period는 초, frequency/rate는 초당 횟수.
const DEFAULTS := {
	"blink": {"period": 1.0, "min_alpha": 0.2, "hard": false},
	"flicker": {"rate": 14.0, "min_alpha": 0.35},
	"shake": {"amplitude": 2.0, "frequency": 18.0},
	"wave": {"amplitude": 6.0, "wavelength": 8.0, "speed": 1.0},
	"float": {"amplitude": 6.0, "period": 2.4},
	"pulse": {"scale": 1.06, "period": 1.2},
	"glitch": {"interval": 1.6, "duration": 0.18, "intensity": 1.0, "slices": 4, "color_a": "#FF2A6DFF", "color_b": "#2AE0FFFF"},
	"color_cycle": {"period": 3.0, "saturation": 0.6, "spread": 0.04},
}

const SALT_FLICKER := 1100
const SALT_SHAKE := 1200
const SALT_GLITCH := 1300


static func default_params(type: String) -> Dictionary:
	var d: Dictionary = {"type": type}
	d.merge(DEFAULTS.get(type, {}).duplicate(true), true)
	return d


static func apply_all(effects: Array, st: GlyphState, ht: float, g: Dictionary, ctx: Dictionary) -> void:
	for e in effects:
		if e is Dictionary:
			apply(e, st, ht, g, ctx)


static func apply(e: Dictionary, st: GlyphState, ht: float, g: Dictionary, ctx: Dictionary) -> void:
	var seed: int = ctx.get("seed", 0)
	var vertical: bool = ctx.get("vertical", false)
	var idx := st.index
	match str(e.get("type", "")):
		"blink":
			var period := maxf(0.01, float(e.get("period", 1.0)))
			var ph := fposmod(ht, period) / period
			var lo := float(e.get("min_alpha", 0.2))
			if bool(e.get("hard", false)):
				st.alpha *= 1.0 if ph < 0.5 else lo
			else:
				st.alpha *= lerpf(lo, 1.0, 0.5 + 0.5 * cos(ph * TAU))
		"flicker":
			var step := int(floor(ht * maxf(0.1, float(e.get("rate", 14.0)))))
			var v := Hash.f(seed, step, SALT_FLICKER)
			if v < 0.35:
				var lo := float(e.get("min_alpha", 0.35))
				st.alpha *= lerpf(lo, 1.0, Hash.f(seed, step, SALT_FLICKER + 1) * 0.6)
		"shake":
			var amp := float(e.get("amplitude", 2.0))
			var x := ht * float(e.get("frequency", 18.0))
			st.pos += Vector2(Hash.noise1(seed, idx * 2 + SALT_SHAKE, x), Hash.noise1(seed, idx * 2 + 1 + SALT_SHAKE, x)) * amp
		"wave":
			var wl := maxf(0.1, float(e.get("wavelength", 8.0)))
			var ph := ht * float(e.get("speed", 1.0)) - float(g.get("col", 0)) / wl
			var off := float(e.get("amplitude", 6.0)) * sin(ph * TAU)
			if vertical:
				st.pos.x += off
			else:
				st.pos.y -= off
		"float":
			var period := maxf(0.01, float(e.get("period", 2.4)))
			st.pos.y += float(e.get("amplitude", 6.0)) * sin(ht / period * TAU)
		"pulse":
			var period := maxf(0.01, float(e.get("period", 1.2)))
			var m := 1.0 + (float(e.get("scale", 1.06)) - 1.0) * (0.5 - 0.5 * cos(ht / period * TAU))
			st.scale *= m
		"glitch":
			_glitch(e, st, ht, g, ctx, seed, idx)
		"color_cycle":
			var period := maxf(0.01, float(e.get("period", 3.0)))
			var hue := fposmod(ht / period + float(g.get("col", 0)) * float(e.get("spread", 0.04)), 1.0)
			var c := Color.from_hsv(hue, clampf(float(e.get("saturation", 0.6)), 0.0, 1.0), 1.0)
			st.tint = st.tint * c


static func _glitch(e: Dictionary, st: GlyphState, ht: float, g: Dictionary, ctx: Dictionary, seed: int, idx: int) -> void:
	var interval := maxf(0.05, float(e.get("interval", 1.6)))
	var dur := clampf(float(e.get("duration", 0.18)), 0.0, interval)
	var win := int(floor(ht / interval))
	var start := float(win) * interval + Hash.f(seed, win, SALT_GLITCH) * (interval - dur)
	if ht < start or ht >= start + dur:
		return
	var em: float = ctx.get("em", 32.0)
	var inten := float(e.get("intensity", 1.0))
	var step := int(floor((ht - start) * 30.0))
	var line: int = g.get("line", 0)
	var n := clampi(int(e.get("slices", 4)), 1, 16)
	st.slices.resize(n)
	for i in n:
		var key := win * 977 + step * 31 + i
		var hit := Hash.f(seed, key, SALT_GLITCH + line * 7 + 1) < 0.45
		st.slices[i] = Hash.signed(seed, key, SALT_GLITCH + line * 7 + 2) * inten * em * 0.22 if hit else 0.0
	st.split = maxf(st.split, inten * em * 0.05 * (0.5 + 0.5 * Hash.f(seed, win * 31 + step, SALT_GLITCH + 3)))
	st.split_color_a = Color.from_string(str(e.get("color_a", "#FF2A6DFF")), st.split_color_a)
	st.split_color_b = Color.from_string(str(e.get("color_b", "#2AE0FFFF")), st.split_color_b)
	st.pos.x += Hash.signed(seed, win * 31 + step, SALT_GLITCH + 4 + idx % 3) * inten * 2.0
