class_name TextFxEffectsCinematic
extends RefCounted
## 노드·렌더링 없이 시간과 seed에서 조각, 잔상, 표면 마스크, 선·입자를 계산한다.
## shader의 숨김 정도와 모든 보조 도형도 여기서 정해진다. 누적 시뮬레이션은 없다.

const Hash := preload("res://addons/text_fx/core/fx_hash.gd")
const State := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const IDS: PackedStringArray = ["fragment_assemble", "ink_bleed", "ember_dissolve", "dimensional_rift",
	"afterimage_overtake", "liquid_merge", "frost_crystal", "thread_stitch", "surface_pressure"]
const COLORS := {"fragment_assemble": "#D9C5FFFF", "ink_bleed": "#553A86FF", "ember_dissolve": "#FF9A32FF",
	"dimensional_rift": "#B46CFFFF", "afterimage_overtake": "#61DFFFFF", "liquid_merge": "#68E3D4FF",
	"frost_crystal": "#BDEFFFFF", "thread_stitch": "#FFD985FF", "surface_pressure": "#D599DFFF"}
const MODES := {"ink_bleed": 1, "ember_dissolve": 2, "dimensional_rift": 3, "liquid_merge": 4,
	"frost_crystal": 5, "thread_stitch": 6, "surface_pressure": 7}
const DEFAULTS := {
	"fragment_assemble": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#D9C5FFFF"},
	"ink_bleed": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#553A86FF"},
	"ember_dissolve": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#FF9A32FF"},
	"dimensional_rift": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#B46CFFFF"},
	"afterimage_overtake": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#61DFFFFF"},
	"liquid_merge": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#68E3D4FF"},
	"frost_crystal": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#BDEFFFFF"},
	"thread_stitch": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#FFD985FF"},
	"surface_pressure": {"intensity": 1.0, "detail": 8, "distance": 1.2, "color": "#D599DFFF"},
}


static func default_params(id: String) -> Dictionary:
	return DEFAULTS.get(id, {}).duplicate(true)


static func apply(id: String, st: State, k: float, g: Dictionary, ctx: Dictionary) -> void:
	var hidden := clampf(k, 0.0, 1.0)
	if hidden <= 0.00001:
		return
	var p: Dictionary = ctx.get("params", {})
	var intensity := clampf(float(p.get("intensity", 1.0)), 0.0, 3.0)
	var detail := clampi(int(p.get("detail", 8)), 2, 16)
	var distance := clampf(float(p.get("distance", 1.2)), 0.0, 5.0)
	var color := Color.from_string(str(p.get("color", COLORS[id])), Color.WHITE)
	var seed: int = ctx.get("seed", 0)
	var em: float = ctx.get("em", 32.0)
	var box: Vector2 = g.get("box", Vector2.ONE * em)
	box = Vector2(maxf(box.x, em * 0.3), maxf(box.y, em * 0.7))
	var elapsed := float(ctx.get("local", 0.0))
	var duration := maxf(0.001, float(ctx.get("duration", 1.0)))
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var leaving: bool = ctx.get("is_exit", false)
	# 시작·끝을 정확히 숨긴다. 나머지 마스크는 실제 glyph alpha 안에서 평가한다.
	st.alpha *= 0.0 if hidden >= 0.99999 else 1.0 - 0.12 * hidden
	st.cinematic = {"mode": MODES.get(id, 0), "hidden": hidden, "progress": progress,
		"seed": Hash.f(seed, st.index, 9100) * 89.0, "intensity": intensity, "detail": detail,
		"distance": distance, "color": color, "marks": []}
	match id:
		"fragment_assemble":
			_fragments(st, hidden, detail, intensity, distance, em, seed)
			st.tint = st.tint.lerp(color, sin(hidden * PI) * 0.3)
		"afterimage_overtake":
			_echoes(st, hidden, detail, intensity, distance, em, color, leaving)
		"ink_bleed":
			st.scale *= 1.0 + hidden * 0.055 * intensity
		"ember_dissolve":
			_embers(st, hidden, progress, detail, intensity, distance, em, box, seed, color, leaving)
		"dimensional_rift":
			_rift(st, hidden, detail, intensity, distance, em, box, color)
		"liquid_merge":
			_liquid(st, hidden, progress, detail, intensity, distance, em, box, seed, color)
		"frost_crystal":
			_frost(st, hidden, detail, intensity, distance, em, box, seed, color, leaving)
		"thread_stitch":
			_stitch(st, hidden, detail, intensity, distance, em, box, color)
		"surface_pressure":
			_pressure(st, hidden, progress, detail, intensity, distance, em, box, color)


