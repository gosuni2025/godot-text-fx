extends Control
## 공용 타이틀(ui/title.tscn)의 신호를 앱 셸에 연결한다.
@onready var title: Control = $Title

func _ready() -> void:
	title.start_requested.connect(AppShell.open_editor)
	title.options_requested.connect(_open_options)
	AppShell.play_bgm()

func _open_options() -> void:
	if not AppShell.options_closed.is_connected(title.focus_default):
		AppShell.options_closed.connect(title.focus_default, CONNECT_ONE_SHOT)
	AppShell.open_options(false)
