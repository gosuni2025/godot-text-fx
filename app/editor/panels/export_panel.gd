extends "res://app/editor/panels/panel_base.gd"
## 내보내기 탭: 문서 JSON 저장/열기, 베이크 JSON(fps), 문서 문자열·조작 기록 복사/붙여넣기·리플레이.
## 파일·클립보드 입출력만 여기서 하고, 문서 변경과 내보내기 계산은 모두 명령(export/load_doc)이다.

const Replay := preload("res://app/logic/replay.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const FPS := [24, 30, 60]

var fps := 30
var last_save_path := ""
var last_message := ""


func _setup() -> void:
	for f in FPS:
		(get_node("%%Fps_%d" % f) as Button).pressed.connect(_on_fps.bind(f))
	(%SaveDoc as Button).pressed.connect(save_doc)
	(%OpenDoc as Button).pressed.connect(open_doc)
	(%ExportBaked as Button).pressed.connect(export_baked)
	(%CopyDoc as Button).pressed.connect(copy_doc_string)
	(%PasteDoc as Button).pressed.connect(func(): paste_doc_string(_clipboard()))
	(%CopyLog as Button).pressed.connect(copy_log)
	(%ReplayLog as Button).pressed.connect(func(): replay_log(_clipboard()))


func _refresh() -> void:
	for f in FPS:
		(get_node("%%Fps_%d" % f) as Button).set_pressed_no_signal(f == fps)
	(%Result as Label).text = last_message if last_message != "" else tr("Nothing exported yet.")


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
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), path.get_file(), "application/json")
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
