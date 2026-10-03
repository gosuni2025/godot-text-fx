extends RefCounted
## UI 테스트 공용 도우미(run_all은 `_`로 시작하는 파일을 테스트로 실행하지 않는다).
## 편집기 씬을 자동 저장 없이 띄우고, 끝나면 정리한다.

const EDITOR := preload("res://app/editor/editor.tscn")


static func open(tree: SceneTree, autosave_path := "") -> Control:
	var ed: Control = EDITOR.instantiate()
	ed.autosave_path = autosave_path
	tree.root.add_child(ed)
	await frames(tree, 3)
	ed.send({"op": "pause"})
	return ed


static func close(tree: SceneTree, ed: Control) -> void:
	for p: Window in [ed.picker, ed.font_picker]:
		p.hide()
	tree.root.remove_child(ed)
	ed.queue_free()
	var shell := tree.root.get_node_or_null("AppShell")
	if shell:
		shell.stop_bgm()
	await frames(tree, 2)


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


## 물리 키 입력을 뷰포트 입력 파이프라인으로 보낸다(Ctrl·Cmd 모두 눌린 것으로 해 플랫폼 무관).
static func key(tree: SceneTree, physical: Key, cmd := false, shift := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = physical
		ev.keycode = physical
		ev.pressed = pressed
		ev.ctrl_pressed = cmd
		ev.meta_pressed = cmd
		ev.shift_pressed = shift
		tree.root.push_input(ev)
	await tree.process_frame
