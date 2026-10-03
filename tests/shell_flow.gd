extends RefCounted
## 부트 → 편집기 직행 및 이전 타이틀 경로의 편집기 연결을 확인한다.
const BOOT := "res://app/shell/boot.tscn"
const TITLE := "res://app/shell/title_screen.tscn"
const EDITOR := "res://app/editor/editor.tscn"


func run(t) -> void:
	var tree: SceneTree = t.tree
	var shell: Node = tree.root.get_node_or_null("AppShell")
	if not t.ok(shell != null, "AppShell autoload exists"):
		return
	t.eq(ProjectSettings.get_setting("application/run/main_scene"), BOOT, "main scene is boot")
	t.eq(tree.change_scene_to_file(BOOT), OK, "boot scene loads")
	t.ok(await _wait_for(tree, EDITOR, 600), "boot opens editor without a menu")
	if tree.current_scene == null or tree.current_scene.scene_file_path != EDITOR:
		return
	var editor := tree.current_scene
	t.ok(not editor.get_node("%Back").visible, "redundant title button hidden")
	editor.open_options()
	await tree.process_frame
	t.ok(shell.options.visible, "editor opens shared options")
	t.ok(not shell.options.get_node("%ReturnTitle").visible or shell.options.get_node("%ReturnTitle").disabled, "no redundant return-to-title action")
	shell.options.get_node("%Back").pressed.emit()
	t.ok(not shell.options.visible, "back closes options")
	t.eq(tree.change_scene_to_file(TITLE), OK, "legacy title path loads")
	t.ok(await _wait_for(tree, EDITOR, 120), "legacy title path redirects to editor")
	shell.stop_bgm()
	tree.unload_current_scene()
	await tree.process_frame


func _wait_for(tree: SceneTree, path: String, frames: int) -> bool:
	for i in frames:
		await tree.process_frame
		if tree.current_scene != null and tree.current_scene.scene_file_path == path:
			return true
	return false
