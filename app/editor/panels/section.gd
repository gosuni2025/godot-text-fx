extends PanelContainer
## 패널 안의 묶음(제목 + 필드 목록). 필드는 %Fields에 붙인다.


func set_title(key: String) -> void:
	(%Title as Label).text = key


func fields_box() -> VBoxContainer:
	return %Fields


func header_box() -> HBoxContainer:
	return %Extra
