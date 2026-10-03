extends "res://app/editor/fields/field_base.gd"
## 2차원 값 필드([x, y]): 숫자 입력 두 개. 한쪽을 바꾸면 [x, y] 전체를 set한다.


func _build() -> void:
	var lo: float = opts.get("min", rule.get("min", -100.0))
	var hi: float = opts.get("max", rule.get("max", 100.0))
	var step: float = opts.get("step", 0.01 if hi - lo <= 2.0 else 1.0)
	for s: SpinBox in [%X, %Y]:
		s.min_value = lo
		s.max_value = hi
		s.step = step
		s.custom_arrow_step = step
		if not s.value_changed.is_connected(_on_value):
			s.value_changed.connect(_on_value)


func _show(v) -> void:
	if v is Array and v.size() == 2:
		(%X as SpinBox).set_value_no_signal(v[0])
		(%Y as SpinBox).set_value_no_signal(v[1])


func _on_value(_v: float) -> void:
	commit([float((%X as SpinBox).value), float((%Y as SpinBox).value)])


func focus_target() -> Control:
	return %X
