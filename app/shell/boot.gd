extends "res://addons/game_base/boot.gd"
## 공용 부트 어댑터. 스레드 로딩·실패 재시도·첫 프레임 완료는 game_base가 맡고,
## 이 앱은 프로파일러 로딩 구간과 BGM 시작만 연결한다. 기본 씬은 base_project.tres의 game_scene.

func _ready() -> void:
	AppShell.set_loading(true)
	super()

func finish_world(_world: Node) -> void:
	AppShell.set_loading(false)
	AppShell.play_bgm()
