extends RefCounted

## These are main-thread wall-clock boundaries, not GPU execution timestamps.
const PHASES := [
	&"physics_to_process_ms", &"process_to_pre_draw_ms", &"pre_to_post_draw_ms",
	&"post_draw_to_next_frame_ms",
]
const MAX_SAMPLES_PER_PHASE := 2048

var _tree: SceneTree
var _enabled := false
var _physics_started := 0
var _process_started := 0
var _draw_started := 0
var _draw_finished := 0
var _samples: Dictionary = {}


func bind(tree: SceneTree) -> void:
	set_enabled(false)
	_tree = tree


func set_enabled(active: bool) -> void:
	if _enabled:
		_tree.physics_frame.disconnect(_on_physics_frame)
		_tree.process_frame.disconnect(_on_process_frame)
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	_enabled = active and _tree != null
	reset()
	if _enabled:
		_tree.physics_frame.connect(_on_physics_frame)
		_tree.process_frame.connect(_on_process_frame)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
		RenderingServer.frame_post_draw.connect(_on_post_draw)


func reset() -> void:
	_physics_started = 0
	_process_started = 0
	_draw_started = 0
	_draw_finished = 0
	_samples.clear()


func snapshot_and_reset() -> Dictionary:
	var result: Dictionary = {}
	for phase in PHASES:
		var values: Array = _samples.get(phase, [])
		if values.is_empty():
			result[str(phase)] = {"mean": null, "p95": null, "max": null, "count": 0}
			continue
		var total := 0
		for value in values:
			total += int(value)
		values.sort()
		result[str(phase)] = {
			"mean": snappedf(float(total) / values.size() / 1000.0, 0.01),
			"p95": snappedf(float(values[ceili(values.size() * 0.95) - 1]) / 1000.0, 0.01),
			"max": snappedf(float(values.back()) / 1000.0, 0.01),
			"count": values.size(),
		}
	# Keep current frame boundaries: the 1Hz reporter runs inside _process(),
	# before that frame's pre/post-draw callbacks have completed.
	_samples.clear()
	return result


func _on_physics_frame() -> void:
	_finish_frame_gap()
	if _physics_started == 0:
		_physics_started = Time.get_ticks_usec()


func _on_process_frame() -> void:
	_finish_frame_gap()
	var now := Time.get_ticks_usec()
	if _physics_started > 0:
		_record(&"physics_to_process_ms", now - _physics_started)
	_physics_started = 0
	_process_started = now


func _on_pre_draw() -> void:
	var now := Time.get_ticks_usec()
	if _process_started > 0:
		_record(&"process_to_pre_draw_ms", now - _process_started)
	_process_started = 0
	_draw_started = now


func _on_post_draw() -> void:
	var now := Time.get_ticks_usec()
	if _draw_started > 0:
		_record(&"pre_to_post_draw_ms", now - _draw_started)
	_draw_started = 0
	_draw_finished = now


func _finish_frame_gap() -> void:
	# Includes presentation, browser scheduling and input before SceneTree resumes;
	# it must not be interpreted as a GPU timer or counted twice during physics.
	if _draw_finished > 0:
		_record(&"post_draw_to_next_frame_ms", Time.get_ticks_usec() - _draw_finished)
		_draw_finished = 0


func _record(phase: StringName, elapsed: int) -> void:
	if not _samples.has(phase):
		_samples[phase] = []
	var values: Array = _samples[phase]
	if values.size() < MAX_SAMPLES_PER_PHASE:
		values.append(maxi(0, elapsed))
