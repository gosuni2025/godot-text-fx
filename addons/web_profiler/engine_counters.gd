extends RefCounted
const Viewports = preload("res://addons/web_profiler/profile_viewports.gd")

static func physical_size(viewport: Viewport) -> Vector2i:
	if viewport is SubViewport: return viewport.size
	return Vector2i(viewport.get_visible_rect().size * viewport.get_stretch_transform().get_scale()).max(Vector2i(2, 2))

static func snapshot(tree: SceneTree, views: Viewports) -> Dictionary:
	var pixels := physical_size(tree.root)
	var result := {
		"process_interval_peak_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_interval_peak_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "nodes": tree.get_node_count(),
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"viewport_px": [pixels.x, pixels.y],
		"max_fps": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second}
	var world := views.world if is_instance_valid(views.world) else tree.root
	pixels = physical_size(world)
	result["world_px"] = [pixels.x, pixels.y]
	result["scale_3d"] = world.scaling_3d_scale
	if is_instance_valid(views.weapon):
		pixels = physical_size(views.weapon)
		result["weapon_viewport_px"] = [pixels.x, pixels.y]
	if is_instance_valid(views.post):
		pixels = physical_size(views.post)
		result["post_viewport_px"] = [pixels.x, pixels.y]
	return result
