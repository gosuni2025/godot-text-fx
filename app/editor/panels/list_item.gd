extends PanelContainer
## 목록 원소 하나(유지 효과·장식): 제목 + 위/아래/삭제 버튼 + 필드 목록.
## 버튼은 list_move/list_remove 명령을 보낸다. 필드는 소유 패널이 %Fields에 붙인다.

var ctx
var list_path := ""
var index := 0


func setup(p_ctx, p_list_path: String, p_index: int, count: int, title: String) -> void:
	ctx = p_ctx
	list_path = p_list_path
	index = p_index
	(%Title as Label).text = title
	(%Up as Button).disabled = index == 0
	(%Down as Button).disabled = index >= count - 1
	(%Up as Button).pressed.connect(_move.bind(-1))
	(%Down as Button).pressed.connect(_move.bind(1))
	(%Remove as Button).pressed.connect(_remove)


func fields_box() -> VBoxContainer:
	return %Fields


func _move(step: int) -> void:
	ctx.send({"op": "list_move", "path": list_path, "from": index, "to": index + step})


func _remove() -> void:
	ctx.send({"op": "list_remove", "path": list_path, "index": index})
