extends RefCounted
## 조작 기록을 새 모델에 다시 적용한다.
## 결과: { model, doc, hash(정규 JSON sha256), export_hash(마지막 내보내기), results(명령별 bool), applied, rejected }

const EditorModel := preload("res://app/logic/editor_model.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")


static func run(log) -> Dictionary:
	var model = EditorModel.new(log.start_doc, log.locale)
	var results: Array = []
	var applied := 0
	for cmd in log.commands:
		var ok: bool = model.apply(cmd.duplicate(true))
		results.append(ok)
		if ok:
			applied += 1
	return {
		"model": model,
		"doc": model.doc,
		"hash": JsonUtil.stable_hash(model.doc),
		"export_hash": str(model.last_export.get("hash", "")),
		"results": results,
		"applied": applied,
		"rejected": results.size() - applied,
	}


## 직렬화 문자열에서 바로 리플레이. 파싱 실패 시 {ok:false, error}.
static func run_string(text: String) -> Dictionary:
	var OpLog := preload("res://app/logic/op_log.gd")
	var p: Dictionary = OpLog.parse(text)
	if not p.ok:
		return {"ok": false, "error": p.error}
	var r := run(p.log)
	r["ok"] = true
	return r