static func _fragments(st: State, k: float, detail: int, amount: float, distance: float, em: float, seed: int) -> void:
	var columns := clampi(int(ceil(sqrt(float(detail)))), 2, 4)
	var rows := columns
	for y in rows:
		for x in columns:
			var i := y * columns + x
			var angle := Hash.f(seed, st.index * 32 + i, 9201) * TAU
			var spread := distance * em * (0.45 + Hash.f(seed, st.index * 32 + i, 9202))
			st.fragments.append({"rect": Rect2(Vector2(x, y) / columns, Vector2.ONE / columns),
				"offset": Vector2.from_angle(angle) * spread * k * amount,
				"rotation": Hash.signed(seed, st.index * 32 + i, 9203) * PI * k * amount,
				"scale": 1.0 - 0.45 * k, "alpha": 1.0 - pow(k, 4.0)})
	st.brightness = maxf(st.brightness, pow(1.0 - k, 6.0) * k * 5.0 * amount)


static func _echoes(st: State, k: float, detail: int, amount: float, distance: float, em: float, color: Color, leaving: bool) -> void:
	var count := clampi(detail / 2, 2, 8)
	var motion := -1.0 if leaving else 1.0
	var arc := sin((1.0 - k) * PI)
	st.pos.x += motion * distance * em * k * amount * 0.25
	for i in count:
		var fraction := float(i + 1) / count
		# 앞지른 잔상이 마지막 구간에서 제자리로 돌아온다.
		var offset := Vector2(motion * (k * 0.4 - arc * fraction) * distance * em * amount,
			 sin(fraction * PI) * arc * em * 0.18 * amount)
		st.echoes.append({"offset": offset, "scale": 1.0 + 0.08 * arc * fraction,
			"rotation": 0.0, "alpha": (1.0 - fraction * 0.65) * arc * 0.5,
			"color": color.lerp(Color.WHITE, fraction * 0.4)})
	st.alpha *= 1.0 - k


static func _embers(st: State, k: float, progress: float, detail: int, amount: float, distance: float,
		em: float, box: Vector2, seed: int, color: Color, leaving: bool) -> void:
	for i in detail * 2:
		var start := Hash.f(seed, st.index * 64 + i, 9301) * 0.65
		var phase := (progress if leaving else 1.0 - progress) - start
		if phase <= 0.0:
			continue
		var life := clampf(phase / 0.55, 0.0, 1.0)
		var x := Hash.signed(seed, st.index * 64 + i, 9302) * box.x * 0.5
		var y := Hash.signed(seed, st.index * 64 + i, 9303) * box.y * 0.35
		var drift := Vector2(sin(life * 8.0 + i) * 0.18, -life * distance) * em * amount
		var radius := em * (0.014 + Hash.f(seed, st.index * 64 + i, 9304) * 0.023)
		var c := color.lerp(Color(0.25, 0.19, 0.25), life)
		_mark(st, "dot", [Vector2(x, y) + drift], c, radius * (1.0 - life * 0.7),
			sin(life * PI) * (1.0 - k) * 3.0)


static func _rift(st: State, k: float, detail: int, amount: float, distance: float, em: float, box: Vector2, color: Color) -> void:
	var open := 1.0 - k
	var width := maxf(1.0, box.x * open * 0.55)
	var points := PackedVector2Array()
	for i in detail + 1:
		var y := (float(i) / detail - 0.5) * (box.y + em * 0.65 * distance)
		points.append(Vector2(sin(i * 2.7) * em * 0.055 * amount, y))
	for side in [-1.0, 1.0]:
		var edge := PackedVector2Array()
		for p: Vector2 in points:
			edge.append(p + Vector2(side * width, 0.0))
		_mark(st, "line", edge, color, em * 0.025 * maxf(0.35, amount), sin(open * PI))
	st.split = maxf(st.split, k * open * em * 0.09 * amount)
	st.split_color_a = color
	st.split_color_b = Color.WHITE


