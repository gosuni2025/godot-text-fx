extends RefCounted
## Optional detailed interval diagnostics. No game classes, paths or node names.
const Phases = preload("res://addons/web_profiler/frame_phase_profiler.gd")
const Renderer = preload("res://addons/web_profiler/viewport_render_profiler.gd")
const Views = preload("res://addons/web_profiler/profile_viewports.gd")
const Work = preload("res://addons/web_profiler/work_profiler.gd")
const Counters = preload("res://addons/web_profiler/engine_counters.gd")
var _tree: SceneTree
var _phases := Phases.new()
var _renderer := Renderer.new()
var _work: Work
var _audio: Dictionary = {}
var _viewports: Dictionary = {}
var _views := Views.new()
var _webgl: JavaScriptObject
var _active := false

func bind(tree: SceneTree, work: Work) -> void:
	unbind()
	_tree = tree
	_work = work
	_phases.bind(tree)
	_track_existing(tree.root)
	tree.node_added.connect(_track)
	if OS.has_feature("web"):
		_webgl = JavaScriptBridge.get_interface("GodotProfilerRenderProbe")
		if _webgl == null: push_error("Detailed profiling requires the detailed web bundle")

func set_views(views: Views) -> void:
	var labels: Array = [&"root"]
	for label in views.diagnostics:
		if is_instance_valid(views.diagnostics[label]): labels.append(label)
	_renderer.retain(labels)
	_views = views
	_renderer.track(_tree.root, &"root")
	for label in views.diagnostics:
		var viewport: Viewport = views.diagnostics[label]
		if is_instance_valid(viewport): _renderer.track(viewport, label)

func set_active(value: bool) -> void:
	if _active == value: return
	_active = value
	_phases.set_enabled(value)
	_renderer.set_enabled(value)
	if _work != null:
		_work.enabled = value
		_work.reset()
	if _webgl != null: _webgl.setEnabled(value)

func discard_interval() -> void:
	_phases.snapshot_and_reset()
	_renderer.snapshot_and_reset()
	if _work != null: _work.reset()
	if _webgl != null: _webgl.snapshotJSON()

func snapshot_and_reset(span_usec: int) -> Dictionary:
	if _tree == null: return {}
	var root := _tree.root
	var scene := _tree.current_scene
	var texture_size := Vector2i(root.get_texture().get_size())
	var pixels := Counters.physical_size(root)
	var result := {"sample_span_ms": snappedf(span_usec / 1000.0, 0.01),
		"phases": _phases.snapshot_and_reset(), "renderer": _renderer.snapshot_and_reset(),
		"render_passes": Renderer.pass_counts(root),
		"scene": scene.scene_file_path.left(256) if scene != null and scene.scene_file_path.begins_with("res://") else "",
		"paused": _tree.paused, "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"render_target_px": [texture_size.x, texture_size.y], "viewport_raster_px": [pixels.x, pixels.y],
		"msaa_3d": root.msaa_3d, "viewport_count": _count_valid(_viewports),
		"playing_audio": _count_valid(_audio, true),
		"audio_latency_ms": snappedf(AudioServer.get_output_latency() * 1000.0, 0.01)}
	if _work != null: result["work"] = _work.snapshot_and_reset()
	if _webgl != null:
		var parsed: Variant = JSON.parse_string(str(_webgl.snapshotJSON()))
		if parsed is Dictionary: result["webgl"] = parsed
	for label in _views.diagnostics:
		var viewport: Viewport = _views.diagnostics[label]
		var exists := is_instance_valid(viewport) and viewport.is_inside_tree()
		var active: bool = exists and (not viewport is SubViewport or viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED)
		var size := Counters.physical_size(viewport) if exists else Vector2i.ZERO
		result[str(label) + "_active"] = active
		result[str(label) + "_render_target_px"] = [size.x, size.y]
		result[str(label) + "_scale_3d"] = viewport.scaling_3d_scale if exists else null
		result[str(label) + "_msaa_3d"] = viewport.msaa_3d if exists else null
		result[str(label) + "_draw_calls"] = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) if active else 0
	return result

func _track_existing(node: Node) -> void:
	_track(node)
	for child in node.get_children(): _track_existing(child)

func _track(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		_audio[node.get_instance_id()] = weakref(node)
	elif node is Viewport: _viewports[node.get_instance_id()] = weakref(node)

func _count_valid(registry: Dictionary, playing_only := false) -> int:
	var count := 0
	for id in registry.keys():
		var node = registry[id].get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree(): registry.erase(id)
		elif not playing_only or node.playing: count += 1
	return count

func unbind() -> void:
	set_active(false)
	if _tree != null and _tree.node_added.is_connected(_track): _tree.node_added.disconnect(_track)
	_renderer.clear()
	_tree = null
	_work = null
	_webgl = null
	_audio.clear()
	_viewports.clear()
	_views = Views.new()
