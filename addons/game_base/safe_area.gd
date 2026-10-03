extends RefCounted

static func insets(control: Control, padding: float = 12.0) -> Vector4:
	var result := Vector4(padding, padding, padding, padding)
	var ui_size := control.get_viewport_rect().size
	if OS.has_feature("web"):
		var data = JSON.parse_string(JavaScriptBridge.eval("JSON.stringify(['left','top','right','bottom'].map(s => parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-' + s)) || 0).concat([innerWidth, innerHeight]))"))
		if data is Array and data.size() == 6 and data[4] > 0 and data[5] > 0:
			for i in range(4):
				result[i] += float(data[i]) * ui_size[i % 2] / float(data[4 + i % 2])
	elif OS.has_feature("android") or OS.has_feature("ios"):
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if screen_size.x > 0 and screen_size.y > 0 and safe.has_area():
			var scale_to_ui := ui_size / screen_size
			result += Vector4(safe.position.x * scale_to_ui.x, safe.position.y * scale_to_ui.y,
				maxf(0, screen_size.x - safe.end.x) * scale_to_ui.x,
				maxf(0, screen_size.y - safe.end.y) * scale_to_ui.y)
	return result

static func apply(control: Control, margin: MarginContainer) -> void:
	var values := insets(control)
	for i in range(4):
		margin.add_theme_constant_override("margin_" + ["left", "top", "right", "bottom"][i], ceili(values[i]))
