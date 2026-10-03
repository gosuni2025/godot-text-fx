extends RefCounted
const Sample = preload("res://addons/web_profiler/schema/measurement_sample.gd")
const Metric = preload("res://addons/web_profiler/schema/metric.gd")

static func table(sample: Sample, prefix: String = "") -> String:
	var rows := ""
	for metric in sample.metrics():
		var allowed := ", ".join(metric.choices)
		if allowed.is_empty(): allowed = "—"
		var condition := "항상" if metric.presence.is_empty() else str(metric.presence) + "일 때"
		if metric.omit_zero: condition = "0이 아닐 때"
		rows += "| `%s%s` | %s | %s | %s | %s | %s |\n" % [prefix, metric.key,
			Metric.Kind.keys()[metric.kind], metric.unit, allowed, condition, metric.meaning]
		if metric.kind == Metric.Kind.SAMPLE:
			rows += table(sample.get(metric.property), prefix + str(metric.key) + ".")
	return rows
