extends RefCounted
## Independent callback bodies, not all process work, AI physics or GPU time.
## Each FramePhases instance owns its probe; no global recorder or per-frame maps.
var names: PackedStringArray
var enabled := false
var active_token := 0
var _serial := 0
var _frame := -1
var _scope := 0
var _first_usec := 0
var _last_end_usec := 0
var _closed := false
var _valid := false
var _values := PackedInt64Array()
var _peak := PackedInt64Array()
var _peak_available := false
var _nodes: Array[WeakRef] = []
var _pending_slot := -1
var _pending_token := 0
var _pending_started_usec := 0

func _init(metric_names: PackedStringArray = []) -> void:
	names = metric_names.duplicate()
	_values.resize(names.size() * 2)
	_peak.resize(names.size() * 2)

func bind_nodes(nodes: Array[Node]) -> bool:
	unbind()
	if names.is_empty() or nodes.size() != names.size(): return false
	# A second QA reporter must never replace the live reporter's node references.
	for node in nodes:
		if not is_instance_valid(node) or node.get("performance_roots") != null: return false
	for node in nodes:
		node.set("performance_roots", self)
		_nodes.append(weakref(node))
	enabled = true
	return true

func unbind() -> void:
	for reference in _nodes:
		var node = reference.get_ref()
		if is_instance_valid(node) and node.get("performance_roots") == self:
			node.set("performance_roots", null)
	_nodes.clear()
	enabled = false
	invalidate()
	clear_peak()

func open_frame(frame: int, scope: int, first_usec: int) -> void:
	invalidate()
	if not enabled or scope == 0: return
	_serial += 1
	active_token = _serial
	_frame = frame
	_scope = scope
	_first_usec = first_usec
	_last_end_usec = first_usec
	_valid = true

func record(slot: int, token: int, started_usec: int, ended_usec: int, frame := -1) -> void:
	if token == 0 or token != active_token or not enabled or _scope == 0 or not _valid: return
	var current_frame := Engine.get_process_frames() if frame < 0 else frame
	if current_frame != _frame or slot < 0 or slot >= names.size(): return
	# Callback bodies are synchronous and independent. Reject accidental nesting
	# or bad clocks instead of reporting overlapping roots as additive costs.
	if started_usec < _last_end_usec or ended_usec < started_usec:
		invalidate()
		return
	_values[slot] += ended_usec - started_usec
	_values[slot + names.size()] += 1
	_last_end_usec = ended_usec

# The measured callback must be synchronous. Only its matching
# tail may end this slot; an invalidated callback cannot resume in a later frame.
func begin_slot(slot: int) -> void:
	if _pending_token != 0:
		invalidate()
		return
	if active_token == 0 or not enabled: return
	if Engine.get_process_frames() != _frame:
		invalidate()
		return
	_pending_slot = slot
	_pending_token = active_token
	_pending_started_usec = Time.get_ticks_usec()

func end_slot() -> void:
	if _pending_token == 0: return
	if Engine.get_process_frames() != _frame:
		invalidate()
		return
	var token := _pending_token
	_pending_token = 0
	record(_pending_slot, token, _pending_started_usec, Time.get_ticks_usec())

func close_frame(frame: int, scope: int, ended_usec: int) -> void:
	if _pending_token != 0:
		invalidate()
		return
	active_token = 0
	_closed = _valid and _frame == frame and _scope == scope and _last_end_usec <= ended_usec

func capture_peak(frame: int, scope: int) -> void:
	_peak_available = enabled and _valid and _closed and _frame == frame and _scope == scope
	if _peak_available:
		for i in range(_values.size()): _peak[i] = _values[i]

func append_peak(target: Dictionary) -> void:
	if not _peak_available: return
	for i in range(names.size()): target[names[i]] = _peak[i] / 1000.0
	var counts: Array[int] = []
	for i in range(names.size()): counts.append(_peak[i + names.size()])
	target["root_call_counts"] = counts

func invalidate() -> void:
	active_token = 0
	_frame = -1
	_scope = 0
	_closed = false
	_valid = false
	_pending_token = 0
	_pending_started_usec = 0
	_values.fill(0)

func clear_peak() -> void:
	_peak_available = false
	_peak.fill(0)
