extends RefCounted
## 내보내기·리플레이·봇·단축키·자동 저장·재생 바.
## - 문서 문자열 복사/붙여넣기, 조작 기록 리플레이 → 같은 문서 해시
## - 결과 텍스트 영역(문서 JSON 기본·베이크·LLM 프롬프트)과 복사
## - EditorBot이 편집기 모델을 직접 조작해도 UI가 모델을 따라가는지
## - 물리 키 단축키(Space/Home/Ctrl+Z/Ctrl+Shift+Z)가 명령이 되는지
## - 자동 저장 → 새 편집기에서 복원

const U := preload("res://tests/_ui_util.gd")
const Replay := preload("res://app/logic/replay.gd")
const EditorBot := preload("res://app/logic/editor_bot.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const AUTOSAVE := "user://test_ui_autosave.json"
const DOC_FILE := "user://test_ui_doc.json"
const BAKED_FILE := "user://test_ui_baked.json"
const PROMPT_FILE := "user://test_ui_prompt.md"


func run(t) -> void:
	var tree: SceneTree = t.tree
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTOSAVE))
	var ed: Control = await U.open(tree, AUTOSAVE)
	await _export(t, ed)
	await _replay(t, ed)
	await _bot(t, ed)
	await _transport(t, ed)
	await _shortcuts(t, ed)
	await _autosave(t, ed)
	for p in [AUTOSAVE, DOC_FILE, BAKED_FILE, PROMPT_FILE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _export(t, ed) -> void:
	ed.send({"op": "apply_template", "id": "cap_converge"})
	ed.select_tab("export")
	await t.tree.process_frame
	var xp: Node = ed.panel("export")
	var s: String = xp.copy_doc_string()
	t.ok(s.begins_with("TFX1:"), "copy produces a TFX1 string")
	var h: String = ed.model.doc_hash()
	ed.send({"op": "set_text", "text": "다른 문장"})
	t.ok(xp.paste_doc_string(s), "paste accepts the string")
	t.eq(ed.model.doc_hash(), h, "pasted string restores the document")
	t.ok(not xp.paste_doc_string("TFX1:broken"), "bad string is rejected")
	t.ok(xp.get_node("%Result").text.length() > 0, "result label shows the last message")
	t.ok(xp.save_doc_to(DOC_FILE), "save writes the document JSON")
	ed.send({"op": "set_text", "text": "바뀐 문장"})
	t.ok(xp.open_doc_from(DOC_FILE), "open reads it back")
	t.eq(ed.model.doc_hash(), h, "opened document equals the saved one")
	xp.get_node("%Fps_24").pressed.emit()
	t.eq(xp.fps, 24, "fps toggle")
	t.ok(xp.export_baked_to(BAKED_FILE), "baked export writes a file")
	var baked = JSON.parse_string(FileAccess.get_file_as_string(BAKED_FILE))
	t.ok(baked is Dictionary and baked.get("format") == "text_fx_baked" and int(baked.get("fps")) == 24, "baked JSON has the chosen fps")
	await _output(t, ed, xp)


## 결과 텍스트 영역: 기본은 문서 JSON, 형식 토글·복사·LLM 프롬프트.
func _output(t, ed, xp) -> void:
	await t.tree.process_frame
	var box: TextEdit = xp.get_node("%Output")
	t.eq(xp.format, "doc_json", "document JSON is the default output")
	var doc = JSON.parse_string(box.text)
	t.ok(doc is Dictionary and doc.get("format") == "text_fx", "text area shows the document JSON without saving")
	t.ok(not xp.get_node("%FpsRow").visible, "fps row hidden for document JSON")
	xp.get_node("%Fmt_baked_json").pressed.emit()
	await t.tree.process_frame
	t.ok(xp.get_node("%FpsRow").visible, "fps row shown for baked JSON")
	var baked = JSON.parse_string(box.text)
	t.ok(baked is Dictionary and int(baked.get("fps")) == 24, "text area shows baked JSON with the chosen fps")
	xp.get_node("%Fmt_llm_prompt").pressed.emit()
	await t.tree.process_frame
	t.ok(box.text.begins_with("# Text animation spec"), "text area shows the LLM prompt")
	t.ok(box.text.contains(str(ed.model.get_value("text")).split("\n")[0]), "prompt contains the text")
	t.ok(box.text.contains("```json"), "prompt embeds the document JSON")
	var copied: String = xp.copy_output()
	t.eq(copied, box.text, "copy returns the shown output")
	t.eq(ed.model.last_export.get("kind"), "llm_prompt", "output goes through the export command")
	var n: int = ed.op_log.commands.size()
	xp.update_output()
	t.eq(ed.op_log.commands.size(), n, "unchanged output is not exported again")
	t.ok(xp.save_output_to(PROMPT_FILE), "prompt saves to a file")
	t.eq(FileAccess.get_file_as_string(PROMPT_FILE), copied, "saved prompt equals the output")
	xp.set_format("doc_json")
	await t.tree.process_frame


func _replay(t, ed) -> void:
	var log_text: String = ed.panel("export").copy_log()
	var r := Replay.run_string(log_text)
	t.ok(r.get("ok", false), "op log parses")
	t.eq(r.get("hash"), ed.model.doc_hash(), "replaying the UI op log reproduces the document")
	var h: String = ed.model.doc_hash()
	ed.send({"op": "apply_template", "id": "msg_check_fumble"})
	t.ok(ed.panel("export").replay_log(log_text), "paste & replay accepted")
	t.eq(ed.model.doc_hash(), h, "replay result is loaded")


func _bot(t, ed) -> void:
	var bot = EditorBot.new(4242)
	bot.model = ed.model
	bot.log = OpLog.create(4242, ed.model.doc, ed.model.locale)
	bot.run_random(60)
	bot.send({"op": "pause"})
	ed.select_tab("text")
	await t.tree.process_frame
	t.eq(ed.panel("text").get_node("%Main").text, ed.model.get_value("text"), "text panel follows bot changes")
	ed.select_tab("layout")
	await t.tree.process_frame
	var f: Node = ed.panel("layout").field_for("layout.font_size")
	t.near(f.get_node("%Slider").value, float(ed.model.get_value("layout.font_size")), 0.001, "layout slider follows bot changes")
	t.eq(Replay.run(bot.log).hash, ed.model.doc_hash(), "bot log replays to the same document")
	t.eq(ed.preview.player.get_document().get("text"), ed.model.get_value("text"), "preview player shows the model document")


func _transport(t, ed) -> void:
	ed.send({"op": "apply_template", "id": "msg_battle_engage"})
	ed.send({"op": "pause"})
	await t.tree.process_frame
	var pv: Node = ed.preview
	pv.get_node("%PlayPause").pressed.emit()
	t.ok(ed.model.playing, "play button sends play")
	await U.frames(t.tree, 3)
	t.ok(ed.model.time > 0.0, "clock advances while playing")
	pv.get_node("%PlayPause").pressed.emit()
	t.ok(not ed.model.playing, "second press pauses")
	pv.get_node("%ToStart").pressed.emit()
	t.eq(ed.model.time, 0.0, "to start seeks to 0")
	pv.scrubber.value = 0.5
	t.near(ed.model.time, 0.5, 0.002, "scrubber sends seek")
	var seeks := 0
	for c in ed.op_log.commands:
		seeks += 1 if c.op == "seek" else 0
	pv.scrubber.value = 0.6
	var seeks2 := 0
	for c in ed.op_log.commands:
		seeks2 += 1 if c.op == "seek" else 0
	t.eq(seeks2, seeks, "consecutive seeks are coalesced in the op log")
	pv.get_node("%Loop_loop_hold").pressed.emit()
	t.eq(ed.model.get_value("timeline.loop"), "loop_hold", "loop toggle sets timeline.loop")
	t.ok(pv.get_node("%Finish").visible, "finish button visible in loop_hold")
	pv.get_node("%Exit").pressed.emit()
	t.eq(ed.model.get_value("timeline.exit.enabled"), false, "exit toggle")
	pv.get_node("%Loop_once").pressed.emit()
	t.ok(not pv.get_node("%Finish").visible, "finish hidden outside loop_hold")
	pv.get_node("%Exit").pressed.emit()
	ed.send({"op": "seek", "t": pv.end_time() + 0.1})
	t.ok(pv.is_ended(), "past the end counts as ended")
	pv.toggle_play()
	t.ok(ed.model.playing and ed.model.time == 0.0, "play at the end restarts from 0")
	ed.send({"op": "pause"})
	pv.get_node("%BgColor").pressed.emit()
	t.eq(pv.bg_mode, "color", "background switch is preview-only")


func _shortcuts(t, ed) -> void:
	var tree: SceneTree = t.tree
	ed.select_tab("layout")
	await tree.process_frame
	ed.get_node("%Tab_layout").grab_focus()
	await U.key(tree, KEY_SPACE)
	t.ok(ed.model.playing, "Space plays even when a button has focus")
	await U.key(tree, KEY_SPACE)
	t.ok(not ed.model.playing, "Space pauses")
	ed.send({"op": "seek", "t": 1.0})
	await U.key(tree, KEY_HOME)
	t.eq(ed.model.time, 0.0, "Home seeks to start")
	ed.send({"op": "set", "path": "layout.font_size", "value": 77.0, "merge": false})
	await U.key(tree, KEY_Z, true)
	t.ne(ed.model.get_value("layout.font_size"), 77.0, "Ctrl/Cmd+Z undoes")
	await U.key(tree, KEY_Z, true, true)
	t.eq(ed.model.get_value("layout.font_size"), 77.0, "Ctrl/Cmd+Shift+Z redoes")
	ed.select_tab("text")
	await tree.process_frame
	var main: TextEdit = ed.panel("text").get_node("%Main")
	main.grab_focus()
	var playing_before: bool = ed.model.playing
	await U.key(tree, KEY_SPACE)
	t.eq(ed.model.playing, playing_before, "Space types into the text field instead of playing")
	ed.get_node("%Tab_text").grab_focus()
	var shell: Node = tree.root.get_node_or_null("AppShell")
	if shell:
		ed.open_options()
		await tree.process_frame
		var was: bool = ed.model.playing
		await U.key(tree, KEY_SPACE)
		t.eq(ed.model.playing, was, "Space is left to the options screen while it is open")
		shell.options.hide()
		await tree.process_frame
	# 패드 LB/RB 탭 이동, 방향키 포커스 이동
	for pressed in [true, false]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		jb.pressed = pressed
		tree.root.push_input(jb)
	await tree.process_frame
	t.eq(ed.current_tab, "motion", "RB moves to the next tab")
	var after: Control = null
	for i in 3:  # 탭이 두 줄이면 아래 줄 탭을 거쳐 패널로 들어간다
		await U.key(tree, KEY_DOWN)
		after = ed.get_viewport().gui_get_focus_owner()
		if after and ed.panel("motion").is_ancestor_of(after):
			break
	t.ok(after != null and ed.panel("motion").is_ancestor_of(after), "Down arrow moves focus into the panel")
	var card: Button = ed.panel("motion").get_node("%Enter").get_node("%EffectCard")
	card.grab_focus()
	card.pressed.emit()
	await tree.process_frame
	ed.picker.hide()
	await tree.process_frame
	t.eq(ed.get_viewport().gui_get_focus_owner(), card, "closing the picker returns focus to its opener")


func _autosave(t, ed) -> void:
	ed.send({"op": "set_text", "text": "자동 저장 확인"})
	ed.save_autosave()
	var h: String = ed.model.doc_hash()
	await U.close(t.tree, ed)
	t.ok(FileAccess.file_exists(AUTOSAVE), "autosave file written")
	var ed2: Control = await U.open(t.tree, AUTOSAVE)
	t.eq(ed2.model.doc_hash(), h, "autosave is restored on open")
	await U.close(t.tree, ed2)
