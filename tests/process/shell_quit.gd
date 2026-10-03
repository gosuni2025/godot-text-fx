extends SceneTree
## 별도 프로세스에서 실행한다. -- --quit-path=options|window|reentrant
## 정상 종료 경로의 코드 0과 PASS 출력, 리소스 경고 없는 종료 로그를 확인한다.
var _path := "options"
var _deadline := 0
var _checks := 0

func _initialize() -> void:
	_deadline = Time.get_ticks_msec() + 5000
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		push_error("FAIL shell_quit: 정상 종료 요청이 5초 안에 완료되지 않음")
		quit(1)
	return false

func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quit-path="): _path = arg.substr(12)
	var shell: Node = root.get_node("AppShell")
	if not _check(not auto_accept_quit, "창 닫기를 호스트가 처리함"): return
	change_scene_to_file(shell.EDITOR_SCENE)
	await scene_changed
	if not _check(shell.options.quit_requested.is_connected(shell.request_quit), "옵션 종료 연결됨"): return
	# 배포 음원 없이 무음 테스트 리소스로 재생 수명 정리를 검사한다.
	shell.bgm.stream = _silent_stream()
	shell.bgm.play()
	var playback_id: int = shell.bgm.get_stream_playback().get_instance_id()
	shell.audio_shutdown_finished.connect(func(success: bool):
		if not _check(success, "오디오 종료 완료"): return
		if not _check(not is_instance_id_valid(playback_id), "믹서의 playback 참조 해제됨"): return
		if not _check(shell.bgm.stream == null and not shell.bgm.playing, "BGM 비활성 상태"): return
		shell.play_bgm()
		if not _check(not shell._bgm_requested, "종료 중 재시작 요청 차단됨"): return
		print("PASS shell_quit %s (%d checks)" % [_path, _checks])
	)
	match _path:
		"options": shell.options.quit_requested.emit()
		"window": shell.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		"reentrant":
			shell.request_quit()
			shell.play_bgm()
			shell.request_quit()
		_: _check(false, "알 수 없는 종료 경로")

func _silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.data = PackedByteArray([0, 0, 0, 0])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 4
	return stream

func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		push_error("FAIL shell_quit %s: %s" % [_path, message])
		# shutdown 완료 signal 뒤 request_quit()이 반환해도 실패 코드를 보존한다.
		quit.call_deferred(1)
	return ok
