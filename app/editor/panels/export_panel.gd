extends "res://app/editor/panels/panel_base.gd"
## 내보내기 탭: 결과 미리보기(문서 JSON·베이크 JSON·LLM 프롬프트)와 복사·파일 저장, 문서 JSON 저장/열기,
## 문서 문자열·조작 기록 복사/붙여넣기·리플레이.
## 파일·클립보드 입출력만 여기서 하고, 문서 변경과 내보내기 계산은 모두 명령(export/load_doc)이다.

const Replay := preload("res://app/logic/replay.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const FPS := [24, 30, 60]
const FORMATS := ["doc_json", "baked_json", "llm_prompt"]
const SUFFIX := {"doc_json": ".json", "baked_json": "_baked.json", "llm_prompt": "_prompt.md"}
const HINTS := {
	"doc_json": "Plays in Godot with the TextFxPlayer node and keeps every effect.",
	"baked_json": "Baked frames contain movement and opacity only. Save document JSON to preserve all effects.",
	"llm_prompt": "A spec for an LLM: paste it with your engine name to reimplement this animation in any engine.",
}
## 텍스트 영역에 그대로 넣는 최대 길이. 넘으면 앞부분만 보이고 복사·저장은 전체를 쓴다.
const MAX_DISPLAY := 200000

var fps := 30
var format := "doc_json"
var last_save_path := ""
var last_message := ""
var output_text := ""
var _output_key := []
var _output_queued := false


func _setup() -> void:
	for id in FORMATS:
		(get_node("%Fmt_" + id) as Button).pressed.connect(set_format.bind(id))
	(%CopyOutput as Button).pressed.connect(copy_output)
	(%SaveOutput as Button).pressed.connect(save_output)
	for f in FPS:
		(get_node("%%Fps_%d" % f) as Button).pressed.connect(_on_fps.bind(f))
	(%SaveDoc as Button).pressed.connect(save_doc)
	(%OpenDoc as Button).pressed.connect(open_doc)
	(%CopyDoc as Button).pressed.connect(copy_doc_string)
	(%PasteDoc as Button).pressed.connect(func(): paste_doc_string(_clipboard()))
	(%CopyLog as Button).pressed.connect(copy_log)
	(%ReplayLog as Button).pressed.connect(func(): replay_log(_clipboard()))


func _refresh() -> void:
	for id in FORMATS:
		(get_node("%Fmt_" + id) as Button).set_pressed_no_signal(id == format)
	for f in FPS:
		(get_node("%%Fps_%d" % f) as Button).set_pressed_no_signal(f == fps)
	(%FpsRow as Control).visible = format == "baked_json"
	(%Result as Label).text = last_message if last_message != "" else tr("Nothing exported yet.")
	_queue_output()


# --- 결과 미리보기 --------------------------------------------------------

func set_format(id: String) -> void:
	if id in FORMATS:
		format = id
		_refresh()


## 현재 형식의 내보내기 결과를 돌려주고 텍스트 영역에 보인다. 문서·형식·fps가 같으면 다시 계산하지 않는다.
func update_output() -> String:
	_output_queued = false
	var key := [format, fps, ctx.model.doc_hash()]
	if key != _output_key:
		var cmd := {"op": "export", "kind": format}
		if format == "baked_json":
			cmd["fps"] = float(fps)
		if ctx.send(cmd):
			output_text = ctx.model.last_export.text
			_output_key = key
		else:
			output_text = ""
			_output_key = []
			_show_output(tr("Could not export: %s") % ctx.model.last_error, tr(HINTS[format]))
			return ""
	var hint := tr(HINTS[format])
	if output_text.length() > MAX_DISPLAY:
		hint += " " + tr("The preview is cut off; Copy and Save use the full text.")
		_show_output(output_text.substr(0, MAX_DISPLAY) + "\n…", hint)
	else:
		_show_output(output_text, hint)
	return output_text


func copy_output() -> String:
	var text := update_output()
	if text == "":
		return ""
	_set_clipboard(text)
	_report(true, tr("Copied the output (%d characters).") % text.length())
	return text


## 현재 형식을 파일로 저장한다(웹은 다운로드).
func save_output() -> void:
	match format:
		"doc_json":
			save_doc(true)
		"baked_json":
			export_baked()
		_:
			if OS.has_feature("web"):
				save_output_to(_suggest_name(SUFFIX[format]))
			else:
				ctx.request_file(FileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.md", "*.txt"]), _suggest_name(SUFFIX[format]), save_output_to)


func save_output_to(path: String) -> bool:
	var text := update_output()
	if text == "":
		return _report(false, ctx.model.last_error)
	if not _write(path, text):
		return _report(false, tr("Could not write %s") % path)
	return _report(true, tr("Saved: %s") % path)


func _queue_output() -> void:
	# 모델 변경 신호 안에서 다시 명령을 보내지 않도록 다음 프레임에 계산한다.
	if not _output_queued and is_visible_in_tree():
		_output_queued = true
		update_output.call_deferred()


func _show_output(text: String, hint: String) -> void:
	var box := %Output as TextEdit
	if box.text != text:
		box.text = text
		box.scroll_vertical = 0
	(%FormatHint as Label).text = hint


# --- 파일 ---------------------------------------------------------------

## 저장 경로가 있으면 바로 저장하고, 없으면 파일 대화상자를 연다.
func save_doc(ask := false) -> void:
	if OS.has_feature("web"):
		save_doc_to(_suggest_name(".json"))
		return
	if last_save_path != "" and not ask:
		save_doc_to(last_save_path)
		return
	ctx.request_file(FileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.json"]), _suggest_name(".json"), save_doc_to)


func save_doc_to(path: String) -> bool:
	if not ctx.send({"op": "export", "kind": "doc_json"}):
		return _report(false, ctx.model.last_error)
	if not _write(path, ctx.model.last_export.text):
		return _report(false, tr("Could not write %s") % path)
	last_save_path = path
	return _report(true, tr("Saved document: %s") % path)


func open_doc() -> void:
	ctx.request_file(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.json"]), "", open_doc_from)


func open_doc_from(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _report(false, tr("Could not read %s") % path)
	var data = JsonUtil.parse(f.get_as_text())
	if not (data is Dictionary):
		return _report(false, tr("Not a JSON document: %s") % path)
	if not ctx.send({"op": "load_doc", "doc": data}):
		return _report(false, ctx.model.last_error)
	last_save_path = path
	return _report(true, tr("Opened document: %s") % path)


func export_baked() -> void:
	if OS.has_feature("web"):
		export_baked_to(_suggest_name("_baked.json"))
		return
	ctx.request_file(FileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.json"]), _suggest_name("_baked.json"), export_baked_to)


func export_baked_to(path: String) -> bool:
	if not ctx.send({"op": "export", "kind": "baked_json", "fps": float(fps)}):
		return _report(false, ctx.model.last_error)
	if not _write(path, ctx.model.last_export.text):
		return _report(false, tr("Could not write %s") % path)
	var frames: int = (ctx.model.last_export.data.frames as Array).size()
	return _report(true, tr("Exported baked JSON (%d fps, %d frames): %s") % [fps, frames, path])


# --- 클립보드 -----------------------------------------------------------

## 문서 문자열(TFX1:...)을 클립보드에 복사하고 돌려준다.
func copy_doc_string() -> String:
	if not ctx.send({"op": "export", "kind": "doc_string"}):
		_report(false, ctx.model.last_error)
		return ""
	var text: String = ctx.model.last_export.text
	_set_clipboard(text)
	_report(true, tr("Copied the document string (%d characters).") % text.length())
	return text


func paste_doc_string(text: String) -> bool:
	if not ctx.send({"op": "load_doc", "string": text.strip_edges()}):
		return _report(false, tr("Could not paste: %s") % ctx.model.last_error)
	return _report(true, tr("Pasted the document string."))


## 이 세션의 조작 기록(시작 문서 + 명령)을 문자열로 복사하고 돌려준다.
func copy_log() -> String:
	var text: String = ctx.op_log.serialize()
	_set_clipboard(text)
	_report(true, tr("Copied the operation log (%d commands).") % ctx.op_log.commands.size())
	return text


## 조작 기록을 새 모델에서 다시 실행하고, 그 결과 문서를 불러온다(load_doc 명령 하나).
func replay_log(text: String) -> bool:
	var r := Replay.run_string(text.strip_edges())
	if not r.get("ok", false):
		return _report(false, tr("Could not replay: %s") % str(r.get("error", "")))
	if not ctx.send({"op": "load_doc", "doc": r.doc}):
		return _report(false, ctx.model.last_error)
	return _report(true, tr("Replayed %d commands (%d rejected). Document hash %s") %
		[(r.results as Array).size(), int(r.rejected), str(r.hash).substr(0, 12)])


# --- 내부 ---------------------------------------------------------------

func _on_fps(f: int) -> void:
	fps = f
	_refresh()


func _suggest_name(suffix: String) -> String:
	var n := str(ctx.model.get_value("name")).strip_edges().validate_filename()
	return (n if n != "" else "text_fx") + suffix


static func _write(path: String, text: String) -> bool:
	if OS.has_feature("web"):
		var mime := "text/markdown" if path.ends_with(".md") else "application/json"
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), path.get_file(), mime)
		return true
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _report(ok: bool, message: String) -> bool:
	last_message = message
	ctx.set_status(message, not ok)
	if is_inside_tree():
		_refresh()
	return ok


static func _clipboard() -> String:
	return DisplayServer.clipboard_get() if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) else ""


static func _set_clipboard(text: String) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
