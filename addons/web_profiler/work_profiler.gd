extends RefCounted
## Inclusive named work: nested measurements overlap. The label set is immutable
## for this collector; numeric enum slots cannot create unbounded arbitrary keys.
var enabled := false
var _names: PackedStringArray
var _work: Dictionary = {}

func _init(names: PackedStringArray = []) -> void:
	_names = names.duplicate()

func start() -> int:
	return Time.get_ticks_usec() if enabled else 0

func finish(slot: int, started: int, units: int = 1) -> void:
	if not enabled or started <= 0 or slot < 0 or slot >= _names.size(): return
	var label := _names[slot]
	var elapsed := maxi(0, Time.get_ticks_usec() - started)
	if not _work.has(label): _work[label] = {"calls": 0, "total_usec": 0, "max_usec": 0, "units": 0}
	var entry: Dictionary = _work[label]
	entry.calls += 1
	entry.total_usec += elapsed
	entry.max_usec = maxi(entry.max_usec, elapsed)
	entry.units += maxi(0, units)

func snapshot_and_reset() -> Dictionary:
	var result := {}
	for label in _work:
		var entry: Dictionary = _work[label]
		result[label] = {"calls": entry.calls, "units": entry.units,
			"total_ms": snappedf(entry.total_usec / 1000.0, 0.01),
			"max_ms": snappedf(entry.max_usec / 1000.0, 0.01)}
	reset()
	return result

func pending_snapshot() -> Dictionary:
	return _work.duplicate(true)

func reset() -> void: _work.clear()
