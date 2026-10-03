extends RefCounted
## 편집기 UI 기본: 씬 구성, 탭 전환, 템플릿 카드 → apply_template, 문장·스타일 필드 ↔ 모델, 실행 취소.
## UI는 명령만 보내고 model.changed로만 갱신되는지 확인한다.

const U := preload("res://tests/_ui_util.gd")
const Templates := preload("res://app/logic/templates.gd")


func run(t) -> void:
	var tree: SceneTree = t.tree
	var ed: Control = await U.open(tree)
	t.ok(ed.model != null and ed.op_log != null, "editor owns a model and an op log")
	t.ne(str(ed.model.get_value("text")), "", "startup applies a template when there is no autosave")
	for id in ed.TABS:
		ed.select_tab(id)
		await tree.process_frame
		t.ok(ed.panel(id).visible, "tab %s shows its panel" % id)
		t.ok(ed.panel(id).fields.size() > 0 or id in ["mode", "export"], "tab %s builds schema fields" % id)
	await _templates(t, ed)
	await _text(t, ed)
	await _style(t, ed)
	await _layout(t, ed)
	await _locale(t, ed)
	await U.close(tree, ed)


func _templates(t, ed) -> void:
	ed.select_tab("mode")
	var mp: Node = ed.panel("mode")
	var mode := str(ed.model.get_value("mode"))
	t.eq(mp.get_node("%Grid").get_child_count(), Templates.by_mode(mode).size(), "template grid lists the mode's templates")
	var target := "msg_battle_victory"
	if mode != "message":
		ed.send({"op": "set_mode", "mode": "message"})
		await t.tree.process_frame
	mp.card(target).pressed.emit()
	await t.tree.process_frame
	t.eq(ed.model.template_id, target, "clicking a card applies the template")
	t.ok(mp.card(target).button_pressed, "applied template card is highlighted")
	t.eq(ed.op_log.commands[-1].op, "apply_template", "card click is logged as a command")
	mp.get_node("%Mode_trailer").pressed.emit()
	await t.tree.process_frame
	t.eq(ed.model.get_value("mode"), "trailer", "mode toggle sends set_mode")
	t.eq(mp.get_node("%Grid").get_child_count(), Templates.by_mode("trailer").size(), "grid follows the mode")
	mp.get_node("%Groups").get_child(1).pressed.emit()
	await t.tree.process_frame
	var g: String = Templates.groups("trailer")[0]
	t.eq(mp.get_node("%Grid").get_child_count(), Templates.by_mode("trailer", g).size(), "group chip filters the grid")
	ed.send({"op": "set_text", "text": "내 문장"})
	mp.get_node("%KeepText").button_pressed = true
	mp.apply_template(Templates.by_mode("trailer", g)[0].id)
	t.eq(ed.model.get_value("text"), "내 문장", "keep_text keeps the user's text")
	mp.get_node("%KeepText").button_pressed = false


func _text(t, ed) -> void:
	ed.send({"op": "apply_template", "id": "msg_battle_engage"})
	ed.select_tab("text")
	await t.tree.process_frame
	var tp: Node = ed.panel("text")
	t.eq(tp.get_node("%Main").text, ed.model.get_value("text"), "text field shows the template text")
	var main: TextEdit = tp.get_node("%Main")
	main.text = "등불이 꺼졌다"
	main.text_changed.emit()  # 키 입력과 같은 신호(코드로 text를 넣으면 신호가 없다)
	await t.tree.process_frame
	t.eq(ed.model.get_value("text"), "등불이 꺼졌다", "typing sends set_text")
	var sub: TextEdit = tp.get_node("%Sub")
	sub.text = "다섯째 종"
	sub.text_changed.emit()
	await t.tree.process_frame
	t.eq(ed.model.get_value("sub_text"), "다섯째 종", "sub text sends set_text")
	ed.send({"op": "undo"})
	await t.tree.process_frame
	t.eq(main.text, ed.model.get_value("text"), "undo refreshes the text field")


