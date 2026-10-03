extends Control
## 공용 타이틀(ui/title.tscn)의 신호를 앱 셸에 연결한다.
@onready var title: Control = $Title

func _ready() -> void:
	title.start_requested.connect(AppShell.open_editor)
	title.options_requested.connect(_open_options)
	var quit_button: Button = title.get_node("%Quit")
	if quit_button.pressed.is_connected(get_tree().quit):
		quit_button.pressed.disconnect(get_tree().quit)
	quit_button.pressed.connect(AppShell.request_quit)
	AppShell.play_bgm()

func _open_options() -> void:
	if not AppShell.options_closed.is_connected(title.focus_default):
		AppShell.options_closed.connect(title.focus_default, CONNECT_ONE_SHOT)
	AppShell.open_options(false)
