extends RefCounted
## Main-thread wall boundaries only: no GPU queries or rendering measurements.
enum Boundary { PHYSICS, PROCESS, PRE_DRAW, POST_DRAW }
const PHASES := ["physics_to_process", "process_to_pre_draw", "pre_to_post_draw", "post_draw_to_next_frame"]
const INVALID := -1
var scope_id := 0
var _tree: SceneTree
var _scope_provider: Callable
var _frame_id := -1
var _stage := INVALID
var _physics_usec := 0
var _process_usec := 0
var _pre_usec := 0
var _post_usec := 0
var _last_usec := 0
var _totals_usec := PackedInt64Array([0, 0, 0, 0])
var _max_usec := PackedInt64Array([0, 0, 0, 0])
var _count := 0
var _frame_physics_ticks := 0
var _physics_ticks := 0
var _work_max_usec := 0
var _work_over_16ms := 0
var _peak_work_frame := PackedInt64Array([-1, 0, 0, 0, 0, 0])
var _peak_render_usec := -1
var _peak_render_frame := PackedInt64Array([-1, 0, 0, 0, 0, 0])
var _web_metrics := preload("res://addons/web_profiler/web_frame_metrics.gd").new()
var process_roots := preload("res://addons/web_profiler/performance_process_roots.gd").new()
var process_slices := preload("res://addons/web_profiler/performance_process_slices.gd").new()
var physics_slices := preload("res://addons/web_profiler/performance_physics_slices.gd").new()

func bind(tree: SceneTree, provider: Callable) -> void:
	unbind()
	_tree = tree
	_scope_provider = provider
	_web_metrics.bind()
	_tree.physics_frame.connect(_on_physics)
	_tree.process_frame.connect(_on_process)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)

func unbind() -> void:
	process_roots.unbind()
	process_slices.unbind()
	physics_slices.unbind()
	_web_metrics.unbind()
	if is_instance_valid(_tree):
		if _tree.physics_frame.is_connected(_on_physics): _tree.physics_frame.disconnect(_on_physics)
		if _tree.process_frame.is_connected(_on_process): _tree.process_frame.disconnect(_on_process)
	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw): RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw): RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	_tree = null
	_scope_provider = Callable()
	set_scope(0)

func set_scope(value: int, blocked_frame := -1) -> void:
	scope_id = value
	discard_span(blocked_frame)
	_clear_totals()

func discard_span(blocked_frame := -1) -> void:
	if process_roots.enabled: process_roots.invalidate()
	if process_slices.enabled: process_slices.invalidate()
	if physics_slices.enabled: physics_slices.invalidate()
	_frame_id = blocked_frame
	_stage = INVALID
	_last_usec = 0
	_frame_physics_ticks = 0

func observe(boundary: Boundary, now_usec: int, frame_id: int, current_scope: int) -> void:
	if current_scope == 0 or current_scope != scope_id:
		discard_span(frame_id)
		return
	if frame_id != _frame_id:
		# The next frame's first callback closes the previous complete draw.
		# Frame IDs also prevent missing draws from turning into long idle gaps.
		var continuous := frame_id == _frame_id + 1 and _stage == Boundary.POST_DRAW \
			and now_usec >= _post_usec and (boundary == Boundary.PHYSICS or boundary == Boundary.PROCESS)
		if continuous: _accumulate(now_usec)
		discard_span(frame_id)
		if boundary == Boundary.PHYSICS:
			_physics_usec = now_usec
			_stage = Boundary.PHYSICS
			_frame_physics_ticks = 1
			if physics_slices.enabled: physics_slices.open_frame(frame_id, current_scope, now_usec)
		elif boundary == Boundary.PROCESS and continuous:
			# A continuous rendered frame can legitimately have zero fixed steps.
			_physics_usec = now_usec
			_process_usec = now_usec
			_stage = Boundary.PROCESS
			if physics_slices.enabled: physics_slices.open_zero_frame(frame_id, current_scope, now_usec)
		if _stage != INVALID and process_roots.enabled:
			process_roots.open_frame(frame_id, current_scope, now_usec)
		if _stage == Boundary.PROCESS and process_slices.enabled:
			process_slices.open_frame(frame_id, current_scope, now_usec)
		_last_usec = now_usec
		return
	if _stage == INVALID: return
	if now_usec < _last_usec:
		discard_span(frame_id)
		return
	_last_usec = now_usec
	if boundary == Boundary.PHYSICS and _stage == Boundary.PHYSICS:
		if physics_slices.enabled: physics_slices.next_tick(frame_id, current_scope, now_usec)
		_frame_physics_ticks += 1
		return
	if boundary != _stage + 1:
		discard_span(frame_id)
		return
	_stage = boundary
	match boundary:
		Boundary.PROCESS:
			_process_usec = now_usec
			if physics_slices.enabled: physics_slices.close_frame(frame_id, current_scope, now_usec)
			if process_slices.enabled: process_slices.open_frame(frame_id, current_scope, now_usec)
		Boundary.PRE_DRAW:
			_pre_usec = now_usec
			if process_slices.enabled: process_slices.close_frame(frame_id, current_scope, now_usec)
		Boundary.POST_DRAW:
			_post_usec = now_usec
			if process_roots.enabled: process_roots.close_frame(frame_id, current_scope, now_usec)

