extends RefCounted
## 편집기 단축키(물리 키 기준이라 한글 IME 상태와 무관).
##   Space 재생/정지(문자 입력 중 제외) · Home 처음으로 · Ctrl/Cmd+Z 실행 취소 · Ctrl/Cmd+Shift+Z(또는 Ctrl+Y) 다시 실행
##   Ctrl/Cmd+S 문서 저장(Shift: 다른 이름) · Ctrl/Cmd+E 베이크 내보내기 · Ctrl/Cmd+Shift+C 문서 문자열 복사
##   Esc/패드 Start 옵션 · 패드 LB/RB 탭 이동. 포커스 이동은 Godot 기본 ui_* 동작(방향키·D패드·Tab).

var ed


func _init(editor) -> void:
	ed = editor


func _typing() -> bool:
	var f: Control = ed.get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


static func _key(event: InputEvent) -> InputEventKey:
	var k := event as InputEventKey
	return k if k != null and k.pressed and not k.echo else null


## GUI보다 먼저: 버튼에 포커스가 있어도 Space는 재생/정지.
func handle_input(event: InputEvent) -> bool:
	var k := _key(event)
	if k == null or k.physical_keycode != KEY_SPACE or k.is_command_or_control_pressed() or k.alt_pressed:
		return false
	if _typing():
		return false
	ed.preview.toggle_play()
	return true


## GUI 다음: 문자 입력 칸이 쓰는 키(Home, Ctrl+Z 등)는 그 칸이 먼저 처리한다.
func handle_shortcut(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				ed.step_tab(-1)
				return true
			JOY_BUTTON_RIGHT_SHOULDER:
				ed.step_tab(1)
				return true
		return false
	var k := _key(event)
	if k == null:
		return false
	var cmd := k.is_command_or_control_pressed()
	match k.physical_keycode:
		KEY_HOME:
			if cmd or _typing():
				return false
			ed.preview.to_start()
			return true
		KEY_Z:
			if not cmd:
				return false
			ed.send({"op": "redo" if k.shift_pressed else "undo"})
			return true
		KEY_Y:
			if not cmd:
				return false
			ed.send({"op": "redo"})
			return true
		KEY_S:
			if not cmd:
				return false
			ed.panel("export").save_doc(k.shift_pressed)
			return true
		KEY_E:
			if not cmd:
				return false
			ed.panel("export").export_baked()
			return true
		KEY_C:
			if not (cmd and k.shift_pressed):
				return false
			ed.panel("export").copy_doc_string()
			return true
	return false


## 아무도 처리하지 않은 Esc / 패드 Start → 옵션.
func handle_unhandled(event: InputEvent) -> bool:
	var k := _key(event)
	var esc := k != null and k.physical_keycode == KEY_ESCAPE
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if not (esc or pad):
		return false
	var shell: Node = ed.get_node_or_null("/root/AppShell")
	if shell == null or shell.options.visible:
		return false
	ed.open_options()
	return true
