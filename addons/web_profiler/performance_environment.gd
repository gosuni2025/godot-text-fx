extends RefCounted
const Config = preload("res://addons/web_profiler/profile_config.gd")
const BROWSER_SNAPSHOT := """
(() => {
  const canvas = document.getElementById('canvas') || document.querySelector('canvas');
  const rect = canvas ? canvas.getBoundingClientRect() : null;
  const result = {
    user_agent: String(navigator.userAgent || '').slice(0, 512),
    navigator_platform: String(navigator.platform || '').slice(0, 64),
    max_touch_points: Math.max(0, Number(navigator.maxTouchPoints) || 0),
    screen_css_px: [Number(screen.width) || 0, Number(screen.height) || 0],
    hardware_concurrency: Number.isFinite(navigator.hardwareConcurrency) ? navigator.hardwareConcurrency : null,
    device_memory_gb: Number.isFinite(navigator.deviceMemory) ? navigator.deviceMemory : null,
    long_tasks_supported: typeof PerformanceObserver !== 'undefined' &&
      Array.isArray(PerformanceObserver.supportedEntryTypes) && PerformanceObserver.supportedEntryTypes.includes('longtask'),
    long_tasks_observer_enabled: false,
    dpr: Number(window.devicePixelRatio) || 1,
    canvas_px: canvas ? [canvas.width, canvas.height] : [0, 0],
    canvas_css_px: rect ? [Math.round(rect.width), Math.round(rect.height)] : [0, 0],
    visibility: String(document.visibilityState || 'unknown').slice(0, 16)
  };
  try {
    if (window.GodotProfilerFrameProbe) result.frame_timing = window.GodotProfilerFrameProbe.snapshot();
    if (window.GodotProfilerGPUProbe) result.gpu_timing = window.GodotProfilerGPUProbe.snapshot();
    if (window.GodotProfilerRenderProbe) result.render_profiler = window.GodotProfilerRenderProbe.capabilities();
    const gl = canvas && (canvas.getContext('webgl2') || canvas.getContext('webgl'));
    if (gl) {
      const attributes = gl.getContextAttributes();
      result.webgl_context = attributes ? {antialias:attributes.antialias, depth:attributes.depth,
        stencil:attributes.stencil, preserve_drawing_buffer:attributes.preserveDrawingBuffer} : null;
      const ext = gl.getExtension('WEBGL_debug_renderer_info');
      result.webgl_renderer = String(gl.getParameter(ext ? ext.UNMASKED_RENDERER_WEBGL : gl.RENDERER) || '').slice(0, 256);
      const supported = gl.getSupportedExtensions() || [];
      result.texture_compression = {};
      for (const [name, extension] of Object.entries({s3tc:'WEBGL_compressed_texture_s3tc', etc:'WEBGL_compressed_texture_etc', astc:'WEBGL_compressed_texture_astc', bptc:'EXT_texture_compression_bptc'})) {
        result.texture_compression[name] = supported.includes(extension);
      }
      result.compressed_texture_formats = Array.from(gl.getParameter(gl.COMPRESSED_TEXTURE_FORMATS) || []).slice(0, 64);
    }
  } catch (_) {}
  return JSON.stringify(result);
})()
"""

static func snapshot(config: Config = Config.new(), root_names: PackedStringArray = []) -> Dictionary:
	var browser := {}
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(BROWSER_SNAPSHOT, true)
		if raw is String:
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary: browser = parsed
	var version := "DEV"
	if FileAccess.file_exists("res://build_info.json"):
		var build: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if build is Dictionary and build.get("version") is String: version = build.version.left(80)
	var build := {"version": version, "label": (config.build_label if not config.build_label.is_empty() else "BUILD " + version).left(100)}
	if config.build_from_project_settings:
		build = {"version": str(ProjectSettings.get_setting("application/config/version", "")).left(80),
			"revision": str(ProjectSettings.get_setting("application/config/build_revision", "")).left(80),
			"build_unix_time": int(ProjectSettings.get_setting("application/config/build_unix_time", 0))}
	return {"build": build,
		"runtime": {"engine": str(Engine.get_version_info().get("string", "")).left(80), "os": OS.get_name(),
			"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"max_fps": Engine.max_fps, "browser": browser,
			"render_path": config.render_path,
			"profiling": {"measurement_schema_version": config.measurement_schema_version, "counter_interval_ms": 1000, "frame_samples": "20ms_wall_bucket_means",
				"browser_frame_timing": "RAF_callback_wall_including_engine_work_outside_GDScript_signals_not_scanout",
				"browser_gpu_timing": "one_async_render_span_per_second_when_extension_available_not_presentation_time",
				"counter_partial_at_boundaries": true, "counter_interval_start_basis": "reporter_session_start",
				"frame_phases": "main_thread_wall_boundaries_not_gpu_time", "phase_samples": "complete_continuous_render_frames",
				"phase_no_physics_step": "zero_only_after_continuous_completed_draw", "phase_counts": "separate_from_interval_frame_count",
				"phase_peak_render_frame": "same_frame_parts_and_actual_fixed_ticks_not_independent_maxima",
				"phase_peak_work_frame": "same_frame_parts_and_fixed_ticks_only_when_interval_work_max_gt_16ms",
				"phase_work_roots": "web_only_independent_callback_body_cpu_wall_subsets_not_all_process_AI_physics_or_GPU_time",
				"phase_physics_slices": "web_default_group_all_fixed_ticks_before_between_after_node_markers_not_solver_only",
				"phase_root_call_order": Array(root_names),
				"phase_work": "same_completed_frame_physics_to_post_draw_excludes_gap_strict_gt_16ms_uses_phase_count",
				"process_physics_time": "engine_interval_peaks_not_individual_frames", "log_offset_basis": "reporter_session_start",
				"slow_work_frame": "interval_peak_physics_process_render_sum_ge_100ms_same_frame_cpu_wall_not_gpu",
				"slow_work_offset": "interval_end_not_frame_time_or_slow_frame_match_gap_excluded_from_threshold",
				"slow_work_root": "largest_available_independent_callback_subset_not_sum_or_whole_process",
				"error_capture": "Logger_categories_and_safe_source_locations_no_raw_messages", "native_render_timers_enabled": config.detailed_diagnostics}}}

static func report_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16: return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
