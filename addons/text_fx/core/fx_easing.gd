class_name TextFxEasing
extends RefCounted
## 이징 함수 표. apply(name, p)는 p를 0..1로 자른 뒤 이징 값을 돌려준다.
## back/elastic 계열은 0..1 범위를 잠시 벗어날 수 있다. 알 수 없는 이름은 linear.

const NAMES: PackedStringArray = [
	"auto", "linear",
	"sine_in", "sine_out", "sine_in_out",
	"quad_in", "quad_out", "quad_in_out",
	"cubic_in", "cubic_out", "cubic_in_out",
	"quart_in", "quart_out", "quart_in_out",
	"quint_in", "quint_out", "quint_in_out",
	"expo_in", "expo_out", "expo_in_out",
	"circ_in", "circ_out", "circ_in_out",
	"back_in", "back_out", "back_in_out",
	"elastic_in", "elastic_out", "elastic_in_out",
	"bounce_in", "bounce_out", "bounce_in_out",
]

const BACK_C1 := 1.70158


static func has(name: String) -> bool:
	return NAMES.has(name)


static func apply(name: String, p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	var u := name.rfind("_")
	if name == "linear" or u < 0:
		return p
	var kind := name.substr(0, u)
	var mode := name.substr(u + 1)
	if name.ends_with("_in_out"):
		kind = name.substr(0, name.length() - 7)
		mode = "in_out"
	match mode:
		"in":
			return _ease_in(kind, p)
		"out":
			return 1.0 - _ease_in(kind, 1.0 - p)
		"in_out":
			if p < 0.5:
				return _ease_in(kind, p * 2.0) * 0.5
			return 1.0 - _ease_in(kind, (1.0 - p) * 2.0) * 0.5
	return p


static func _ease_in(kind: String, p: float) -> float:
	match kind:
		"sine":
			return 1.0 - cos(p * PI * 0.5)
		"quad":
			return p * p
		"cubic":
			return p * p * p
		"quart":
			return p * p * p * p
		"quint":
			return p * p * p * p * p
		"expo":
			return 0.0 if p <= 0.0 else pow(2.0, 10.0 * p - 10.0)
		"circ":
			return 1.0 - sqrt(maxf(0.0, 1.0 - p * p))
		"back":
			return (BACK_C1 + 1.0) * p * p * p - BACK_C1 * p * p
		"elastic":
			if p <= 0.0 or p >= 1.0:
				return p
			return -pow(2.0, 10.0 * p - 10.0) * sin((p * 10.0 - 10.75) * TAU / 3.0)
		"bounce":
			return 1.0 - _bounce_out(1.0 - p)
	return p


static func _bounce_out(p: float) -> float:
	const N := 7.5625
	const D := 2.75
	if p < 1.0 / D:
		return N * p * p
	if p < 2.0 / D:
		p -= 1.5 / D
		return N * p * p + 0.75
	if p < 2.5 / D:
		p -= 2.25 / D
		return N * p * p + 0.9375
	p -= 2.625 / D
	return N * p * p + 0.984375
