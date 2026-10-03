class_name TextFxBackgroundDrawer
extends RefCounted
## 프레임 배경을 Godot 기본 GradientTexture2D로 그린다. 호출자가 캔버스→표시 변환을 설정한다.

const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")
var _textures: Dictionary = {}


func draw(canvas: CanvasItem, background: Dictionary) -> void:
	if background.is_empty() or background.get("type", "none") == "none":
		return
	var rect := Rect2(Vector2.ZERO, background["canvas"])
	var color := Drawer.premul(background["color"], float(background["opacity"]))
	var type := str(background["type"])
	if type == "solid":
		canvas.draw_rect(rect, color)
		return
	var extent := clampf(float(background["extent"]), 0.01, 1.0)
	var key := "%s:%.4f" % [type, extent]
	if not _textures.has(key):
		# 설정을 오래 조절해도 이전 그라데이션 리소스가 무한히 쌓이지 않는다.
		if _textures.size() >= 16:
			_textures.clear()
		_textures[key] = _gradient(type, extent)
	canvas.draw_texture_rect(_textures[key], rect, false, color)


static func _gradient(type: String, extent: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 128
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	# 투명 픽셀의 RGB도 0으로 보간해야 PREMULT_ALPHA 재질에서 검은 띠가 생기지 않는다.
	if type == "vignette":
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		gradient.offsets = PackedFloat32Array([maxf(0.0, 1.0 - extent), 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color.WHITE])
	elif type == "top":
		gradient.offsets = PackedFloat32Array([0.0, extent])
		gradient.colors = PackedColorArray([Color.WHITE, Color(0, 0, 0, 0)])
	else:
		gradient.offsets = PackedFloat32Array([1.0 - extent, 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color.WHITE])
	texture.gradient = gradient
	return texture
