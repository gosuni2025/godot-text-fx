extends RefCounted
## Default-group physics wall slices, not solver-only timing.
## A frame can contain zero, one, or several complete physics ticks.
const NAMES := ["physics_before_nodes_ms", "physics_nodes_ms", "physics_after_nodes_ms"]
const FIRST_PRIORITY := -2147483648
const LAST_PRIORITY := 2147483647
var enabled := false
var active_token := 0
var _serial := 0
var _frame := -1
var _scope := 0
var _valid := false
var _closed := false
var _ticks := 0
var _completed_ticks := 0
var _frame_start_usec := -1
var _frame_end_usec := -1
# Current tick: signal, first node, last node. Totals span the whole render frame.
var _times := PackedInt64Array([-1, -1, -1])
var _totals := PackedInt64Array([0, 0, 0])
var _peak := PackedInt64Array([0, 0, 0])
var _peak_available := false
var _tree: SceneTree
var _arena: WeakRef
var _first: Node
var _last: Node

class Marker extends Node:
	var probe: WeakRef
	var last := false
	func _physics_process(_delta: float) -> void:
		var target = probe.get_ref()
		if target != null and target.active_token != 0:
			target.mark(last, target.active_token, Time.get_ticks_usec(), Engine.get_process_frames())

func bind_arena(arena: Node) -> bool:
	unbind()
	if not is_instance_valid(arena) or not arena.is_inside_tree(): return false
	var tree := arena.get_tree()
	if not _supported(tree.root): return false
	for node in tree.root.find_children("*", "", true, false):
		if not _supported(node): return false
	_tree = tree
	_arena = weakref(arena)
	_first = _add_marker(arena, false)
	_last = _add_marker(arena, true)
	_tree.node_added.connect(_on_node_added)
	arena.tree_exiting.connect(unbind, CONNECT_ONE_SHOT)
	enabled = true
	return true

func _supported(node: Node) -> bool:
	return node.is_queued_for_deletion() or (node.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT \
		and node.process_physics_priority != FIRST_PRIORITY and node.process_physics_priority != LAST_PRIORITY)

func _on_node_added(node: Node) -> void:
	if not _supported(node): unbind()

func _add_marker(arena: Node, last: bool) -> Node:
	var marker := Marker.new()
	marker.name = "PerformancePhysicsLast" if last else "PerformancePhysicsFirst"
	marker.process_mode = Node.PROCESS_MODE_ALWAYS
	marker.process_physics_priority = LAST_PRIORITY if last else FIRST_PRIORITY
	marker.set_meta("performance_probe", "physics_slices")
	marker.probe = weakref(self)
	marker.last = last
	arena.add_child(marker)
	return marker

func unbind() -> void:
	if is_instance_valid(_tree) and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	var arena = _arena.get_ref() if _arena != null else null
	if is_instance_valid(arena) and arena.tree_exiting.is_connected(unbind): arena.tree_exiting.disconnect(unbind)
	for marker in [_first, _last]:
		if is_instance_valid(marker):
			marker.set_physics_process(false)
			marker.queue_free()
	_first = null
	_last = null
	_tree = null
	_arena = null
	enabled = false
	invalidate()
	clear_peak()

func open_frame(frame: int, scope: int, physics_usec: int) -> void:
	invalidate()
	if not enabled or scope == 0 or frame < 0 or physics_usec < 0: return
	_frame = frame
	_scope = scope
	_valid = true
	_frame_start_usec = physics_usec
	_open_tick(physics_usec)

func _open_tick(now_usec: int) -> void:
	_serial += 1
	active_token = _serial
	_ticks += 1
	_times.fill(-1)
	_times[0] = now_usec

func next_tick(frame: int, scope: int, physics_usec: int) -> void:
	# The next physics signal closes the previous tick's complete residual.
	# An invalid tick invalidates the entire render frame; never sum partial ticks.
	if not _matches(frame, scope) or _closed or not _finish_tick(physics_usec):
		invalidate()
		return
	_open_tick(physics_usec)

func mark(last: bool, token: int, now_usec: int, frame: int) -> void:
	# Old/unbound/deferred tokens are inert. A current token cannot change frames.
	if not enabled or token == 0 or token != active_token: return
	if not _valid or _closed or frame != _frame:
		invalidate()
		return
	var index := 2 if last else 1
	if _times[index] >= 0 or _times[index - 1] < 0 or now_usec < _times[index - 1]:
		invalidate()
		return
	_times[index] = now_usec

func _finish_tick(end_usec: int) -> bool:
	if active_token == 0 or _times[2] < 0 or end_usec < _times[2]: return false
	_totals[0] += _times[1] - _times[0]
	_totals[1] += _times[2] - _times[1]
	_totals[2] += end_usec - _times[2]
	_completed_ticks += 1
	active_token = 0
	return true

func close_frame(frame: int, scope: int, process_usec: int) -> void:
	if not _matches(frame, scope) or _closed or not _finish_tick(process_usec):
		invalidate()
		return
	_frame_end_usec = process_usec
	_closed = _ticks == _completed_ticks and _totals[0] + _totals[1] + _totals[2] == process_usec - _frame_start_usec
	if not _closed: invalidate()

func open_zero_frame(frame: int, scope: int, process_usec: int) -> void:
	# Only Phases may call this after a continuous previous POST_DRAW. Missing
	# physics callbacks at startup/pause/discontinuity must not be labelled zero.
	invalidate()
	if not enabled or scope == 0 or frame < 0 or process_usec < 0: return
	_frame = frame
	_scope = scope
	_frame_start_usec = process_usec
	_frame_end_usec = process_usec
	_valid = true
	_closed = true

func _matches(frame: int, scope: int) -> bool:
	return enabled and _valid and scope != 0 and frame == _frame and scope == _scope

func capture_peak(frame: int, scope: int, expected_ticks := -1) -> void:
	_peak_available = _matches(frame, scope) and _closed and _ticks == _completed_ticks \
		and (expected_ticks < 0 or _ticks == expected_ticks)
	if _peak_available:
		for i in range(3): _peak[i] = _totals[i]

func append_peak(target: Dictionary) -> void:
	if _peak_available:
		for i in range(3): target[NAMES[i]] = _peak[i] / 1000.0

func invalidate() -> void:
	active_token = 0
	_frame = -1
	_scope = 0
	_valid = false
	_closed = false
	_ticks = 0
	_completed_ticks = 0
	_frame_start_usec = -1
	_frame_end_usec = -1
	_times.fill(-1)
	_totals.fill(0)

func clear_peak() -> void:
	_peak_available = false
	_peak.fill(0)
