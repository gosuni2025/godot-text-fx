class_name TextFxGlyphRenderer
extends RefCounted
## 매 프레임에 필요한 글자 CanvasItem을 풀에서 얻는다. draw 순서가 앞/뒤/오버레이 순서다.

const GlyphCanvas := preload("res://addons/text_fx/render/fx_glyph_canvas.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")

var _pool: Array = []
var _used := 0
var _parent := RID()


func begin(parent: RID) -> void:
	_parent = parent
	_used = 0


func draw_glyph(st: GlyphState, sprite: Dictionary, origin: Vector2, fit: float, front: bool) -> void:
	var spr: Dictionary = sprite.get("blur", sprite) if st.ghost > 0.05 else sprite
	var tex: Texture2D = spr["texture_front"] if front else spr["texture"]
	if tex == null:
		return
	if _used == _pool.size():
		_pool.append(GlyphCanvas.new(_parent))
	var canvas: GlyphCanvas = _pool[_used]
	canvas.configure(st, spr, front, _used)
	Drawer.draw_glyph(canvas, st, spr, origin, fit, front)
	_used += 1


func end() -> void:
	for i in range(_used, _pool.size()):
		_pool[i].hide()


func clear() -> void:
	_pool.clear()
	_used = 0
