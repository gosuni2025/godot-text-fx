extends RefCounted
## Transport-independent state machine. Retrying always requires another UI call.
## Transports take (body: PackedByteArray, content_type: String). A legacy
## one-argument transport receives the plain JSON String and never gzip.
signal status_changed(status: Dictionary)
var project_id: String

func _init(project: String = "") -> void:
	project_id = project
## Wire limit of the request body, compressed or not. Matches the server.
const MAX_BYTES := 65536
## Decompressed JSON limit of a gzip body. Matches the server's MAX_DECOMPRESSED_BYTES.
const MAX_RAW_BYTES := 524288
const JSON_CONTENT_TYPE := "application/json"
const GZIP_CONTENT_TYPE := "application/vnd.godot-web-profiler.report+gzip"
const MAX_LOGS := 128
const MAX_COUNTERS := 30
const MAX_ATTEMPTS := 3
const MESSAGES := {"idle": "", "sending": "Sending performance report...", "success": "Performance report sent.",
	"network_error": "Report could not be sent. Please retry.", "rate_limited": "Too many reports. Please retry later.",
	"invalid_response": "The report server returned an invalid response.", "retry_limit": "Retry limit reached. Send a new report.",
	"too_large": "The performance report is too large.", "no_samples": "Play briefly before sending a performance report.",
	"invalid_report": "The performance report could not be prepared."}
var _status := {"state": "idle", "message": "", "message_code": "idle", "report_id": "", "report_type": "profile", "attempts": 0, "retryable": false}
## Uncompressed JSON of the pending report. Non-empty while a report is pending.
var pending_json := ""
## Exact request bytes; a manual retry resends them unchanged.
var pending_body := PackedByteArray()
var pending_content_type := ""
var pending_id := ""
var pending_type := "profile"
var attempts := 0
var _pending_payload := {}
var _transport := Callable()

func get_status() -> Dictionary:
	return _status.duplicate(true)

func send(payload: Dictionary, transport: Callable) -> void:
	if _status.state == "sending": return
	if attempts >= MAX_ATTEMPTS:
		set_error("retry_limit")
		return
	var legacy := _legacy(transport)
	if pending_json.is_empty():
		if project_id.is_empty() or payload.get("project") != project_id or str(payload.get("report_id", "")).is_empty() or payload.get("report_type", "profile") not in ["profile", "log"]:
			set_error("invalid_report")
			return
		pending_type = payload.get("report_type", "profile")
		if pending_type == "profile" and int(payload.get("window", {}).get("frame_count", 0)) == 0:
			set_error("no_samples")
			return
		if not _set_pending(encode_payload(payload, not legacy)):
			set_error("too_large")
			return
		pending_id = payload.report_id
	elif legacy and pending_content_type == GZIP_CONTENT_TYPE and not _downgrade():
		set_error("too_large")
		return
	attempts += 1
	_transport = transport
	_set_status("sending", "sending")
	if _dispatch() != OK: set_error("network_error")

func complete(result: int, response_code: int, body: PackedByteArray) -> void:
	if _status.state != "sending": return
	if result == HTTPRequest.RESULT_SUCCESS and _needs_json_fallback(response_code, body):
		# A server predating gzip rejects the media type before reading the body.
		# Resend the same report once as plain JSON within the same user attempt.
		if not _downgrade(): set_error("too_large")
		elif _dispatch() != OK: set_error("network_error")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code not in [200, 201]:
		set_error("rate_limited" if response_code == 429 else "network_error")
		return
	if body.size() > 16384:
		set_error("invalid_response")
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		set_error("invalid_response")
		return
	var response: Variant = parser.data
	if response is not Dictionary or response.get("ok") != true or response.get("report_id") != pending_id \
		or response.get("project") != project_id or response.get("report_type") != pending_type \
		or response.get("received_at") is not String or response.received_at.is_empty():
		set_error("invalid_response")
		return
	_set_status("success", "success")
	_clear_pending()

func discard_pending() -> void:
	if _status.state == "sending": return
	_clear_pending()
	_set_status("idle", "idle")

func set_error(code: String) -> void:
	_set_status("error", code)

func _set_status(state: String, code: String) -> void:
	_status = {"state": state, "message": MESSAGES.get(code, MESSAGES.invalid_report), "message_code": code,
		"report_id": pending_id, "report_type": pending_type, "attempts": attempts,
		"retryable": state == "error" and not pending_json.is_empty() and attempts < MAX_ATTEMPTS}
	status_changed.emit(get_status())

func _set_pending(encoded: Dictionary) -> bool:
	if encoded.is_empty(): return false
	pending_json = encoded.json
	pending_body = encoded.body
	pending_content_type = encoded.content_type
	# Only a gzip body may need the plain JSON fallback later.
	_pending_payload = encoded.payload if pending_content_type == GZIP_CONTENT_TYPE else {}
	return true

func _clear_pending() -> void:
	pending_json = ""
	pending_body = PackedByteArray()
	pending_content_type = ""
	pending_id = ""
	attempts = 0
	_pending_payload = {}
	_transport = Callable()

func _downgrade() -> bool:
	if pending_content_type != GZIP_CONTENT_TYPE or _pending_payload.is_empty(): return false
	return _set_pending(encode_payload(_pending_payload, false))

func _dispatch() -> int:
	if not _transport.is_valid(): return ERR_UNCONFIGURED
	if _legacy(_transport): return _transport.call(pending_json)
	return _transport.call(pending_body, pending_content_type)

static func _legacy(transport: Callable) -> bool:
	return transport.is_valid() and transport.get_argument_count() == 1