func _style(t, ed) -> void:
	# merge:false로 따로 기록해 두면 다음 슬라이더 변경과 합쳐지지 않는다.
	ed.send({"op": "set", "path": "style.outline.size", "value": 9.0, "merge": false})
	ed.select_tab("style")
	await t.tree.process_frame
	var sp: Node = ed.panel("style")
	var f: Node = sp.field_for("style.outline.size")
	t.ok(f != null, "outline size field exists")
	if f == null:
		return
	t.near(f.get_node("%Slider").value, 9.0, 0.001, "slider shows the model value")
	f.get_node("%Slider").value = 12.5
	t.eq(ed.model.get_value("style.outline.size"), 12.5, "slider change sends set")
	t.near(f.get_node("%Spin").value, 12.5, 0.001, "spin box follows the slider")
	ed.send({"op": "undo"})
	await t.tree.process_frame
	t.near(sp.field_for("style.outline.size").get_node("%Slider").value, 9.0, 0.001, "undo restores the slider")
	var tog: Node = sp.field_for("style.glow.enabled")
	tog.get_node("%Check").button_pressed = true
	t.eq(ed.model.get_value("style.glow.enabled"), true, "toggle sends set")
	sp.field_for("style.fill.type").button_for("solid").pressed.emit()
	await t.tree.process_frame
	var col: Node = sp.field_for("style.fill.color")
	col.get_node("%Picker").color_changed.emit(Color(1, 0, 0, 1))
	t.eq(ed.model.get_value("style.fill.color"), "#FF0000FF", "color picker sends #RRGGBBAA")
	sp.field_for("style.fill.type").button_for("gradient").pressed.emit()
	await t.tree.process_frame
	t.eq(ed.model.get_value("style.fill.type"), "gradient", "fill choice sends set")
	t.ok(sp.field_for("style.fill.gradient.angle") != null, "gradient fields appear")
	var stops: int = (ed.model.get_value("style.fill.gradient.stops") as Array).size()
	sp.find_child("AddStop", true, false).pressed.emit()
	await t.tree.process_frame
	t.eq((ed.model.get_value("style.fill.gradient.stops") as Array).size(), stops + 1, "add stop sends list_add")
	sp.get_node("%SubToggle").button_pressed = true
	await t.tree.process_frame
	t.ok(ed.model.get_value("sub_style") is Dictionary, "separate sub style creates sub_style")
	t.eq(sp.target, "sub_style", "editing target switches to the sub style")
	t.ok(sp.field_for("sub_style.outline.size") != null, "fields edit sub_style")
	sp.get_node("%SubToggle").button_pressed = false
	await t.tree.process_frame
	t.eq(ed.model.get_value("sub_style"), null, "turning it off clears sub_style")


func _layout(t, ed) -> void:
	ed.select_tab("layout")
	await t.tree.process_frame
	var lp: Node = ed.panel("layout")
	lp.field_for("layout.align").button_for("left").pressed.emit()
	t.eq(ed.model.get_value("layout.align"), "left", "align toggle group sends set")
	t.ok(lp.field_for("layout.align").button_for("left").button_pressed, "pressed state follows the model")
	lp.get_node("%Preset_1080x1080").pressed.emit()
	await t.tree.process_frame
	t.eq([ed.model.get_value("canvas.width"), ed.model.get_value("canvas.height")], [1080.0, 1080.0], "canvas preset sets both sides in one command")
	ed.send({"op": "undo"})
	t.eq(ed.model.get_value("canvas.width"), 1280.0, "one undo restores the canvas")
	var seed_before = ed.model.get_value("seed")
	lp.next_seed()
	t.ne(ed.model.get_value("seed"), seed_before, "new seed changes the seed deterministically")


## 셸 옵션의 언어 변경(TranslationServer)을 편집기가 set_locale 명령으로 따라간다.
func _locale(t, ed) -> void:
	var prev := TranslationServer.get_locale()
	ed.send({"op": "apply_template", "id": "msg_battle_engage"})
	ed.select_tab("mode")
	var other := "ja" if ed.model.locale != "ja" else "en"
	TranslationServer.set_locale(other)
	await U.frames(t.tree, 2)
	t.eq(ed.model.locale, other, "editor follows the UI language")
	t.eq(ed.op_log.commands[-1].op, "set_locale", "language change is a logged command")
	var tpl := Templates.get_template("msg_battle_engage")
	t.eq(ed.model.get_value("text"), Templates.localized(tpl, "text", other), "untouched sample text switches language")
	await t.tree.process_frame
	var card: Button = ed.panel("mode").card("msg_battle_engage")
	t.eq(card.get_node("%Name").text, Templates.localized(tpl, "name", other), "template cards show localized names")
	TranslationServer.set_locale(prev)
	await U.frames(t.tree, 2)
