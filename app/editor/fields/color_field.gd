extends "res://app/editor/fields/field_base.gd"
## 색 필드. 문서의 "#RRGGBBAA" 문자열 ↔ ColorPickerButton. 드래그 중 변경은 모델에서 하나로 합쳐진다.



func _build() -> void:
	var p := %Picker as ColorPickerButton
	if not p.color_changed.is_connected(_on_color):
		p.color_changed.connect(_on_color)


func _show(v) -> void:
	if v is String:
		(%Picker as ColorPickerButton).color = Color.html(v)


static func to_hex(c: Color) -> String:
	return "#" + c.to_html(true).to_upper()


func _on_color(c: Color) -> void:
	commit(to_hex(c))


func focus_target() -> Control:
	return %Picker
