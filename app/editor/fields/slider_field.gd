extends "res://app/editor/fields/field_base.gd"
## 수 필드: 슬라이더 + 숫자 입력. 슬라이더 드래그는 같은 경로의 set이라 모델에서 하나로 합쳐진다.



func _build() -> void:
	var lo: float = opts.get("min", rule.get("min", 0.0))
	var hi: float = opts.get("max", rule.get("max", 1.0))
	var step: float = opts.get("step", 1.0 if rule.get("t") == "int" else _auto_step(hi - lo))
	for r: Range in [%Slider, %Spin]:
		r.min_value = lo
		r.max_value = hi
		r.step = step
	(%Spin as SpinBox).custom_arrow_step = step
	if not (%Slider as HSlider).value_changed.is_connected(_on_value):
		(%Slider as HSlider).value_changed.connect(_on_value)
		(%Spin as SpinBox).value_changed.connect(_on_value)


static func _auto_step(span: float) -> float:
	if span <= 5.0:
		return 0.01
	if span <= 20.0:
		return 0.05
	if span <= 100.0:
		return 0.5
	return 1.0


func _show(v) -> void:
	if v is float or v is int:
		(%Slider as HSlider).set_value_no_signal(v)
		(%Spin as SpinBox).set_value_no_signal(v)


func _on_value(v: float) -> void:
	var step: float = (%Slider as HSlider).step
	var value := snappedf(v, step) if step > 0.0 else v
	(%Slider as HSlider).set_value_no_signal(value)
	(%Spin as SpinBox).set_value_no_signal(value)
	commit(value)


func focus_target() -> Control:
	return %Slider
