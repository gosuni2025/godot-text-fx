extends "res://app/editor/panels/panel_base.gd"
## 스타일 탭: 채우기(단색/그라데이션 + 색 지점 목록), 테두리, 2차 테두리, 그림자, 글로우, 불투명도.
## "보조 문구 스타일 따로"를 켜면 sub_style을 본문 스타일 사본으로 만들고, 대상 버튼으로 편집 대상을 고른다.

const StopScene := preload("res://app/editor/panels/gradient_stop_row.tscn")
const ActionScene := preload("res://app/editor/fields/action_button.tscn")

var target := "style"
var _stops: Array = []


func structural_paths() -> Array:
	return ["sub_style", "style.fill.type", "sub_style.fill.type", "style.fill.gradient.stops",
		"sub_style.fill.gradient.stops"]


func _setup() -> void:
	(%SubToggle as Button).toggled.connect(_on_sub_toggle)
	(%Target_style as Button).pressed.connect(_on_target.bind("style"))
	(%Target_sub_style as Button).pressed.connect(_on_target.bind("sub_style"))


func _build() -> void:
	var has_sub: bool = ctx.model.get_value("sub_style") is Dictionary
	if not has_sub:
		target = "style"
	var box := %Sections as VBoxContainer
	clear_box(box)
	_stops.clear()
	var p := target + "."
	var fill := add_section(box, "Fill")
	add_field(fill.fields_box(), p + "fill.type")
	if str(ctx.model.get_value(p + "fill.type")) == "gradient":
		add_field(fill.fields_box(), p + "fill.gradient.angle", {"min": -180.0, "max": 180.0, "step": 1.0})
		add_field(fill.fields_box(), p + "fill.gradient.space")
		var list_path := p + "fill.gradient.stops"
		var stops: Array = ctx.model.get_value(list_path)
		for i in stops.size():
			var row: Node = StopScene.instantiate()
			fill.fields_box().add_child(row)
			row.name = "Stop_%d" % i
			row.setup(ctx, list_path, i, stops.size() > 2)
			_stops.append(row)
		var add: Button = ActionScene.instantiate()
		add.name = "AddStop"
		add.text = "Add color stop"
		add.icon = ctx.ui_icon("add")
		add.disabled = stops.size() >= 8
		add.pressed.connect(func(): ctx.send({"op": "list_add", "path": list_path, "value": [0.5, "#FFFFFFFF"]}))
		fill.fields_box().add_child(add)
	else:
		add_field(fill.fields_box(), p + "fill.color")
	for o in [["outline", "Outline"], ["outline2", "Second outline layer"]]:
		var s := add_section(box, o[1])
		add_field(s.fields_box(), p + o[0] + ".enabled")
		add_field(s.fields_box(), p + o[0] + ".size", {"max": 32.0, "step": 0.5})
		add_field(s.fields_box(), p + o[0] + ".color")
	var sh := add_section(box, "Shadow")
	add_field(sh.fields_box(), p + "shadow.enabled")
	add_field(sh.fields_box(), p + "shadow.offset", {"step": 1.0})
	add_field(sh.fields_box(), p + "shadow.blur", {"max": 32.0, "step": 0.5})
	add_field(sh.fields_box(), p + "shadow.color")
	var gl := add_section(box, "Glow")
	add_field(gl.fields_box(), p + "glow.enabled")
	add_field(gl.fields_box(), p + "glow.size", {"max": 64.0, "step": 0.5})
	add_field(gl.fields_box(), p + "glow.color")
	add_field(gl.fields_box(), p + "glow.strength")
	var op := add_section(box, "Opacity")
	add_field(op.fields_box(), p + "opacity")


func _refresh() -> void:
	var has_sub: bool = ctx.model.get_value("sub_style") is Dictionary
	(%SubToggle as Button).set_pressed_no_signal(has_sub)
	(%Targets as Control).visible = has_sub
	(%Target_style as Button).set_pressed_no_signal(target == "style")
	(%Target_sub_style as Button).set_pressed_no_signal(target == "sub_style")
	for r in _stops:
		if is_instance_valid(r):
			r.refresh()


func _on_sub_toggle(on: bool) -> void:
	var value = (ctx.model.get_value("style") as Dictionary).duplicate(true) if on else null
	if ctx.send({"op": "set", "path": "sub_style", "value": value}) and on:
		target = "sub_style"
	mark_rebuild()


func _on_target(t: String) -> void:
	target = t
	rebuild()
