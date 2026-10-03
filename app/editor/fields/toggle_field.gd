extends "res://app/editor/fields/field_base.gd"
## 켜기/끄기 필드: 토글 버튼(눌림 = 켜짐, 글자도 켜짐/꺼짐으로 바뀐다).


func _build() -> void:
	var c := %Check as Button
	if not c.toggled.is_connected(_on_toggled):
		c.toggled.connect(_on_toggled)


func _show(v) -> void:
	if v is bool:
		(%Check as Button).set_pressed_no_signal(v)
		_label(v)


func _label(on: bool) -> void:
	(%Check as Button).text = "On" if on else "Off"


func _on_toggled(on: bool) -> void:
	_label(on)
	commit(on)


func focus_target() -> Control:
	return %Check
