extends RefCounted
## Override only game-specific state. Keep the instance alive with bind_source().
const Sample = preload("res://addons/web_profiler/schema/measurement_sample.gd")
const Work = preload("res://addons/web_profiler/work_profiler.gd")
const Roots = preload("res://addons/web_profiler/performance_process_roots.gd")
const Viewports = preload("res://addons/web_profiler/profile_viewports.gd")

func work_profiler() -> Work: return null
func host() -> Node: return null
func scope_node() -> Node: return host()
func can_collect() -> bool: return is_instance_valid(host())
func map_id() -> String: return "gameplay"
func viewports() -> Viewports: return Viewports.new()
func create_root_probe() -> Roots: return Roots.new()
func diagnostic_keys() -> PackedStringArray: return []
func interaction_codes() -> PackedStringArray: return []
func root_nodes() -> Array[Node]: return []
func context_sample() -> Sample: return null
func counter_sample() -> Sample: return null
func slow_sample() -> Sample: return null
func extend_environment(_environment: Dictionary) -> void: pass
