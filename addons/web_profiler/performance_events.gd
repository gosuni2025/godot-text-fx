extends RefCounted
## Only fixed event codes and allowlisted diagnostic scalar fields are retained.
const MAX_EVENTS := 128
var interactions: PackedStringArray = []
var root_names: PackedStringArray = []
var extra_keys: PackedStringArray = []
const KEYS := ["map_id", "state", "reason", "error_type", "line", "script", "function", "http_code", "result", "attempt", "count", "duration_ms", "loading",
	"interval_start_session_ms", "sample_phase", "interaction",
	"frame_id", "physics_ticks", "physics_ms", "process_ms", "render_ms", "gap_ms", "physics_before_nodes_ms",
	"physics_nodes_ms", "physics_after_nodes_ms", "process_before_nodes_ms", "process_nodes_ms", "process_after_nodes_ms", "root_name", "root_ms"]
var entries: Array[Dictionary] = []
var origin_usec := Time.get_ticks_usec()
var dropped := 0

func record(event: String, data := {}, level := "info", at_usec := -1) -> void:
	if not _code(event, 128) or level not in ["debug", "info", "warn", "error"]: return
	if at_usec < 0: at_usec = Time.get_ticks_usec()
	var safe := {}
	for key in data:
		if safe.size() >= 16: break
		if str(key) not in KEYS and str(key) not in extra_keys: continue
		var value: Variant = data[key]
		if key == "interaction" and (not value is String or value not in interactions): continue
		if key == "sample_phase" and (not value is String or value != "frame_end"): continue
		if key == "root_name" and (not value is String or value not in root_names): continue
		if value is bool or value is int: safe[key] = value
		elif value is float and is_finite(value): safe[key] = value
		elif value is String:
			if key == "script":
				if value.begins_with("res://") and not value.contains("..") and value.length() <= 256: safe[key] = value
			elif _code(value, 128): safe[key] = value
	entries.append({"offset_ms": maxi(0, at_usec - origin_usec) / 1000.0,
		"level": level, "event": event, "data": safe})
	if entries.size() > MAX_EVENTS:
		entries.pop_front()
		dropped += 1

func snapshot() -> Array:
	return entries.duplicate(true)

static func _code(value: String, limit: int) -> bool:
	if value.is_empty() or value.length() > limit: return false
	for character in value:
		if not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_.:-": return false
	return true
