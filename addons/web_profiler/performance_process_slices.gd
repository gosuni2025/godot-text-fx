extends RefCounted
## Main process-group wall slices, not exclusive script costs or GPU time.
## The current project uses only the default group. Explicit groups and priority
## collisions disable this optional probe instead of mislabelling partial work.
const NAMES := ["process_before_nodes_ms", "process_nodes_ms", "process_after_nodes_ms"]
const FIRST_PRIORITY := -2147483648
const LAST_PRIORITY := 2147483647
var enabled := false
var active_token := 0
var _serial := 0
var _frame := -1
var _scope := 0
var _closed := false
# Process signal, first node, last node, pre-draw. No per-frame allocation.
var _times := PackedInt64Array([-1, -1, -1, -1])
var _peak := PackedInt64Array([0, 0, 0])
var _peak_available := false
var _tree: SceneTree
var _arena: WeakRef
var _first: Node
var _last: Node

class Marker extends Node:
	var probe: WeakRef
	var last := false
	func _process(_delta: float) -> void:
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
		and node.process_priority != FIRST_PRIORITY and node.process_priority != LAST_PRIORITY)

func _on_node_added(node: Node) -> void:
	if not _supported(node): unbind()

func _add_marker(arena: Node, last: bool) -> Node:
	var marker := Marker.new()
	marker.name = "PerformanceProcessLast" if last else "PerformanceProcessFirst"
	marker.process_mode = Node.PROCESS_MODE_ALWAYS
	marker.process_priority = LAST_PRIORITY if last else FIRST_PRIORITY
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
			marker.set_process(false)
			marker.queue_free()
	_first = null
	_last = null
	_tree = null
	_arena = null
	enabled = false
	invalidate()
	clear_peak()

func open_frame(frame: int, scope: int, process_usec: int) -> void:
	invalidate()
	if not enabled or scope == 0: return
	_serial += 1
	active_token = _serial
	_frame = frame
	_scope = scope
	_times[0] = process_usec

func mark(last: bool, token: int, now_usec: int, frame: int) -> void:
	if not enabled or token == 0 or token != active_token or frame != _frame: return
	var index := 2 if last else 1
	# Missing, repeated or reversed markers are unknown, never zero-cost samples.
	if _times[index] >= 0 or _times[index - 1] < 0 or now_usec < _times[index - 1]:
		invalidate()
		return
	_times[index] = now_usec

func close_frame(frame: int, scope: int, pre_usec: int) -> void:
	active_token = 0
	_closed = enabled and _frame == frame and _scope == scope and _times[2] >= 0 and pre_usec >= _times[2]
	if _closed: _times[3] = pre_usec

func capture_peak(frame: int, scope: int) -> void:
	_peak_available = enabled and _closed and _frame == frame and _scope == scope
	if _peak_available:
		for i in range(3): _peak[i] = _times[i + 1] - _times[i]

func append_peak(target: Dictionary) -> void:
	if _peak_available:
		for i in range(3): target[NAMES[i]] = _peak[i] / 1000.0

func invalidate() -> void:
	active_token = 0
	_frame = -1
	_scope = 0
	_closed = false
	_times.fill(-1)

func clear_peak() -> void:
	_peak_available = false
	_peak.fill(0)
