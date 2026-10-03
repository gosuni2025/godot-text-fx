extends "res://app/editor/fields/field_base.gd"
## 선택지 필드: 콤보 리스트 대신 토글 버튼 묶음. 누르면 set 명령, 표시는 모델 값으로만 갱신한다.

const ChipScene := preload("res://app/editor/fields/chip_button.tscn")

var _buttons: Dictionary = {}   # 값 → Button


func _build() -> void:
	var box := %Chips as HFlowContainer
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	_buttons.clear()
	var values: Array = opts.get("choices", rule.get("v", []))
	var names: Dictionary = opts.get("labels", {})
	for v in values:
		var b: Button = ChipScene.instantiate()
		b.text = str(names.get(v, Labels.enum_value(path, str(v))))
		b.name = "Choice_" + str(v)
		b.pressed.connect(_on_pick.bind(v))
		box.add_child(b)
		_buttons[v] = b


func _show(v) -> void:
	for k in _buttons:
		(_buttons[k] as Button).set_pressed_no_signal(k == v)


func _on_pick(v) -> void:
	commit(v)
	refresh()


func button_for(value) -> Button:
	return _buttons.get(value)


func focus_target() -> Control:
	return (%Chips as HFlowContainer).get_child(0) if (%Chips as HFlowContainer).get_child_count() > 0 else null
