extends "res://addons/web_profiler/profile_source.gd"
## Minimal adapter; games may subclass to supply typed counters and loading policy.
var _host: WeakRef
func _init(game: Node) -> void: _host = weakref(game)
func host() -> Node: return _host.get_ref()
func viewports() -> Viewports:
	var result := Viewports.new()
	if host() != null: result.world = host().get_viewport()
	return result
