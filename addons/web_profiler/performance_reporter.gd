extends Node
## Memory-only collection. Network is touched exclusively by send_report().
signal status_changed(status: Dictionary)
const RecentWindow = preload("res://addons/web_profiler/recent_performance_window.gd")
const FrameInterval = preload("res://addons/web_profiler/performance_interval.gd")
const FramePhases = preload("res://addons/web_profiler/performance_frame_phases.gd")
const Events = preload("res://addons/web_profiler/performance_events.gd")
const SlowWork = preload("res://addons/web_profiler/performance_slow_work.gd")
const ErrorLogger = preload("res://addons/web_profiler/runtime_error_logger.gd")
const ReportEnvironment = preload("res://addons/web_profiler/performance_environment.gd")
const Upload = preload("res://addons/web_profiler/performance_upload.gd")
const Source = preload("res://addons/web_profiler/profile_source.gd")
const Config = preload("res://addons/web_profiler/profile_config.gd")
const EngineCounters = preload("res://addons/web_profiler/engine_counters.gd")
var _diagnostics := preload("res://addons/web_profiler/interval_diagnostics.gd").new()
var source := Source.new()
var config := Config.new()
var _window := RecentWindow.new()
var _interval := FrameInterval.new()
var _phases := FramePhases.new()
var _phase_map: WeakRef
var _events := Events.new()
var _upload := Upload.new()
var _logger := ErrorLogger.new()
var _arena: WeakRef
var _request: HTTPRequest
var _loading := false
var _focused := true
var _document_visible := true
var _collecting := false
var _last_map := ""
var _document: JavaScriptObject
var _visibility_callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	_request.name = "ReportRequest"
	_request.timeout = 15.0
	_request.body_size_limit = 16384
	_request.max_redirects = 0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	_upload.status_changed.connect(_on_status_changed)
	OS.add_logger(_logger)
	_phases.bind(get_tree(), _phase_scope)
	if DisplayServer.get_name() != "headless": _focused = DisplayServer.window_is_focused()
	if OS.has_feature("web"):
		_document = JavaScriptBridge.get_interface("document")
		_visibility_callback = JavaScriptBridge.create_callback(_on_visibility_changed)
		_document.addEventListener("visibilitychange", _visibility_callback)
		_on_visibility_changed([])
	record_event("reporter_ready")

func bind_source(value: Source, options: Config) -> bool:
	if value == null or options == null or not options.is_valid(): return false
	# Keep an in-flight or retryable request bound to its original project.
	if not _upload.pending_json.is_empty() and _upload.project_id != options.project_id: return false
	_finish_interval()
	_diagnostics.unbind()
	_phases.process_roots.unbind()
	_phases.process_slices.unbind()
	_phases.physics_slices.unbind()
	source = value
	_phases.process_roots = source.create_root_probe()
	_events.root_names = _phases.process_roots.names.duplicate()
	_events.extra_keys = source.diagnostic_keys()
	_events.interactions = source.interaction_codes()
	config = options
	if config.detailed_diagnostics: _diagnostics.bind(get_tree(), source.work_profiler())
	_upload.project_id = config.project_id
	var arena := source.host()
	_arena = weakref(arena) if arena != null else null
	_window.clear()
	_collecting = false
	_last_map = ""
	_phase_map = null
	_phases.set_scope(0, Engine.get_process_frames())
	if OS.has_feature("web") and arena != null:
		_phases.process_roots.bind_nodes(source.root_nodes())
		_phases.process_slices.bind_arena(arena)
		_phases.physics_slices.bind_arena(arena)
	record_event("source_bound")
	return true

func set_loading(value: bool) -> void:
	if _loading == value: return
	_finish_interval()
	_loading = value
	_diagnostics.set_active(false)
	_collecting = false
	record_event("loading_changed", {"loading": value})

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var arena = _arena.get_ref() if _arena != null else null
	if not can_collect(arena):
		if _collecting:
			_finish_interval()
			record_event("collection_suspended")
		_collecting = false
		_diagnostics.set_active(false)
		return
	_collect_frame(now, arena)

func _collect_frame(now: int, arena: Node) -> void:
	var map := _map_id(arena)
	var map_node: Node = source.scope_node()
	if not is_instance_valid(map_node): return
	var scope := map_node.get_instance_id()
	if _interval.start_usec >= 0 and (map != _interval.map_id or scope != _phases.scope_id):
		# The crossing frame has no unambiguous map; never charge it to either.
		_finish_interval()
	if scope != _phases.scope_id:
		_phase_map = weakref(map_node)
		_phases.set_scope(scope, Engine.get_process_frames())
		if config.detailed_diagnostics:
			_diagnostics.set_active(false)
			_diagnostics.set_views(source.viewports())
	if not _collecting:
		_events.record("collection_resumed", {"map_id": map}, "info", now)
		_collecting = true
	if config.detailed_diagnostics: _diagnostics.set_active(true)
	if map != _last_map:
		_events.record("map_changed", {"map_id": map}, "info", now)
		_last_map = map
	if _interval.start_usec < 0:
		_interval.begin(now, map)
		return
	var elapsed := now - _interval.last_usec
	if _interval.record_frame(now): _interval.slow_context = _slow_frame_context(arena)
	_window.record_frame(now, elapsed)
	if _interval.is_due():
		_finish_interval(arena, true)
		_interval.begin(now, map)
		_drain_errors()

