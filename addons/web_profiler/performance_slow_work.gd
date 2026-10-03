extends RefCounted
## Rare completed-frame evidence. The event timestamp is the interval end,
## not this frame's start/end; it is independent of inter-process slow_frame.
const MIN_WORK_USEC := 100_000
const PARTS := ["physics_ms", "process_ms", "render_ms", "gap_ms"]
const SLICES := ["physics_before_nodes_ms", "physics_nodes_ms", "physics_after_nodes_ms",
	"process_before_nodes_ms", "process_nodes_ms", "process_after_nodes_ms"]

static func record(phases: Dictionary, interval: RefCounted, events: RefCounted) -> void:
	var peak: Variant = phases.get("phase_peak_work_frame")
	if not peak is Dictionary or interval.frame_count <= 0: return
	for key in PARTS:
		if not _nonnegative_number(peak.get(key)): return
	# Values originate in integer microseconds. Recover that precision for the
	# inclusive threshold instead of letting floating point sums exclude 100ms.
	var work_usec := roundi(float(peak.physics_ms) * 1000.0) \
		+ roundi(float(peak.process_ms) * 1000.0) + roundi(float(peak.render_ms) * 1000.0)
	if work_usec < MIN_WORK_USEC: return
	if not peak.get("frame_id") is int or peak.frame_id < 0 \
		or not peak.get("physics_ticks") is int or peak.physics_ticks < 0: return
	# Only the rare branch allocates a dictionary; roots/slices remain optional.
	var data := {"map_id": interval.map_id,
		"interval_start_session_ms": maxi(0, interval.start_usec - events.origin_usec) / 1000.0,
		"frame_id": peak.frame_id, "physics_ticks": peak.physics_ticks}
	for key in PARTS: data[key] = peak[key]
	for key in SLICES:
		if _nonnegative_number(peak.get(key)): data[key] = peak[key]
	var root_name := ""
	var root_ms := -1.0
	for key in events.root_names:
		var value: Variant = peak.get(key)
		if _nonnegative_number(value) and float(value) > root_ms:
			root_name = key
			root_ms = float(value)
	if not root_name.is_empty():
		data["root_name"] = root_name
		data["root_ms"] = root_ms
	events.record("slow_work_frame", data, "info", interval.last_usec)

static func _nonnegative_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0
