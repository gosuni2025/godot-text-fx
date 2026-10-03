extends "res://app/editor/panels/panel_base.gd"
## 장식 탭: 밑줄·띠·틀 등 장식 목록. 추가는 종류 팝업(list_add), 삭제·순서는 목록 명령.

const DocSchema := preload("res://app/logic/doc_schema.gd")
const ItemScene := preload("res://app/editor/panels/list_item.tscn")
const LIST := "decorations"
const FIELD_OPTS := {
	"thickness": {"max": 32.0, "step": 0.5}, "delay": {"max": 3.0}, "duration": {"max": 3.0},
}


func structural_paths() -> Array:
	return [LIST]


func _setup() -> void:
	(%Add as Button).pressed.connect(open_add_picker)


func _build() -> void:
	var list := %Items as VBoxContainer
	clear_box(list)
	var decos: Array = ctx.model.get_value(LIST)
	for i in decos.size():
		var d: Dictionary = decos[i]
		var item: Node = ItemScene.instantiate()
		list.add_child(item)
		item.name = "Deco_%d" % i
		item.setup(ctx, LIST, i, decos.size(), "%d. %s" % [i + 1, tr(Labels.decoration(str(d.type)))])
		for key in d:
			add_field(item.fields_box(), "%s.%d.%s" % [LIST, i, key], FIELD_OPTS.get(key, {}))
	(%Empty as Label).visible = decos.is_empty()
	(%Add as Button).disabled = decos.size() >= DocSchema.LISTS[LIST]


func open_add_picker() -> void:
	var items: Array = []
	for id in DocSchema.DECORATIONS:
		items.append({"id": id, "label": Labels.decoration(id), "icon": ctx.ui_icon("tab_decor")})
	ctx.open_picker("Add decoration", items, "", add_decoration, true)


func add_decoration(id: String) -> void:
	ctx.send({"op": "list_add", "path": LIST, "value": id})
