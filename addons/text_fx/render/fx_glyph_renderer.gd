class_name TextFxGlyphRenderer
extends RefCounted
## 매 프레임에 필요한 글자 CanvasItem을 풀에서 얻는다. draw 순서가 앞/뒤/오버레이 순서다.

const GlyphCanvas := preload("res://addons/text_fx/render/fx_glyph_canvas.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")
const CinematicDrawer := preload("res://addons/text_fx/render/fx_cinematic_drawer.gd")

var _pool: Array = []
var _used := 0
var _parent := RID()


func begin(parent: RID) -> void:
	_parent = parent
	_used = 0


func draw_glyph(st: GlyphState, sprite: Dictionary, origin: Vector2, fit: float, front: bool) -> void:
	var spr: Dictionary = sprite.get("blur", sprite) if st.ghost > 0.05 else sprite
	if not front and not st.cinematic.get("marks", []).is_empty():
		var canvas := _next_canvas()
		canvas.configure_marks(_used, Transform2D(st.rotation, st.scale * fit, 0.0, origin + st.pos * fit))
		CinematicDrawer.draw(canvas.item, st.cinematic["marks"], st.alpha)
		_used += 1
	for echo: Dictionary in st.echoes:
		var copy: GlyphState = st.copy()
		copy.cinematic = {}
		copy.fragments = []
		copy.echoes = []
		copy.pos += (echo["offset"] as Vector2).rotated(st.rotation)
		copy.rotation += float(echo.get("rotation", 0.0))
		copy.scale *= float(echo.get("scale", 1.0))
		copy.alpha *= float(echo["alpha"])
		copy.tint *= echo["color"]
		_draw_single(copy, spr, origin, fit, front)
	if not st.fragments.is_empty():
		_draw_fragments(st, spr, origin, fit, front)
		return
	_draw_single(st, spr, origin, fit, front)


func _next_canvas() -> GlyphCanvas:
	if _used == _pool.size():
		_pool.append(GlyphCanvas.new(_parent))
	return _pool[_used]


func _draw_single(st: GlyphState, spr: Dictionary, origin: Vector2, fit: float, front: bool) -> void:
	var tex: Texture2D = spr["texture_front"] if front else spr["texture"]
	if tex == null:
		return
	var canvas := _next_canvas()
	canvas.configure(st, spr, front, _used)
	Drawer.draw_glyph(canvas, st, spr, origin, fit, front)
	_used += 1


func _draw_fragments(st: GlyphState, sprite: Dictionary, origin: Vector2, fit: float, front: bool) -> void:
	var source: Rect2 = sprite["region"]
	var center: Vector2 = sprite["center"]
	var scale: float = sprite["scale"]
	for fragment: Dictionary in st.fragments:
		var rect: Rect2 = fragment["rect"]
		var region := Rect2(source.position + rect.position * source.size, rect.size * source.size)
		var cell := sprite.duplicate()
		cell["region"] = region
		cell["center"] = region.get_center()
		# 조각의 회전 원점이 각 잘린 영역의 중심이 되도록 원본 위치를 보존한다.
		var inner: Rect2 = sprite["inner"]
		cell["inner"] = Rect2(inner.position + center - region.get_center(), inner.size)
		var copy: GlyphState = st.copy()
		copy.fragments = []
		copy.echoes = []
		copy.cinematic = {}
		var local := (region.get_center() - center) / scale
		copy.pos += ((local + fragment["offset"]) * st.scale).rotated(st.rotation)
		copy.rotation += float(fragment["rotation"])
		copy.scale *= float(fragment["scale"])
		copy.alpha *= float(fragment["alpha"])
		_draw_single(copy, cell, origin, fit, front)


func end() -> void:
	for i in range(_used, _pool.size()):
		_pool[i].hide()


func clear() -> void:
	_pool.clear()
	_used = 0
