extends RefCounted

## Engine CPU timings, in milliseconds. GLES3 viewport timestamps are delayed;
## never subtract them from this frame's pre/post-draw wall time as exclusive CPU.
var _enabled := false
var _viewports: Dictionary = {}
var _samples: Dictionary = {}


func track(viewport: Viewport, label: StringName) -> void:
	if _viewports.has(label):
		var previous = _viewports[label].get_ref()
		if previous == viewport: return
		if is_instance_valid(previous): RenderingServer.viewport_set_measure_render_time(previous.get_viewport_rid(), false)
	_viewports[label] = weakref(viewport)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), _enabled)


func set_enabled(active: bool) -> void:
	if _enabled:
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	_enabled = active
	_samples.clear()
	for label in _viewports:
		var viewport := (_viewports[label] as WeakRef).get_ref() as Viewport
		if is_instance_valid(viewport):
			RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), active)
	if _enabled:
		RenderingServer.frame_post_draw.connect(_on_post_draw)


func _on_post_draw() -> void:
	_record(&"setup_cpu_ms", RenderingServer.get_frame_setup_time_cpu())
	for label in _viewports:
		var viewport := (_viewports[label] as WeakRef).get_ref() as Viewport
		if not is_instance_valid(viewport) or not viewport.is_inside_tree():
			continue
		if viewport is SubViewport and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			continue
		_record(StringName(str(label) + "_cpu_delayed_ms"),
			RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))


func _record(label: StringName, value: float) -> void:
	if not _samples.has(label):
		_samples[label] = {"count": 0, "total": 0.0, "max": 0.0}
	var entry: Dictionary = _samples[label]
	entry["count"] += 1
	entry["total"] += value
	entry["max"] = maxf(entry["max"], value)


func snapshot_and_reset() -> Dictionary:
	var result := {}
	for label in _samples:
		var entry: Dictionary = _samples[label]
		result[str(label)] = {
			"mean": snappedf(float(entry["total"]) / int(entry["count"]), 0.01),
			"max": snappedf(entry["max"], 0.01), "count": entry["count"],
		}
	_samples.clear()
	return result


## Last completed root viewport frame, not an interval average.
static func pass_counts(viewport: Viewport) -> Dictionary:
	var result := {}
	var types := {"visible": Viewport.RENDER_INFO_TYPE_VISIBLE,
		"shadow": Viewport.RENDER_INFO_TYPE_SHADOW, "canvas": Viewport.RENDER_INFO_TYPE_CANVAS}
	for label in types:
		result[label] = [
			viewport.get_render_info(types[label], Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			viewport.get_render_info(types[label], Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
			viewport.get_render_info(types[label], Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		]
	return result

func retain(labels: Array) -> void:
	for label in _viewports.keys():
		if label in labels: continue
		var viewport = _viewports[label].get_ref()
		if is_instance_valid(viewport): RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
		_viewports.erase(label)

func clear() -> void:
	set_enabled(false)
	_viewports.clear()
