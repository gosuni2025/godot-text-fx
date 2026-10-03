extends Control
## 이전 타이틀 경로로 진입해도 메뉴를 거치지 않고 편집기를 연다.

func _ready() -> void:
	hide()
	AppShell.open_editor.call_deferred()
