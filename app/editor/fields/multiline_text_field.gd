extends "res://app/editor/fields/field_base.gd"
## 여러 줄 문자열 필드. 원문 줄바꿈과 한글 IME는 Godot TextEdit이 처리한다.


func _build() -> void:
	var edit := %Edit as TextEdit
	edit.custom_minimum_size.y = ctx.scaled(Vector2(0, 100)).y
	edit.text_changed.connect(_on_text)


func _show(value) -> void:
	var edit := %Edit as TextEdit
	if value is String and edit.text != value:
		var line := edit.get_caret_line()
		var column := edit.get_caret_column()
		edit.text = value
		edit.set_caret_line(mini(line, edit.get_line_count() - 1))
		edit.set_caret_column(column)


func _on_text() -> void:
	commit((%Edit as TextEdit).text)


func focus_target() -> Control:
	return %Edit
