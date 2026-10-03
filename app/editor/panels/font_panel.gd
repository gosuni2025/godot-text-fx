extends "res://app/editor/panels/panel_base.gd"
## 글꼴 탭: 본문 글꼴과 (켜면) 보조 문구 글꼴. 고르기는 글꼴 팝업(번들/시스템/파일).


func structural_paths() -> Array:
	return ["sub_font"]


func _setup() -> void:
	%Main.setup(ctx, self, "font", "Main text font")
	%Sub.setup(ctx, self, "sub_font", "Sub text font")
	(%SubToggle as Button).toggled.connect(_on_sub_toggle)


func _build() -> void:
	%Main.build()
	%Sub.build()


func _refresh() -> void:
	var has_sub: bool = ctx.model.get_value("sub_font") is Dictionary
	(%SubToggle as Button).set_pressed_no_signal(has_sub)
	(%Sub as Control).visible = has_sub
	%Main.refresh()
	if has_sub:
		%Sub.refresh()


func _on_sub_toggle(on: bool) -> void:
	var value = (ctx.model.get_value("font") as Dictionary).duplicate(true) if on else null
	ctx.send({"op": "set", "path": "sub_font", "value": value})
	_refresh()
