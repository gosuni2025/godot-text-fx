extends Logger
## Never retain stdout, error text, rationale or stack traces: these can contain saves/paths.
var _mutex := Mutex.new()
var _pending: Array[Dictionary] = []
var dropped := 0

func _log_message(_message: String, _error: bool) -> void:
	pass

func _log_error(function: String, file: String, line: int, _code: String, _rationale: String,
	_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var data := {"error_type": error_type, "line": maxi(0, line)}
	if file.begins_with("res://") and file.length() <= 256: data["script"] = file
	if function.is_valid_identifier() and function.length() <= 128: data["function"] = function
	_mutex.lock()
	if _pending.size() < 64:
		_pending.append({"at": Time.get_ticks_usec(), "level": "warn" if error_type == ERROR_TYPE_WARNING else "error", "data": data})
	else: dropped += 1
	_mutex.unlock()

func drain() -> Array[Dictionary]:
	_mutex.lock()
	var result := _pending
	_pending = []
	_mutex.unlock()
	return result

func dropped_count() -> int:
	_mutex.lock()
	var result := dropped
	_mutex.unlock()
	return result
