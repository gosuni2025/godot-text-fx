extends HBoxContainer
## 그라데이션 색 지점 한 줄: 위치 슬라이더 + 색 + 삭제. 값 [pos, "#RRGGBBAA"]을 통째로 set한다.

const ColorField := preload("res://app/editor/fields/color_field.gd")

var ctx
var list_path := ""
var index := 0
var _updating := false


func setup(p_ctx, p_list_path: String, p_index: int, can_remove: bool) -> void:
	ctx = p_ctx
	list_path = p_list_path
	index = p_index
	(%Remove as Button).disabled = not can_remove
	(%Pos as HSlider).value_changed.connect(func(_v: float): _commit())
	(%Color as ColorPickerButton).color_changed.connect(func(_c: Color): _commit())
	(%Remove as Button).pressed.connect(func():
		ctx.send({"op": "list_remove", "path": list_path, "index": index}))
	refresh()


func path() -> String:
	return "%s.%d" % [list_path, index]


func refresh() -> void:
	var v = ctx.model.get_value(path())
	if not (v is Array and v.size() == 2):
		return
	_updating = true
	(%Pos as HSlider).set_value_no_signal(v[0])
	(%PosLabel as Label).text = "%d%%" % roundi(float(v[0]) * 100.0)
	(%Color as ColorPickerButton).color = Color.html(str(v[1]))
	_updating = false


func _commit() -> void:
	if _updating:
		return
	var p := snappedf((%Pos as HSlider).value, 0.01)
	(%PosLabel as Label).text = "%d%%" % roundi(p * 100.0)
	ctx.send({"op": "set", "path": path(), "value": [p, ColorField.to_hex((%Color as ColorPickerButton).color)]})
