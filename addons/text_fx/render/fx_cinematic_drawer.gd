extends RefCounted
## 순수 evaluator가 만든 선·입자를 그린다. 게임 시간·난수·물리 상태를 읽지 않는다.
const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")


static func draw(item: RID, marks: Array, alpha: float) -> void:
	for mark: Dictionary in marks:
		var points: PackedVector2Array = mark["points"]
		var color := Drawer.premul(mark["color"], alpha * float(mark["alpha"]))
		var width: float = mark["width"]
		if mark["type"] == "dot" and not points.is_empty():
			var polygon := PackedVector2Array()
			for i in 16:
				polygon.append(points[0] + Vector2.from_angle(float(i) * TAU / 16.0) * width)
			RenderingServer.canvas_item_add_polygon(item, polygon, PackedColorArray([color]))
		elif points.size() >= 2:
			RenderingServer.canvas_item_add_polyline(item, points, PackedColorArray([color]), width, true)
