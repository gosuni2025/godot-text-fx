extends RefCounted
## Subclasses expose typed properties and a closed list of Metric definitions.
## Serialization is the only Dictionary boundary; unknown properties are never collected.
const Metric = preload("res://addons/web_profiler/schema/metric.gd")

func metrics() -> Array[Metric]: return []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var known := {}
	for metric in metrics():
		if metric.key in known: errors.append("Duplicate metric: " + str(metric.key))
		known[metric.key] = true
		if not metric.presence.is_empty() and not get(metric.presence): continue
		var problem := metric.error(get(metric.property))
		if not problem.is_empty(): errors.append(problem)
	return errors

func serialize() -> Dictionary:
	if not validation_errors().is_empty(): return {}
	var result := {}
	for metric in metrics():
		if not metric.presence.is_empty() and not get(metric.presence): continue
		var value: Variant = get(metric.property)
		if metric.omit_zero and value == 0.0: continue
		result[metric.key] = metric.encode(value)
	return result