func _needs_json_fallback(response_code: int, body: PackedByteArray) -> bool:
	if pending_content_type != GZIP_CONTENT_TYPE: return false
	if response_code == 415: return true
	# 400 may come from a proxy or server that could not decode the body. A
	# report that decoded but failed validation would fail as plain JSON too.
	if response_code != 400 or body.size() > 16384: return false
	var response: Variant = JSON.parse_string(body.get_string_from_utf8())
	return not (response is Dictionary and response.get("error") == "invalid_report")

## Plain JSON within MAX_BYTES. Empty when the report cannot fit.
static func serialize_payload(source: Dictionary) -> String:
	return encode_payload(source, false).get("json", "")

## Returns {json, body, content_type, payload}, or {} when the report cannot fit.
## gzip: JSON up to MAX_RAW_BYTES, compressed to at most MAX_BYTES.
## Both modes trim the oldest unprotected logs first, then the oldest counters.
static func encode_payload(source: Dictionary, gzip := true) -> Dictionary:
	var payload := source.duplicate(true)
	var logs: Array = payload.get("logs", [])
	var counters: Array = payload.get("counters", [])
	if not payload.has("runtime"): payload["runtime"] = {}
	# A fallback re-encodes an already trimmed report; keep its earlier counts.
	var previous: Variant = payload.runtime.get("upload_trimming")
	if previous is not Dictionary: previous = {}
	var trimming := {"logs_dropped": int(previous.get("logs_dropped", 0)),
		"counters_dropped": int(previous.get("counters_dropped", 0)), "encoding": "gzip" if gzip else "json"}
	if not gzip and previous.get("encoding") == "gzip": trimming["gzip_rejected"] = true
	if gzip:
		# Widest possible values while trimming; replaced by measured sizes below.
		trimming["json_bytes"] = MAX_RAW_BYTES
		trimming["gzip_bytes"] = MAX_BYTES
	payload.runtime["upload_trimming"] = trimming
	var log_only: bool = payload.get("report_type", "profile") == "log"
	var protected_log := logs.size() - 1 if log_only else -1
	if not log_only:
		for i in range(logs.size() - 1, -1, -1):
			if logs[i] is Dictionary and logs[i].get("event") == "slow_work_frame":
				protected_log = i
				break
	while logs.size() > MAX_LOGS:
		protected_log = _drop_oldest_log(logs, protected_log)
		trimming.logs_dropped += 1
	while counters.size() > MAX_COUNTERS:
		counters.pop_front()
		trimming.counters_dropped += 1
	if log_only and logs.is_empty(): return {}
	var minimum_logs := 1 if protected_log >= 0 else 0
	while true:
		var encoded := _measure(payload, gzip)
		if gzip and _fits(encoded, gzip): encoded = _settle(payload, trimming, encoded)
		if _fits(encoded, gzip):
			encoded["payload"] = payload
			return encoded
		if logs.size() > minimum_logs:
			protected_log = _drop_oldest_log(logs, protected_log)
			trimming.logs_dropped += 1
		elif not counters.is_empty():
			counters.pop_front()
			trimming.counters_dropped += 1
		else:
			break
	return {}

static func _measure(payload: Dictionary, gzip: bool) -> Dictionary:
	var json := JSON.stringify(payload)
	var raw := json.to_utf8_buffer()
	if not gzip: return {"json": json, "raw_size": raw.size(), "body": raw, "content_type": JSON_CONTENT_TYPE}
	# Compression is skipped while the JSON alone exceeds its own budget.
	var body := raw.compress(FileAccess.COMPRESSION_GZIP) if raw.size() <= MAX_RAW_BYTES else PackedByteArray()
	return {"json": json, "raw_size": raw.size(), "body": body, "content_type": GZIP_CONTENT_TYPE}

static func _fits(encoded: Dictionary, gzip: bool) -> bool:
	if not gzip: return encoded.body.size() <= MAX_BYTES
	return encoded.raw_size <= MAX_RAW_BYTES and not encoded.body.is_empty() and encoded.body.size() <= MAX_BYTES

## Replace the placeholder sizes with the sizes of the body that carries them.
## The recorded gzip size changes the compressed bytes, so look for a
## self-consistent value near the measured size when plain iteration oscillates.
static func _settle(payload: Dictionary, trimming: Dictionary, encoded: Dictionary) -> Dictionary:
	for _pass in 3:
		if _consistent(trimming, encoded): return encoded
		trimming.json_bytes = encoded.raw_size
		trimming.gzip_bytes = encoded.body.size()
		encoded = _measure(payload, true)
	var center: int = encoded.body.size()
	for delta in [0, -1, 1, -2, 2, -3, 3, -4, 4]:
		trimming.json_bytes = encoded.raw_size
		trimming.gzip_bytes = center + delta
		var candidate := _measure(payload, true)
		if _consistent(trimming, candidate): return candidate
	# Rare: no exact value nearby. The final measured body is still the one sent
	# and checked against the limits; gzip_bytes is then off by a few bytes.
	trimming.json_bytes = encoded.raw_size
	trimming.gzip_bytes = center
	return _measure(payload, true)

static func _consistent(trimming: Dictionary, encoded: Dictionary) -> bool:
	return trimming.json_bytes == encoded.raw_size and trimming.gzip_bytes == encoded.body.size()

static func _drop_oldest_log(logs: Array, protected_index: int) -> int:
	# Callers retain at least the protected entry. Skip it even when ordinary
	# diagnostics appended later have moved it to the front of the trim queue.
	var index := 1 if protected_index == 0 else 0
	logs.remove_at(index)
	return protected_index - 1 if protected_index > index else protected_index
