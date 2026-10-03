extends RefCounted
## Scale visual menu dimensions once, preserving a 44px landscape touch target.
static func apply(panel: Control, buttons: Array, multiplier: float) -> void:
	panel.custom_minimum_size.x *= multiplier
	for button: Button in buttons:
		button.custom_minimum_size *= multiplier
		button.set_meta("base_menu_height", button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", maxi(5, roundi(button.get_theme_font_size("font_size") * multiplier)))
		for key in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := button.get_theme_stylebox(key).duplicate() as StyleBox
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				style.set_content_margin(side, maxf(0, style.get_content_margin(side)) * multiplier)
			button.add_theme_stylebox_override(key, style)
	fit_touch_targets(panel, buttons)

static func fit_touch_targets(control: Control, buttons: Array) -> void:
	var viewport := control.get_viewport()
	var scale_y := viewport.get_screen_transform().get_scale().y
	for button: Button in buttons:
		button.custom_minimum_size.y = maxf(float(button.get_meta("base_menu_height", 0.0)), 44.0 / maxf(1.0, scale_y))
