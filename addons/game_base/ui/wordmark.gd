@tool
extends Control
## A CanvasGroup shades only the actual font glyphs, never the title background.
@export_multiline var text := "MY GAME":
	set(value):
		text = value
		if is_node_ready(): $Effect/Title.text = value
@export_range(8, 120) var font_size := 28:
	set(value):
		font_size = value
		if is_node_ready(): $Effect/Title.add_theme_font_size_override("font_size", value)
var effect_material: ShaderMaterial
var _tween: Tween
var _config: Resource

func _ready() -> void:
	_config = preload("res://addons/game_base/project_config.gd").current()
	font_size = roundi(font_size * _config.title_size_multiplier)
	custom_minimum_size.y = font_size * 1.35
	$Effect/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _config.title_centered else HORIZONTAL_ALIGNMENT_LEFT
	$Effect/Title.text = text
	$Effect/Title.add_theme_font_size_override("font_size", font_size)
	if _config.title_material != null:
		effect_material = _config.title_material.duplicate()
		$Effect.material = effect_material
	resized.connect(_layout)
	visibility_changed.connect(_animate)
	_layout()
	_animate()

func _layout() -> void:
	$Effect/Title.size = size.max(Vector2.ONE)
	if effect_material != null: effect_material.set_shader_parameter("rect_size", size.max(Vector2.ONE))

func _animate() -> void:
	if _tween != null: _tween.kill()
	_tween = null
	if effect_material == null: return
	_progress(-0.2)
	if not is_visible_in_tree() or Engine.is_editor_hint(): return
	# Headless rendering cannot always resolve a shader's default uniforms.
	# Null therefore keeps the shader's default enabled state.
	var motion = effect_material.get_shader_parameter("motion_enabled")
	if motion != null and float(motion) <= 0: return
	_tween = create_tween().set_loops()
	_tween.tween_interval(maxf(0.01, _config.sweep_delay))
	_tween.tween_method(_progress, 0.0, 1.0, maxf(0.05, _config.sweep_duration)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_progress.bind(-0.2))
	_tween.tween_interval(maxf(0.01, _config.sweep_rest))

func _progress(value: float) -> void:
	effect_material.set_shader_parameter("sweep_progress", value)