func _accumulate(next_frame_usec: int) -> void:
	# One completed frame's active wall span, excluding its following idle gap.
	var work_usec := _post_usec - _physics_usec
	if work_usec > 16000 and work_usec > _work_max_usec:
		process_roots.capture_peak(_frame_id, scope_id)
		process_slices.capture_peak(_frame_id, scope_id)
		physics_slices.capture_peak(_frame_id, scope_id, _frame_physics_ticks)
		_peak_work_frame[0] = _frame_id
		_peak_work_frame[1] = _frame_physics_ticks
		_peak_work_frame[2] = _process_usec - _physics_usec
		_peak_work_frame[3] = _pre_usec - _process_usec
		_peak_work_frame[4] = _post_usec - _pre_usec
		_peak_work_frame[5] = next_frame_usec - _post_usec
	_work_max_usec = maxi(_work_max_usec, work_usec)
	_work_over_16ms += int(work_usec > 16000)
	_add(0, _process_usec - _physics_usec)
	_add(1, _pre_usec - _process_usec)
	_add(2, _post_usec - _pre_usec)
	_add(3, next_frame_usec - _post_usec)
	_physics_ticks += _frame_physics_ticks
	if _post_usec - _pre_usec > _peak_render_usec:
		_peak_render_usec = _post_usec - _pre_usec
		_peak_render_frame[0] = _frame_id
		_peak_render_frame[1] = _frame_physics_ticks
		_peak_render_frame[2] = _process_usec - _physics_usec
		_peak_render_frame[3] = _pre_usec - _process_usec
		_peak_render_frame[4] = _post_usec - _pre_usec
		_peak_render_frame[5] = next_frame_usec - _post_usec
	_count += 1

func _add(index: int, elapsed: int) -> void:
	_totals_usec[index] += elapsed
	_max_usec[index] = maxi(_max_usec[index], elapsed)

func snapshot_and_reset() -> Dictionary:
	var result := {}
	for i in range(PHASES.size()):
		var prefix: String = "phase_" + PHASES[i]
		result[prefix + "_mean_ms"] = snappedf(float(_totals_usec[i]) / _count / 1000.0, 0.001) if _count > 0 else null
		result[prefix + "_max_ms"] = _max_usec[i] / 1000.0 if _count > 0 else null
		result[prefix + "_count"] = _count
	result["phase_physics_ticks"] = _physics_ticks
	result["phase_work_max_ms"] = _work_max_usec / 1000.0 if _count > 0 else null
	result["phase_work_over_16ms"] = _work_over_16ms
	# Unlike independent maxima, every part here belongs to the same rendered frame.
	result["phase_peak_render_frame"] = {"frame_id": _peak_render_frame[0], "physics_ticks": _peak_render_frame[1],
		"physics_ms": _peak_render_frame[2] / 1000.0, "process_ms": _peak_render_frame[3] / 1000.0,
		"render_ms": _peak_render_frame[4] / 1000.0, "gap_ms": _peak_render_frame[5] / 1000.0} if _count > 0 else null
	# Keep ordinary intervals small; only an over-budget frame needs attribution.
	if _work_max_usec > 16000:
		result["phase_peak_work_frame"] = {"frame_id": _peak_work_frame[0], "physics_ticks": _peak_work_frame[1],
			"physics_ms": _peak_work_frame[2] / 1000.0, "process_ms": _peak_work_frame[3] / 1000.0,
			"render_ms": _peak_work_frame[4] / 1000.0, "gap_ms": _peak_work_frame[5] / 1000.0}
		process_roots.append_peak(result.phase_peak_work_frame)
		process_slices.append_peak(result.phase_peak_work_frame)
		physics_slices.append_peak(result.phase_peak_work_frame)
	# The 1Hz counter runs inside _process, before this frame's draw callbacks.
	# Preserve that pending span while starting a fresh set of aggregate totals.
	_clear_totals()
	return result

func _clear_totals() -> void:
	# Reset the completed peak, never this frame's pending callback costs.
	process_roots.clear_peak()
	process_slices.clear_peak()
	physics_slices.clear_peak()
	_totals_usec.fill(0)
	_max_usec.fill(0)
	_count = 0
	_physics_ticks = 0
	_work_max_usec = 0
	_work_over_16ms = 0
	_peak_work_frame.fill(0)
	_peak_work_frame[0] = -1
	_peak_render_usec = -1
	_peak_render_frame.fill(0)
	_peak_render_frame[0] = -1

func _callback(boundary: Boundary) -> void:
	var current_scope: int = _scope_provider.call() if _scope_provider.is_valid() else 0
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	observe(boundary, now, frame, current_scope)
	_web_metrics.observe(boundary, frame, current_scope, now)

func _on_physics() -> void: _callback(Boundary.PHYSICS)
func _on_process() -> void: _callback(Boundary.PROCESS)
func _on_pre_draw() -> void: _callback(Boundary.PRE_DRAW)
func _on_post_draw() -> void: _callback(Boundary.POST_DRAW)
