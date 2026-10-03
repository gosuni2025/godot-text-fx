extends "res://app/editor/fields/field_base.gd"
## 색 필드. 문서의 "#RRGGBBAA" 문자열 ↔ ColorPickerButton. 드래그 중 변경은 모델에서 하나로 합쳐진다.



func _build() -> void:
	var inherit := %Inherit as Button
	inherit.visible = rule.t == "null_or_color"
	if not inherit.pressed.is_connected(_inherit):
		inherit.pressed.connect(_inherit)
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


func _inherit() -> void:
	commit(null)


func refresh() -> void:
	if ctx == null:
		return
	var v = ctx.model.get_value(path)
	_updating = true
	(%Inherit as Button).disabled = v == null
	if v == null:
		var role := "sub_style" if path.begins_with("timeline.sub_enter") else "style"
		v = ctx.model.get_value(role + ".fill.color")
		if v == null:
			v = ctx.model.get_value("style.fill.color")
	_show(v)
	_updating = false
