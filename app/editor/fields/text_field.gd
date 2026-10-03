extends "res://app/editor/fields/field_base.gd"
## 한 줄 문자열 필드(LineEdit). 입력마다 set 명령(같은 경로라 하나로 합쳐짐).


func _build() -> void:
	var e := %Edit as LineEdit
	if not e.text_changed.is_connected(_on_text):
		e.text_changed.connect(_on_text)
	e.max_length = int(rule.get("max", 0))


func _show(v) -> void:
	var e := %Edit as LineEdit
	if v is String and e.text != v:
		var caret := e.caret_column
		e.text = v
		e.caret_column = mini(caret, v.length())


func _on_text(t: String) -> void:
	commit(t)


func focus_target() -> Control:
	return %Edit
