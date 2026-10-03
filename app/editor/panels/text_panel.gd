extends "res://app/editor/panels/panel_base.gd"
## 문장 탭: 본문·보조 문구(set_text, 연속 입력은 하나로 합쳐짐)와 문서 이름.

var _updating := false


func _setup() -> void:
	(%Main as Control).custom_minimum_size.y = ctx.scaled(Vector2(0, 180)).y
	(%Sub as Control).custom_minimum_size.y = ctx.scaled(Vector2(0, 90)).y
	(%Main as TextEdit).text_changed.connect(_on_main)
	(%Sub as TextEdit).text_changed.connect(_on_sub)


func _build() -> void:
	var box := %Extra as VBoxContainer
	clear_box(box)
	add_field(box, "name")


func _refresh() -> void:
	_updating = true
	_show(%Main, str(ctx.model.get_value("text")))
	_show(%Sub, str(ctx.model.get_value("sub_text")))
	_updating = false
	var mode := str(ctx.model.get_value("mode"))
	var scroll = ctx.model.get_value("timeline.scroll")
	(%PageHint as Label).visible = mode == "trailer" and not (scroll is Dictionary)


static func _show(edit: TextEdit, value: String) -> void:
	if edit.text == value:
		return
	var line := edit.get_caret_line()
	var col := edit.get_caret_column()
	edit.text = value
	edit.set_caret_line(mini(line, edit.get_line_count() - 1))
	edit.set_caret_column(col)


func _on_main() -> void:
	if not _updating:
		ctx.send({"op": "set_text", "text": (%Main as TextEdit).text})


func _on_sub() -> void:
	if not _updating:
		ctx.send({"op": "set_text", "sub_text": (%Sub as TextEdit).text})
