extends Control
## 임시 편집기 자리표시자. 실제 편집기 UI(DESIGN.md §7)가 만들어지면 이 씬을 통째로 교체한다.
## 셸 연결은 AppShell.play_bgm() / open_options(true) / go_to_title() 세 호출뿐이다.

func _ready() -> void:
	%Options.pressed.connect(_open_options)
	%Title.pressed.connect(AppShell.go_to_title)
	AppShell.play_bgm()
	%Options.grab_focus.call_deferred()

func _open_options() -> void:
	if not AppShell.options_closed.is_connected(%Options.grab_focus):
		AppShell.options_closed.connect(%Options.grab_focus, CONNECT_ONE_SHOT)
	AppShell.open_options(true)

func _unhandled_input(event: InputEvent) -> void:
	# 물리 키 Esc 또는 패드 Start로 옵션을 연다(IME 상태와 무관).
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if (key or pad) and not AppShell.options.visible:
		_open_options()
		get_viewport().set_input_as_handled()
