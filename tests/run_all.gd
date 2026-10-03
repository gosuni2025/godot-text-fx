extends SceneTree
## 헤드리스 테스트 실행기.
##   godot --headless --path . --script res://tests/run_all.gd [-- --filter=부분문자열]
##
## 규칙(다른 에이전트도 이 규칙으로 테스트를 추가한다):
## - `tests/` 바로 아래의 `*.gd` 파일을 이름순으로 모두 찾는다. 단 `run_all.gd`, `test_helper.gd`,
##   `_`로 시작하는 파일, 하위 폴더(`tests/visual/` 등)는 제외한다.
## - 테스트 파일은 `extends RefCounted`(또는 Node) 스크립트이고 `func run(t) -> void`를 가진다.
##   `t`는 `tests/test_helper.gd` 인스턴스다: t.ok(cond, msg), t.eq(a, b, msg), t.ne(a, b, msg),
##   t.near(a, b, eps, msg), t.fail(msg), t.log(msg).
## - `run(t)` 안에서 `await`를 써도 된다(프레임이 필요하면 `await t.tree.process_frame`).
##   Node 테스트는 실행 동안 루트에 추가되고 끝나면 해제된다.
## - 다른 엔진 코드 참조는 class_name 대신 preload 상수를 쓴다(헤드리스 클래스 캐시 비의존).
## 결과는 파일마다 PASS/FAIL 한 줄로 출력하고, 하나라도 실패하면 종료 코드 1로 끝낸다.

const Helper := preload("res://tests/test_helper.gd")
const SKIP := ["run_all.gd", "test_helper.gd"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
	var files := _discover()
	var passed := 0
	var failed := 0
	var total_checks := 0
	for path in files:
		if filter != "" and path.find(filter) < 0:
			continue
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s (스크립트를 불러올 수 없음)" % path)
			failed += 1
			continue
		var inst: Object = script.new()
		if not inst.has_method("run"):
			if inst is Node:
				(inst as Node).free()
			continue
		var t := Helper.new()
		t.test_name = path.get_file().get_basename()
		t.tree = self
		if inst is Node:
			root.add_child(inst)
		var started := Time.get_ticks_msec()
		await inst.run(t)
		var ms := Time.get_ticks_msec() - started
		if inst is Node:
			(inst as Node).queue_free()
		total_checks += t.checks
		if t.passed():
			passed += 1
			print("PASS %s (%d checks, %d ms)" % [path.get_file(), t.checks, ms])
		else:
			failed += 1
			print("FAIL %s (%d/%d failed, %d ms)" % [path.get_file(), t.failures.size(), t.checks, ms])
			for f in t.failures:
				print("    - " + f)
	print("---- %d passed, %d failed, %d checks ----" % [passed, failed, total_checks])
	quit(1 if failed > 0 else 0)


func _discover() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".gd") or f.begins_with("_") or SKIP.has(f):
			continue
		out.append("res://tests/" + f)
	out.sort()
	return out
