extends RefCounted
## 문서 캔버스 좌표로 장식 상태를 그린다. Player와 같은 premultiplied alpha 계약.
const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")

static func draw(canvas: CanvasItem, d: Dictionary) -> void:
	var type := str(d["type"])
	var alpha := float(d["alpha"])
	if type == "box":
		for rect: Rect2 in d["rects"]:
			_box(canvas, rect, d, alpha)
		return
	if type == "frame" and float(d.get("fill_opacity", 0.0)) > 0.0:
		canvas.draw_rect(d["fill_rect"], Drawer.premul(d["fill_color"], alpha * float(d["fill_opacity"])))
	for i in d["rects"].size():
		var rect: Rect2 = d["rects"][i]
		alpha = float(d["alpha"])
		if type == "tape" and d.get("blink", false) and i % 2 != int(d["blink_phase"]):
			alpha *= 1.0 - float(d.get("blink_strength", 1.0))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if d.get("outline2", false):
			var pad := float(d["outline2_size"]) + (float(d["outline_size"]) if d.get("outline", false) else 0.0)
			canvas.draw_rect(rect.grow(pad), Drawer.premul(d["outline2_color"], alpha))
		if d.get("outline", false):
			canvas.draw_rect(rect.grow(float(d["outline_size"])), Drawer.premul(d["outline_color"], alpha))
		if type == "band" and (float(d.get("softness", 0.0)) > 0.0 or float(d.get("end_fade", 0.0)) > 0.0):
			_band(canvas, rect, d, alpha)
		else:
			canvas.draw_rect(rect, Drawer.premul(d["color"], alpha))
		if type == "tape":
			_tape(canvas, rect, d, i, alpha)

static func _box(canvas: CanvasItem, rect: Rect2, d: Dictionary, alpha: float) -> void:
	var thickness := float(d.get("thickness", 0.0))
	var radius := float(d.get("radius", 0.0))
	if thickness > 0.0:
		if d.get("outline2", false):
			var pad := float(d["outline2_size"]) + (float(d["outline_size"]) if d.get("outline", false) else 0.0)
			_rounded(canvas, rect.grow(pad), radius + pad, Drawer.premul(d["outline2_color"], alpha), Color(0, 0, 0, 0), thickness + pad)
		if d.get("outline", false):
			var pad := float(d["outline_size"])
			_rounded(canvas, rect.grow(pad), radius + pad, Drawer.premul(d["outline_color"], alpha), Color(0, 0, 0, 0), thickness + pad)
	_rounded(canvas, rect, radius, Drawer.premul(d["color"], alpha),
		Drawer.premul(d.get("fill_color", Color(0, 0, 0, 0)), alpha * float(d.get("fill_opacity", 0.0))), thickness)

static func _rounded(canvas: CanvasItem, rect: Rect2, radius: float, border: Color, fill: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(roundi(width))
	style.set_corner_radius_all(roundi(radius))
	style.corner_detail = 12
	canvas.draw_style_box(style, rect)

static func _band(canvas: CanvasItem, rect: Rect2, d: Dictionary, alpha: float) -> void:
	var vertical := bool(d.get("vertical", false))
	var softness := float(d.get("softness", 0.0))
	var ends := float(d.get("end_fade", 0.0))
	var nx := 8 if vertical else 16
	var ny := 16 if vertical else 8
	var step := rect.size / Vector2(nx, ny)
	for x in nx:
		for y in ny:
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]:
				var uv := corner / Vector2(nx, ny)
				var a := _edge(uv.x if vertical else uv.y, softness) * _edge(uv.y if vertical else uv.x, ends)
				points.append(rect.position + corner * step)
				colors.append(Drawer.premul(d["color"], alpha * a))
			# 꼭짓점 alpha를 보간해 셀 경계의 계단·중복 합성을 없앤다.
			canvas.draw_polygon(points, colors)

static func _edge(p: float, fade: float) -> float:
	return 1.0 if fade <= 0.0 else smoothstep(0.0, maxf(0.001, fade * 0.5), minf(p, 1.0 - p))

static func _tape(canvas: CanvasItem, rect: Rect2, d: Dictionary, index: int, alpha: float) -> void:
	var vertical := bool(d.get("vertical", false))
	var width := maxf(2.0, float(d.get("stripe_width", 24.0)))
	var phase := fposmod(float(d.get("stripe_phase", 0.0)) * (-1.0 if index % 2 == 0 else 1.0), width * 2.0)
	var span := rect.size.y if vertical else rect.size.x
	var thick := rect.size.x if vertical else rect.size.y
	var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var start := -thick - width * 2.0 + phase
	while start < span + thick:
		var points := PackedVector2Array()
		for p: Vector2 in [Vector2(start, 0), Vector2(start + width, 0), Vector2(start + width + thick, thick), Vector2(start + thick, thick)]:
			points.append(rect.position + (Vector2(p.y, p.x) if vertical else p))
		for poly in Geometry2D.intersect_polygons(points, clip):
			canvas.draw_colored_polygon(poly, Drawer.premul(d.get("fill_color", Color.BLACK), alpha))
		start += width * 2.0
