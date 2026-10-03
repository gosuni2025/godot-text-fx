extends RefCounted
## Fixed wall-time buckets retain the full horizon even above 60 FPS.
const WINDOW_USEC := 30_000_000
const BUCKET_USEC := 20_000
const MAX_BUCKETS := 1501
const MAX_COUNTERS := 30
var _bins: Array = []
var _counters: Array[Dictionary] = []
var _last_usec := 0

func _init() -> void:
	_bins.resize(MAX_BUCKETS)

func clear() -> void:
	_bins.clear()
	_bins.resize(MAX_BUCKETS)
	_counters.clear()
	_last_usec = 0

func record_frame(now_usec: int, elapsed_usec: int) -> void:
	if elapsed_usec <= 0 or elapsed_usec > WINDOW_USEC: return
	var tick := now_usec / BUCKET_USEC
	var index := posmod(tick, MAX_BUCKETS)
	var value: float = elapsed_usec / 1000.0
	if _bins[index] == null or _bins[index].tick != tick:
		_bins[index] = {"tick": tick, "first": now_usec - elapsed_usec, "last": now_usec,
			"count": 0, "total": 0.0, "max": 0.0, "over_16_67": 0, "over_33_33": 0, "over_50": 0}
	var bucket: Dictionary = _bins[index]
	bucket.last = now_usec
	bucket.count += 1
	bucket.total += value
	bucket.max = maxf(bucket.max, value)
	bucket.over_16_67 += int(elapsed_usec > 16667)
	bucket.over_33_33 += int(elapsed_usec > 33333)
	bucket.over_50 += int(elapsed_usec > 50000)
	_last_usec = now_usec

func record_counters(now_usec: int, values: Dictionary) -> void:
	var sample := values.duplicate(true)
	sample["_at_usec"] = now_usec
	_counters.append(sample)
	if _counters.size() > MAX_COUNTERS: _counters.pop_front()

func snapshot(now_usec: int, freeze_at_last_frame := false) -> Dictionary:
	var end := mini(now_usec, _last_usec) if freeze_at_last_frame and _last_usec > 0 else now_usec
	var cutoff := end - WINDOW_USEC
	var buckets: Array[Dictionary] = []
	for bucket in _bins:
		# Exclude the boundary bucket: represented intervals never exceed 30 seconds.
		if bucket != null and bucket.first >= cutoff and bucket.last <= end: buckets.append(bucket)
	buckets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.tick < b.tick)
	var samples: Array[float] = []
	var count := 0
	var total := 0.0
	var peak := 0.0
	var slow := {"over_16_67": 0, "over_33_33": 0, "over_50": 0}
	for bucket in buckets:
		count += bucket.count
		total += bucket.total
		peak = maxf(peak, bucket.max)
		for key in slow: slow[key] += bucket[key]
		samples.append(snappedf(bucket.total / bucket.count, 0.01))
	var start: int = buckets[0].first if not buckets.is_empty() else end
	var counters: Array[Dictionary] = []
	for entry in _counters:
		if entry._at_usec < start or entry._at_usec > end: continue
		if entry.has("interval_elapsed_ms"):
			# Only whole intervals belong to this frame window. A counter ending
			# exactly at its start still represents earlier, excluded gameplay.
			var interval_start: int = entry._at_usec - roundi(float(entry.interval_elapsed_ms) * 1000.0)
			if interval_start < start: continue
		var sample := entry.duplicate(true)
		sample.offset_ms = snappedf((entry._at_usec - start) / 1000.0, 0.01)
		sample.erase("_at_usec")
		counters.append(sample)
	return {"window": {"duration_ms": (end - start) / 1000.0, "active_elapsed_ms": snappedf(total, 0.01),
		"end_age_ms": maxi(0, now_usec - end) / 1000.0, "frame_count": count,
		"mean_fps": snappedf(count * 1000.0 / total, 0.01) if total > 0 else 0.0,
		"max_frame_ms": snappedf(peak, 0.01), "slow_frames": slow,
		"sample_kind": "mean_frame_ms_per_20ms_wall_bucket", "sample_bucket_ms": 20,
		"bucket_mean_ms_percentiles": _percentiles(samples), "samples": samples,
		"start_tick_ms": start / 1000.0, "end_tick_ms": end / 1000.0}, "counters": counters}

static func _percentiles(samples: Array[float]) -> Dictionary:
	if samples.is_empty(): return {"median": null, "p95": null}
	var sorted := samples.duplicate()
	sorted.sort()
	var count := sorted.size()
	var median: float = sorted[count / 2]
	if count % 2 == 0: median = (sorted[count / 2 - 1] + median) * 0.5
	return {"median": snappedf(median, 0.01), "p95": sorted[ceili(count * 0.95) - 1]}
