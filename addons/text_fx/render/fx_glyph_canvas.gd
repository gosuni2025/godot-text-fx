class_name TextFxGlyphCanvas
extends RefCounted
## 글자 하나의 CanvasItem. 같은 draw callback 안에서도 각 글자의 셰이더 값이 독립적이다.
## 노드나 프레임별 뷰포트 없이 RenderingServer CanvasItem을 재사용한다.

const ShaderFx := preload("res://addons/text_fx/render/shaders/fx_glyph_effect.gdshader")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")

var item := RID()
var material := ShaderMaterial.new()
var _transform := Transform2D.IDENTITY


func _init(parent: RID) -> void:
	item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, parent)
	RenderingServer.canvas_item_set_default_texture_filter(item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	material.shader = ShaderFx
	RenderingServer.canvas_item_set_material(item, material.get_rid())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and item.is_valid():
		RenderingServer.free_rid(item)


func configure(st: GlyphState, sprite: Dictionary, front: bool, index: int) -> void:
	RenderingServer.canvas_item_clear(item)
	RenderingServer.canvas_item_set_visible(item, true)
	RenderingServer.canvas_item_set_draw_index(item, index)
	var tex: Texture2D = sprite["texture_front"] if front else sprite["texture"]
	var ts := tex.get_size()
	var region: Rect2 = sprite["region"]
	var scale: float = sprite["scale"]
	var factor := (st.overlay_scale if st.overlay else 1.0) / scale
	var transform := Transform2D(st.rotation, st.scale * factor, 0.0, st.pos)
	var inverse := transform.affine_inverse() if absf(transform.determinant()) > 0.000001 else Transform2D.IDENTITY
	var x_delta := inverse.basis_xform(Vector2.RIGHT) / ts
	var glow: Texture2D = sprite.get("texture_glow") if not front else null
	material.set_shader_parameter("has_glow", glow != null)
	material.set_shader_parameter("glow_texture", glow)
	material.set_shader_parameter("glow_multiplier", maxf(0.0, st.glow_multiplier))
	material.set_shader_parameter("brightness", clampf(st.brightness, 0.0, 1.0))
	material.set_shader_parameter("blur_radius", maxf(0.0, st.ghost * scale))
	# rise의 방향은 문서 캔버스 기준이다. 세로쓰기에서 회전한 글자도 위아래로 흐려진다.
	var blur_direction := inverse.basis_xform(st.ghost_dir).normalized() if st.ghost_dir != Vector2.ZERO else Vector2.ZERO
	material.set_shader_parameter("blur_direction", blur_direction)
	material.set_shader_parameter("source_rect", Vector4(region.position.x / ts.x, region.position.y / ts.y, region.end.x / ts.x, region.end.y / ts.y))
	material.set_shader_parameter("canvas_x", Vector3(transform.x.x, transform.y.x, transform.origin.x))
	material.set_shader_parameter("canvas_y", Vector3(transform.x.y, transform.y.y, transform.origin.y))
	material.set_shader_parameter("canvas_x_to_uv", x_delta)
	material.set_shader_parameter("clip_enabled", st.clip_enabled)
	material.set_shader_parameter("clip_invert", st.clip_invert)
	material.set_shader_parameter("clip_rect", Vector4(st.clip_rect.position.x, st.clip_rect.position.y, st.clip_rect.end.x, st.clip_rect.end.y))
	material.set_shader_parameter("clip_feather", maxf(0.0, st.clip_feather))
	var n := mini(32, st.slices.size()) if st.slices_global else 0
	material.set_shader_parameter("slice_count", n)
	material.set_shader_parameter("slice_origin_y", st.slice_origin_y)
	material.set_shader_parameter("slice_height", maxf(0.001, st.slice_height))
	if n > 0:
		var offsets := st.slices.duplicate()
		offsets.resize(32)
		material.set_shader_parameter("slice_offsets", offsets)


func hide() -> void:
	RenderingServer.canvas_item_clear(item)
	RenderingServer.canvas_item_set_visible(item, false)


func draw_set_transform(origin: Vector2, rotation: float, scale: Vector2) -> void:
	draw_set_transform_matrix(Transform2D(rotation, scale, 0.0, origin))


func draw_set_transform_matrix(transform: Transform2D) -> void:
	_transform = transform


func draw_texture_rect_region(texture: Texture2D, rect: Rect2, region: Rect2, color: Color) -> void:
	# 전역 글리치가 셀 밖으로 옮긴 부분도 shader가 원래 셀 범위로 마스킹한다.
	# draw 명령의 transform은 VERTEX 자체에 합쳐질 수 있으므로 CanvasItem 변환으로 둔다.
	RenderingServer.canvas_item_set_transform(item, _transform)
	RenderingServer.canvas_item_add_texture_rect_region(item, rect, texture.get_rid(), region, color, false, false)
