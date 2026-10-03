extends "res://addons/game_base/profile_source.gd"
## 이 앱 전용 프로파일 Source. 화면 이름만 구역(map_id)으로 넘긴다.
## 게임 전용 강타입 측정값이 필요해지면 measurement_sample.gd 기반 Sample을 여기서 정의한다.

func map_id() -> String:
	var tree := host().get_tree() if host() != null else null
	if tree == null or tree.current_scene == null: return "boot"
	match tree.current_scene.scene_file_path:
		"res://app/shell/title_screen.tscn": return "title"
		"res://app/editor/editor.tscn": return "editor"
	return "other"
