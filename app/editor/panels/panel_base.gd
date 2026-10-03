extends ScrollContainer
## 오른쪽 탭 패널 공통 동작. 보이는 패널만 즉시 갱신하고, 숨은 패널은 다시 보일 때 갱신한다.
## 구조가 바뀌는 경로(목록·효과 종류 등)가 바뀌면 다시 만들고, 그 밖에는 필드 값만 다시 읽는다.

const Factory := preload("res://app/editor/fields/field_factory.gd")
const SectionScene := preload("res://app/editor/panels/section.tscn")
const Labels := preload("res://app/editor/ui_labels.gd")

var ctx
var fields: Array = []
var _built := false
var _need_rebuild := true
var _stale := false


func setup(p_ctx) -> void:
	ctx = p_ctx
	_setup()


## 바뀌면 패널을 다시 만들어야 하는 문서 경로(정확히 같은 경로). "*"는 항상 포함.
func structural_paths() -> Array:
	return []


func on_doc_changed(paths: PackedStringArray) -> void:
	if _needs_rebuild(paths):
		_need_rebuild = true
	_stale = true
	if is_visible_in_tree():
		sync()


func on_state_changed(_paths: PackedStringArray) -> void:
	pass


## 다시 만들기 또는 값 갱신을 지금 반영한다.
func sync() -> void:
	if ctx == null:
		return
	if _need_rebuild or not _built:
		rebuild()
	elif _stale:
		refresh_fields()
		_refresh()
	_stale = false


func mark_rebuild() -> void:
	_need_rebuild = true
	if is_visible_in_tree():
		sync()


func rebuild() -> void:
	fields.clear()
	_build()
	_built = true
	_need_rebuild = false
	_stale = false
	_refresh()


func refresh_fields() -> void:
	for f in fields:
		if is_instance_valid(f):
			f.refresh()


func add_field(parent: Node, path: String, opts: Dictionary = {}) -> Node:
	var f := Factory.make(ctx, parent, path, opts)
	if f != null:
		fields.append(f)
	return f


func add_section(parent: Node, title_key: String) -> Node:
	var s: Node = SectionScene.instantiate()
	parent.add_child(s)
	s.set_title(title_key)
	return s


## 문서 경로에 해당하는 필드(테스트·포커스용).
func field_for(path: String) -> Node:
	for f in fields:
		if is_instance_valid(f) and f.path == path:
			return f
	return null


static func clear_box(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _needs_rebuild(paths: PackedStringArray) -> bool:
	var keys := structural_paths()
	for p in paths:
		if p == "*":
			return true
		if p in keys:
			return true
	return false


## 하위 패널이 구현: 처음 한 번(정적 노드 연결).
func _setup() -> void:
	pass


## 하위 패널이 구현: 동적 필드 만들기.
func _build() -> void:
	pass


## 하위 패널이 구현: 필드 밖의 표시 갱신.
func _refresh() -> void:
	pass
