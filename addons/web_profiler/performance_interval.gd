extends RefCounted
## One continuous map segment. Only numeric accumulation runs for every frame.
const REPORT_USEC := 1_000_000
const SLOW_FRAME_USEC := 100_000
var map_id := ""
var start_usec := -1
var last_usec := -1
var frame_count := 0
var elapsed_usec := 0
var max_frame_usec := 0
var slow_at_usec := -1
var slow_context: Dictionary = {}

func begin(now_usec: int, map: String) -> void:
	reset()
	map_id = map
	start_usec = now_usec
	last_usec = now_usec

func reset() -> void:
	map_id = ""
	start_usec = -1
	last_usec = -1
	frame_count = 0
	elapsed_usec = 0
	max_frame_usec = 0
	slow_at_usec = -1
	slow_context.clear()

func record_frame(now_usec: int) -> bool:
	if last_usec < 0 or now_usec <= last_usec: return false
	var duration := now_usec - last_usec
	last_usec = now_usec
	frame_count += 1
	elapsed_usec += duration
	if duration <= max_frame_usec: return false
	max_frame_usec = duration
	if duration < SLOW_FRAME_USEC: return false
	slow_at_usec = now_usec
	return true # Capture context only when a slow interval maximum changes.

func is_due() -> bool:
	return elapsed_usec >= REPORT_USEC

func counters(origin_usec: int) -> Dictionary:
	return {"map_id": map_id, "interval_start_session_ms": maxi(0, start_usec - origin_usec) / 1000.0,
		"interval_frame_count": frame_count, "interval_elapsed_ms": elapsed_usec / 1000.0,
		"interval_max_frame_ms": max_frame_usec / 1000.0}

func take_slow_frame(origin_usec: int) -> Dictionary:
	if slow_at_usec < 0: return {}
	var data := slow_context.duplicate()
	data["map_id"] = map_id
	data["duration_ms"] = max_frame_usec / 1000.0
	data["interval_start_session_ms"] = maxi(0, start_usec - origin_usec) / 1000.0
	data["sample_phase"] = "frame_end"
	var event := {"at_usec": slow_at_usec, "data": data}
	slow_at_usec = -1
	slow_context.clear()
	return event
