extends RefCounted
## Two JS marks per active frame; one optional GPU query span per second.
## These boundaries do not measure compositor completion or physical scanout.
var _frame_probe: JavaScriptObject
var _gpu_probe: JavaScriptObject
var _frame := -1
var _scope := 0
var _next_gpu_usec := 0
var _gpu_active := false

func bind() -> void:
	if not OS.has_feature("web"): return
	_frame_probe = JavaScriptBridge.get_interface("GodotProfilerFrameProbe")
	_gpu_probe = JavaScriptBridge.get_interface("GodotProfilerGPUProbe")
	if _gpu_probe != null: _gpu_probe.init()

func unbind() -> void:
	_invalidate()
	_frame_probe = null
	_gpu_probe = null

func observe(boundary: int, frame: int, scope: int, now_usec: int) -> void:
	if _frame_probe == null: return
	if scope == 0:
		if _scope != 0: _invalidate()
		return
	# Match FramePhases.Boundary without introducing a cyclic preload.
	if boundary <= 1 and frame != _frame:
		if _scope != scope: _next_gpu_usec = 0
		_frame = frame
		_scope = scope
		_frame_probe.begin(scope, frame)
	elif boundary == 2 and _gpu_probe != null and now_usec >= _next_gpu_usec:
		_next_gpu_usec = now_usec + 1000000
		_gpu_active = bool(_gpu_probe.begin(scope))
	elif boundary == 3:
		if _gpu_active:
			_gpu_probe.end(scope)
			_gpu_active = false
		_frame_probe.end(scope)

func _invalidate() -> void:
	if _frame_probe != null: _frame_probe.invalidate()
	if _gpu_probe != null: _gpu_probe.invalidate()
	_scope = 0
	_frame = -1
	_gpu_active = false