func _finish_interval(arena: Node = null, preserve_phase_span := false) -> void:
	var phase_values := _phases.snapshot_and_reset()
	if _interval.frame_count > 0:
		# Boundary fragments retain exact frame totals. Live render counters are
		# omitted because a transition may already have replaced the old scene.
		var values := _sample_counters(arena) if arena != null else {}
		values.merge(_interval.counters(_events.origin_usec), true)
		values.merge(phase_values)
		_window.record_counters(_interval.last_usec, values)
		var slow := _interval.take_slow_frame(_events.origin_usec)
		if not slow.is_empty(): _events.record("slow_frame", slow.data, "info", slow.at_usec)
		SlowWork.record(phase_values, _interval, _events)
	if config.detailed_diagnostics and arena == null: _diagnostics.discard_interval()
	_interval.reset()
	if not preserve_phase_span: _phases.discard_span(Engine.get_process_frames())

func _phase_scope() -> int:
	if not _collecting or _interval.start_usec < 0: return 0
	var arena = _arena.get_ref() if _arena != null else null
	if not can_collect(arena) or _map_id(arena) != _interval.map_id: return 0
	var map_node = _phase_map.get_ref() if _phase_map != null else null
	if not is_instance_valid(map_node) or map_node != source.scope_node(): return 0
	return _phases.scope_id

func can_collect(arena: Node) -> bool:
	if not is_instance_valid(arena) or not arena.is_inside_tree(): return false
	if not _focused or not _document_visible or _loading or get_tree().paused: return false
	return source.can_collect()

func _slow_frame_context(_arena: Node) -> Dictionary:
	return _encode(source.slow_sample())

func _encode(sample: Source.Sample) -> Dictionary:
	if sample == null: return {}
	var problems := sample.validation_errors()
	if not problems.is_empty():
		# Fail closed: no partial/mistyped game record is serialized.
		_events.record("invalid_measurement", {"count": problems.size()}, "warn")
		return {}
	return sample.serialize()

func get_status() -> Dictionary:
	return _upload.get_status()

func discard_pending() -> void:
	_upload.discard_pending()

func send_report(report_type := "profile") -> void:
	if _upload.get_status().state == "sending": return
	if report_type not in ["profile", "log"]:
		_upload.set_error("invalid_report")
		return
	# A failed report keeps its exact bytes/UUID until success or explicit discard.
	var payload := build_payload(report_type) if _upload.pending_json.is_empty() else {}
	_upload.send(payload, _start_request)

func build_payload(report_type := "profile", now_usec := -1) -> Dictionary:
	# A pause-menu click can precede this autoload's next process callback.
	# Include the last partial interval, then resume from the next observed frame.
	_finish_interval()
	_drain_errors()
	var now: int = Time.get_ticks_usec() if now_usec < 0 else now_usec
	var environment := ReportEnvironment.snapshot(config, _phases.process_roots.names)
	source.extend_environment(environment)
	var arena = _arena.get_ref() if _arena != null else null
	var payload := {"schema_version": 1, "project": config.project_id, "report_type": report_type,
		"report_id": ReportEnvironment.report_id(), "created_at": Time.get_datetime_string_from_system(true, false) + "Z",
		"build": environment.build, "runtime": environment.runtime, "context": _context(arena),
		"logs": _events.snapshot()}
	payload.runtime.profiling["diagnostic_events_dropped"] = _events.dropped
	payload.runtime.profiling["logger_errors_dropped"] = _logger.dropped_count()
	if report_type == "profile":
		var recent := _window.snapshot(now, true)
		# Convert monotonic process ticks to the same session-relative basis as logs.
		recent.window.start_tick_ms = maxf(0.0, recent.window.start_tick_ms - _events.origin_usec / 1000.0)
		recent.window.end_tick_ms = maxf(0.0, recent.window.end_tick_ms - _events.origin_usec / 1000.0)
		payload["window"] = recent.window
		payload["counters"] = recent.counters
	return payload

func record_event(event: String, data := {}, level := "info") -> void:
	_events.record(event, data, level)

func _sample_counters(_arena: Node) -> Dictionary:
	var values := EngineCounters.snapshot(get_tree(), source.viewports())
	# A game definition cannot overwrite module-owned measurements.
	if config.detailed_diagnostics:
		_diagnostics.set_views(source.viewports())
		values.merge(_diagnostics.snapshot_and_reset(_interval.elapsed_usec), false)
	values.merge(_encode(source.counter_sample()), false)
	return values

func _map_id(_arena: Node) -> String:
	return source.map_id()

func _context(_arena: Node) -> Dictionary:
	var values := _encode(source.context_sample())
	values["map_id"] = source.map_id()
	return values

func _start_request(body: PackedByteArray, content_type: String) -> int:
	if not config.is_valid(): return ERR_INVALID_PARAMETER
	return _request.request_raw(config.endpoint, PackedStringArray(["Content-Type: " + content_type]), HTTPClient.METHOD_POST, body)

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_upload.complete(result, code, body)

func _on_status_changed(status: Dictionary) -> void:
	record_event("upload_status", {"state": status.state, "reason": status.message_code, "attempt": status.attempts})
	status_changed.emit(status)

func _drain_errors() -> void:
	for entry in _logger.drain(): _events.record("engine_error", entry.data, entry.level, entry.at)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_clear_visibility_window()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_clear_visibility_window()

func _on_visibility_changed(_arguments: Array) -> void:
	_document_visible = not bool(_document.hidden)
	_clear_visibility_window()

func _clear_visibility_window() -> void:
	_finish_interval()
	_diagnostics.set_active(false)
	_window.clear()
	_collecting = false
	record_event("visibility_changed", {"state": "foreground" if _focused and _document_visible else "background"})

func _exit_tree() -> void:
	_diagnostics.unbind()
	_phases.unbind()
	_phase_map = null
	OS.remove_logger(_logger)
	if is_instance_valid(_request): _request.cancel_request()
	if _document != null and _visibility_callback != null:
		_document.removeEventListener("visibilitychange", _visibility_callback)
	_visibility_callback = null
	_document = null
