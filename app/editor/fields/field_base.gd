extends HBoxContainer
## 스키마 필드 공통 동작. 필드 씬(fields/*.tscn)의 루트 스크립트가 상속한다.
## setup(ctx, path, rule, opts) 후 refresh()로 모델 값을 표시하고, 사용자가 바꾸면 set 명령을 보낸다.
## 필드는 문서를 직접 바꾸지 않는다: ctx.send(command) → model.changed → refresh().
## opts: label(번역 키), min/max/step(슬라이더 범위), choices(선택지 배열), labels({값: 키}).

const Labels := preload("res://app/editor/ui_labels.gd")

var ctx
var path := ""
var rule: Dictionary = {}
var opts: Dictionary = {}
var _updating := false


func setup(p_ctx, p_path: String, p_rule: Dictionary, p_opts: Dictionary = {}) -> void:
	ctx = p_ctx
	path = p_path
	rule = p_rule
	opts = p_opts
	var caption := get_node_or_null("%Caption") as Label
	if caption:
		caption.text = str(opts.get("label", Labels.field(path)))
		caption.tooltip_text = path
	_build()
	refresh()


## 모델 값을 다시 읽어 표시한다(신호를 내지 않는다).
func refresh() -> void:
	if ctx == null:
		return
	var v = ctx.model.get_value(path)
	if v == null:
		return
	_updating = true
	_show(v)
	_updating = false


func commit(value) -> void:
	if _updating or ctx == null:
		return
	ctx.send({"op": "set", "path": path, "value": value})


## 첫 번째 포커스 대상(키보드·패드 이동용).
func focus_target() -> Control:
	return null


func _build() -> void:
	pass


func _show(_v) -> void:
	pass