static func _liquid(st: State, k: float, progress: float, detail: int, amount: float, distance: float,
		em: float, box: Vector2, seed: int, color: Color) -> void:
	var swell := sin((1.0 - k) * PI * 2.0) * k * 0.15 * amount
	st.scale *= Vector2(1.0 + swell, maxf(0.2, 1.0 - swell))
	for i in detail:
		var a := Hash.f(seed, st.index * 32 + i, 9401) * TAU
		var target := Vector2(Hash.signed(seed, st.index * 32 + i, 9402) * box.x * 0.35,
			Hash.signed(seed, st.index * 32 + i, 9403) * box.y * 0.3)
		var pos := target + Vector2.from_angle(a) * em * distance * pow(k, 1.5) * amount
		pos.y += sin(progress * TAU * 1.5 + a) * k * em * 0.12 * amount
		var radius := em * (0.03 + Hash.f(seed, st.index * 32 + i, 9404) * 0.065) * k
		_mark(st, "dot", [pos], color, radius, sin(k * PI) * 0.85)
		_mark(st, "dot", [pos + Vector2(-0.25, -0.3) * radius], Color.WHITE, radius * 0.22, sin(k * PI) * 0.75)


static func _frost(st: State, k: float, detail: int, amount: float, distance: float, em: float, box: Vector2,
		seed: int, color: Color, leaving: bool) -> void:
	var growth := 1.0 - k
	for i in detail:
		var origin := Vector2(Hash.signed(seed, st.index * 32 + i, 9501) * box.x * 0.55,
			Hash.signed(seed, st.index * 32 + i, 9502) * box.y * 0.55)
		if leaving:
			origin += Vector2(Hash.signed(seed, i, 9503), 1.0) * k * em * amount
		var radius := em * (0.07 + 0.1 * Hash.f(seed, i, 9504)) * growth * amount * (0.4 + distance * 0.5)
		for branch in 3:
			var direction := Vector2.from_angle(branch * PI / 3.0)
			_mark(st, "line", [origin - direction * radius, origin + direction * radius], color,
				maxf(0.7, em * 0.012), sin(growth * PI) * 0.9)
			var tip := origin + direction * radius * 0.6
			for sign in [-1.0, 1.0]:
				_mark(st, "line", [tip, tip - direction.rotated(sign * PI / 3.0) * radius * 0.4], color,
					maxf(0.5, em * 0.008), sin(growth * PI) * 0.8)


static func _stitch(st: State, k: float, detail: int, amount: float, distance: float, em: float, box: Vector2, color: Color) -> void:
	var shown := (1.0 - k) * detail
	var path := PackedVector2Array()
	for i in detail + 1:
		if float(i) > shown:
			break
		path.append(Vector2((float(i) / detail - 0.5) * box.x,
			(-0.24 if i % 2 == 0 else 0.24) * box.y))
	var head := Vector2((shown / detail - 0.5) * box.x,
		lerpf(-0.24 if int(shown) % 2 == 0 else 0.24, 0.24 if int(shown) % 2 == 0 else -0.24, fposmod(shown, 1.0)) * box.y)
	path.append(head)
	_mark(st, "line", path, color, maxf(0.8, em * 0.025 * amount), minf(1.0, k * 5.0))
	_mark(st, "dot", [head], Color.WHITE, em * 0.035 * amount, sin(k * PI))
	var tail := head + Vector2(-0.15, -0.45) * em * k * distance
	_mark(st, "line", [head, tail], color, maxf(0.7, em * 0.018), sin(k * PI))


static func _pressure(st: State, k: float, progress: float, detail: int, amount: float,
		distance: float, em: float, box: Vector2, color: Color) -> void:
	var pressure := sin((1.0 - k) * PI)
	st.scale *= 1.0 + pressure * 0.25 * amount
	st.pos.y -= pressure * em * 0.08 * amount
	for ring in 3:
		var points := PackedVector2Array()
		var r := 0.45 + float(ring) * 0.13 * distance
		for i in 33:
			var a := float(i) / 32.0 * TAU
			var wobble := sin(a * detail + progress * TAU) * 0.02 * pressure * amount
			points.append(Vector2(cos(a) * box.x, sin(a) * box.y) * (r + wobble))
		_mark(st, "line", points, color, maxf(0.7, em * 0.012), pressure * (0.32 - ring * 0.07))


static func _mark(st: State, kind: String, points, color: Color, width: float, alpha: float) -> void:
	if alpha <= 0.001 or width <= 0.001:
		return
	st.cinematic["marks"].append({"type": kind, "points": PackedVector2Array(points), "color": color,
		"width": width, "alpha": clampf(alpha, 0.0, 1.0)})
