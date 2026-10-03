class_name TextFxEffectsEnter
extends RefCounted
## 등장/퇴장 효과 표(DESIGN §2.2).
## 각 효과는 숨김 정도 k(0 = 정상, 1 = 완전히 숨김)로 글자 상태를 바꾼다.
## 등장은 k = 1 - ease(p), 퇴장은 k = ease(p). 방향이 있는 효과(slide/drop/rise/wipe)는
## 퇴장에서 들어온 길로 되돌아가지 않고 운동 방향을 이어 간다(dir = 움직이는 방향).
## center_stamp 등장은 시퀀스라 fx_center_stamp.gd가 처리하고, 퇴장에서는 slam_scale 배율 zoom으로 동작한다.

const Hash := preload("res://addons/text_fx/core/fx_hash.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Block := preload("res://addons/text_fx/core/fx_effects_block.gd")
const Cinematic := preload("res://addons/text_fx/core/fx_effects_cinematic.gd")

const IDS: PackedStringArray = [
	"fade", "slide", "zoom", "pop", "drop", "rise", "blur", "spin", "converge",
	"tracking", "center_split", "scatter", "wipe", "typewriter", "glitch", "center_stamp",
	"flip", "flicker", "slam", "block_zoom", "emerge", "shutter", "flash", "erase",
	"block_wipe", "block_glitch", "bounce",
	"fragment_assemble", "ink_bleed", "ember_dissolve", "dimensional_rift", "afterimage_overtake",
	"liquid_merge", "frost_crystal", "thread_stitch", "surface_pressure",
	"text_morph",
]

const BLOCK_EFFECTS: PackedStringArray = ["slam", "block_zoom", "emerge", "shutter", "flash", "block_wipe", "block_glitch", "text_morph"]

## 거리 단위는 em(글자 크기 비율), 각도는 도.
const DEFAULTS := {
	"fade": {},
	"slide": {"dir": "up", "distance": 0.5},
	"zoom": {"from_scale": 0.3},
	"pop": {"from_scale": 0.2},
	"drop": {"distance": 1.2},
	"rise": {"distance": 0.8, "blur": 0.15},
	"blur": {"radius": 0.18},
	"spin": {"angle": 180.0},
	"converge": {"distance": 1.0, "mode": "alternate"},
	"tracking": {"spread": 1.2},
	"center_split": {"jitter": 0.25, "overlap_hold": 0.0},
	"scatter": {"distance": 3.0, "angle": 120.0},
	"wipe": {"dir": "right"},
	"typewriter": {"pop": 0.25},
	"glitch": {"intensity": 1.0, "color_a": "#FF2A6DFF", "color_b": "#2AE0FFFF"},
	"center_stamp": {"solo_animated": true, "viewport_scale": 0.0, "big_scale": 3.0, "hold_each": 0.28, "pause": 0.3, "slam_scale": 2.2,
		"space_pause": 0.0, "impact_duration": 0.0, "impact_brightness": 0.0, "impact_shake": 0.0},
	"flip": {"axis": "auto"},
	"flicker": {"rate": 20.0, "min_alpha": 0.08},
	"slam": {"from_scale": 2.4, "impact": 0.4, "shake": 0.06, "brightness": 0.7, "blur": 0.08},
	"block_zoom": {"from_scale": 2.0, "blur": 0.16},
	"emerge": {"from_scale": 0.25},
	"shutter": {"axis": "vertical"},
	"flash": {"brightness": 1.0, "glow": 1.8},
	"erase": {},
	"block_wipe": {"dir": "right", "feather": 0.12},
	"block_glitch": {"intensity": 1.0, "slices": 5, "color_a": "#FF2A6DFF", "color_b": "#2AE0FFFF"},
	"bounce": {"distance": 1.2},
	"text_morph": {"from_text": "", "readable_ratio": 0.3, "intensity": 1.0},
	"fragment_assemble": Cinematic.DEFAULTS["fragment_assemble"],
	"ink_bleed": Cinematic.DEFAULTS["ink_bleed"],
	"ember_dissolve": Cinematic.DEFAULTS["ember_dissolve"],
	"dimensional_rift": Cinematic.DEFAULTS["dimensional_rift"],
	"afterimage_overtake": Cinematic.DEFAULTS["afterimage_overtake"],
	"liquid_merge": Cinematic.DEFAULTS["liquid_merge"],
	"frost_crystal": Cinematic.DEFAULTS["frost_crystal"],
	"thread_stitch": Cinematic.DEFAULTS["thread_stitch"],
	"surface_pressure": Cinematic.DEFAULTS["surface_pressure"],
}

## 모든 효과 공통 params(순서 관련).
const COMMON := {"punct_pause": 0.0, "punct_long_pause": 0.0, "line_pause": 0.0, "line_stagger": 0.65, "sweep_duration": 0.5,
	"cursor": false, "cursor_blink": 0.6, "cursor_color": null}

## 효과별 권장 이징(에디터 템플릿용 힌트).
const SUGGESTED_EASING := {
	"pop": "back_out", "drop": "bounce_out", "typewriter": "linear", "glitch": "linear",
	"center_stamp": "cubic_in", "scatter": "quart_out", "spin": "back_out",
	"bounce": "bounce_out", "flip": "back_out", "flicker": "linear", "erase": "linear",
	"slam": "linear", "block_glitch": "linear", "shutter": "expo_out", "block_wipe": "cubic_in_out",
	"text_morph": "linear",
	"fragment_assemble": "linear", "ink_bleed": "linear", "ember_dissolve": "linear",
	"dimensional_rift": "linear", "afterimage_overtake": "linear", "liquid_merge": "linear",
	"frost_crystal": "linear", "thread_stitch": "linear", "surface_pressure": "linear",
}

const DIRS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
const SALT_SCATTER := 101
const SALT_SPLIT := 202
const SALT_GLITCH := 303


static func default_params(id: String) -> Dictionary:
	var d: Dictionary = COMMON.duplicate(true)
	d.merge(DEFAULTS.get(id, {}).duplicate(true), true)
	if Cinematic.IDS.has(id):
		d.merge(Cinematic.default_params(id), true)
	return d


## auto만 효과별 곡선으로 해석한다. v1의 명시 이징은 바꾸지 않는다.
static func resolve_easing(id: String, selected: String, is_exit: bool = false) -> String:
	if selected != "auto":
		return selected
	if Cinematic.IDS.has(id):
		return "linear"
	if is_exit:
		if id in ["flicker", "erase", "typewriter", "glitch", "block_glitch", "slam"]:
			return "linear"
		if id == "block_wipe":
			return "cubic_in_out"
		return "expo_in" if id == "shutter" else "cubic_in"
	return str(SUGGESTED_EASING.get(id, "cubic_out"))


## 렌더러가 아틀라스 주변 여백을 확보할 때 쓰는 최대 blur(em).
static func max_blur_em(seg: Dictionary) -> float:
	var id := str(seg.get("effect", ""))
	var params: Dictionary = seg.get("params", {})
	if id == "blur":
		return maxf(0.0, float(params.get("radius", 0.18)))
	if id in ["rise", "slam", "block_zoom"]:
		return maxf(0.0, float(params.get("blur", DEFAULTS[id]["blur"])))
	return 0.0


## ctx: { seed, em, params, is_exit, vertical, line_center(Vector2), local(이 글자 애니메이션 경과 초) }
## g: 레이아웃 글자 Dictionary.
static func apply(id: String, st: GlyphState, k: float, g: Dictionary, ctx: Dictionary) -> void:
	if id == "text_morph":
		if ctx.get("is_exit", false):
			st.alpha *= 1.0 - clampf(k, 0.0, 1.0)
		return # 원문과 대상문을 함께 다루는 evaluator의 문장 변이 경로가 처리한다.
	if Cinematic.IDS.has(id):
		Cinematic.apply(id, st, k, g, ctx)
		return
	if BLOCK_EFFECTS.has(id):
		Block.apply(id, st, k, ctx)
		return
	var kc := clampf(k, 0.0, 1.0)
	var params: Dictionary = ctx.get("params", {})
	var em: float = ctx.get("em", 32.0)
	var seed: int = ctx.get("seed", 0)
	var is_exit: bool = ctx.get("is_exit", false)
	var vertical: bool = ctx.get("vertical", false)
	var idx: int = st.index
	match id:
		"fade":
			st.alpha *= 1.0 - kc
		"slide":
			var d: Vector2 = DIRS.get(str(params.get("dir", "up")), Vector2(0, -1))
			st.pos += d * (1.0 if is_exit else -1.0) * float(params.get("distance", 0.5)) * em * k
			st.alpha *= 1.0 - kc
		"zoom":
			st.scale *= maxf(0.0, lerpf(1.0, float(params.get("from_scale", 0.3)), k))
			st.alpha *= 1.0 - kc
		"pop":
			st.scale *= maxf(0.0, lerpf(1.0, float(params.get("from_scale", 0.2)), k))
			st.alpha *= clampf((1.0 - k) * 3.0, 0.0, 1.0)
		"drop", "bounce":
			var dist := float(params.get("distance", 1.2)) * em
			st.pos.y += (dist if is_exit else -dist) * k
			st.alpha *= clampf((1.0 - k) * 4.0, 0.0, 1.0)
		"rise":
			var dist := float(params.get("distance", 0.8)) * em
			st.pos.y += (-dist if is_exit else dist) * k
			st.ghost = maxf(st.ghost, float(params.get("blur", 0.15)) * em * kc)
			st.ghost_dir = Vector2(0, 1)
			st.alpha *= 1.0 - kc
		"blur":
			st.ghost = maxf(st.ghost, float(params.get("radius", 0.18)) * em * kc)
			st.ghost_dir = Vector2.ZERO
			st.scale *= 1.0 + 0.1 * kc
			st.alpha *= 1.0 - kc
		"spin":
			st.rotation += deg_to_rad(float(params.get("angle", 180.0))) * k
			st.scale *= lerpf(1.0, 0.4, kc)
			st.alpha *= 1.0 - kc
		"converge":
			var side := 1.0
			if str(params.get("mode", "alternate")) == "role":
				side = -1.0 if g.get("role", "main") == "main" else 1.0
			else:
				side = -1.0 if int(g.get("col", 0)) % 2 == 0 else 1.0
			var off := side * float(params.get("distance", 1.0)) * em * k
			if vertical:
				st.pos.x -= off
			else:
				st.pos.y += off
			st.alpha *= 1.0 - kc
		"tracking":
			var lc: Vector2 = ctx.get("line_center", st.pos)
			var spread := float(params.get("spread", 1.2))
			if vertical:
				st.pos.y += (st.pos.y - lc.y) * spread * k
			else:
				st.pos.x += (st.pos.x - lc.x) * spread * k
			st.alpha *= 1.0 - kc
		"flip":
			var axis := str(params.get("axis", "auto"))
			var x_axis := axis == "horizontal" or (axis == "auto" and vertical)
			if x_axis:
				st.scale.x *= maxf(0.0, 1.0 - k)
			else:
				st.scale.y *= maxf(0.0, 1.0 - k)
			st.alpha *= clampf((1.0 - kc) * 3.0, 0.0, 1.0)
		"flicker":
			var step := int(floor(float(ctx.get("local", 0.0)) * maxf(1.0, float(params.get("rate", 20.0)))))
			var visible := Hash.f(seed, idx + 4101, step) >= kc
			st.alpha *= 0.0 if kc >= 0.999 else (1.0 if visible else clampf(float(params.get("min_alpha", 0.08)), 0.0, 1.0))
		"erase":
			st.alpha *= 0.0 if (is_exit and k >= 0.5) or (not is_exit and k > 0.5) else 1.0
		"center_split":
			var lc: Vector2 = ctx.get("line_center", st.pos)
			var j := float(params.get("jitter", 0.25)) * em
			var hidden := lc + Vector2(Hash.signed(seed, idx, SALT_SPLIT), Hash.signed(seed, idx, SALT_SPLIT + 1)) * j
			st.pos += (hidden - st.pos) * k
			var overlap := maxf(0.0, float(params.get("overlap_hold", 0.0)))
			if overlap > 0.0 and not is_exit:
				var appearance := clampf(float(ctx.get("local", 0.0)) / minf(0.2, overlap), 0.0, 1.0)
				st.alpha *= appearance
				st.scale *= 1.0 + 0.2 * (1.0 - appearance)
			else:
				st.alpha *= clampf((1.0 - kc) * 3.0, 0.0, 1.0)
		"scatter":
			var ang := Hash.f(seed, idx, SALT_SCATTER) * TAU
			var r := float(params.get("distance", 3.0)) * em * (0.6 + 0.4 * Hash.f(seed, idx, SALT_SCATTER + 1))
			st.pos += Vector2(cos(ang), sin(ang)) * r * k
			st.rotation += deg_to_rad(float(params.get("angle", 120.0))) * Hash.signed(seed, idx, SALT_SCATTER + 2) * k
			st.alpha *= 1.0 - kc
		"wipe":
			var dir_id: int = {"right": 0, "left": 1, "down": 2, "up": 3}.get(str(params.get("dir", "right")), 0)
			if is_exit:
				dir_id = [1, 0, 3, 2][dir_id]
			st.clip = minf(st.clip, 1.0 - kc)
			st.clip_dir = dir_id
		"typewriter":
			if k >= 0.999:
				st.alpha = 0.0
			else:
				st.scale *= 1.0 + float(params.get("pop", 0.25)) * kc
		"glitch":
			st.split_color_a = Color.from_string(str(params.get("color_a", "#FF2A6DFF")), st.split_color_a)
			st.split_color_b = Color.from_string(str(params.get("color_b", "#2AE0FFFF")), st.split_color_b)
			var inten := float(params.get("intensity", 1.0))
			var step := int(floor(float(ctx.get("local", 0.0)) * 24.0))
			var jit := inten * em * 0.45 * kc
			st.pos += Vector2(Hash.signed(seed, idx * 64 + 1, step + SALT_GLITCH), Hash.signed(seed, idx * 64 + 2, step + SALT_GLITCH) * 0.3) * jit
			st.split = maxf(st.split, inten * em * 0.08 * kc)
			if kc > 0.15:
				var n := 3
				st.slices.resize(n)
				for i in n:
					var hit := Hash.f(seed, idx * 64 + 8 + i, step) < 0.5
					st.slices[i] = Hash.signed(seed, idx * 64 + 16 + i, step) * inten * em * 0.3 * kc if hit else 0.0
			if kc >= 0.999 or Hash.f(seed, idx * 64 + 3, step + SALT_GLITCH) < kc * 0.6:
				st.alpha = 0.0
		"center_stamp":
			# 퇴장(또는 시퀀스 밖) 대체 동작: 크게 부풀며 사라짐.
			st.scale *= maxf(0.0, lerpf(1.0, float(params.get("slam_scale", 2.2)), k))
			st.alpha *= 1.0 - kc
		_:
			st.alpha *= 1.0 - kc
