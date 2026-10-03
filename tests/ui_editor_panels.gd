extends RefCounted
## 연출·장식·글꼴 탭과 팝업: 효과/이징 카드 팝업 → set, 유지 효과·장식 목록 → list_add/remove/move,
## 글꼴 팝업(번들·시스템) → set font, 보조 문구 글꼴 토글.

const U := preload("res://tests/_ui_util.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")


func run(t) -> void:
	var tree: SceneTree = t.tree
	var ed: Control = await U.open(tree)
	ed.send({"op": "apply_template", "id": "msg_battle_engage"})
	await _motion(t, ed)
	await _hold(t, ed)
	await _decor(t, ed)
	await _font(t, ed)
	await U.close(tree, ed)


func _motion(t, ed) -> void:
	ed.select_tab("motion")
	await t.tree.process_frame
	var mp: Node = ed.panel("motion")
	mp.get_node("%Enter").open_effect_picker()
	await t.tree.process_frame
	t.ok(ed.picker.visible, "effect card opens the picker popup")
	t.eq(ed.picker.get_node("%Grid").get_child_count(), Enter.IDS.size(), "picker lists every enter effect")
	var cur: Button = ed.picker.card(str(ed.model.get_value("timeline.enter.effect")))
	t.ok(cur != null and cur.button_pressed, "current effect is marked")
	ed.picker.card("slide").pressed.emit()
	await t.tree.process_frame
	t.eq(ed.model.get_value("timeline.enter.effect"), "slide", "picking a card sets the effect")
	t.ok(ed.picker.visible, "picker stays open to try other effects")
	t.ok(mp.field_for("timeline.enter.params.dir") != null, "effect params are rendered from the schema")
	mp.field_for("timeline.enter.params.dir").button_for("left").pressed.emit()
	t.eq(ed.model.get_value("timeline.enter.params.dir"), "left", "param choice sends set")
	ed.picker.hide()
	mp.get_node("%Enter").open_easing_picker()
	await t.tree.process_frame
	t.eq(ed.picker.get_node("%Grid").get_child_count(), Easing.NAMES.size(), "easing picker lists all easings")
	ed.picker.pick("bounce_out")
	t.eq(ed.model.get_value("timeline.enter.easing"), "bounce_out", "easing card sets easing")
	ed.picker.hide()
	mp.field_for("timeline.enter.order").button_for("reverse").pressed.emit()
	t.eq(ed.model.get_value("timeline.enter.order"), "reverse", "order toggle group sends set")
	mp.get_node("%Exit").get_node("%Enabled").button_pressed = false
	t.eq(ed.model.get_value("timeline.exit.enabled"), false, "exit switch sends set")
	mp.get_node("%Exit").open_effect_picker()
	ed.picker.pick("zoom")
	ed.picker.hide()
	t.eq(ed.model.get_value("timeline.exit.effect"), "zoom", "exit effect picker targets exit")


func _hold(t, ed) -> void:
	var mp: Node = ed.panel("motion")
	var n: int = (ed.model.get_value("timeline.hold.effects") as Array).size()
	mp.open_hold_picker()
	await t.tree.process_frame
	ed.picker.pick("wave")
	await t.tree.process_frame
	t.ok(not ed.picker.visible, "add picker closes after picking")
	t.eq((ed.model.get_value("timeline.hold.effects") as Array).size(), n + 1, "hold effect added")
	mp.add_hold("pulse")
	await t.tree.process_frame
	var items: Node = mp.get_node("%Effects")
	t.eq(items.get_child_count(), n + 2, "list shows every hold effect")
	var last: Node = items.get_child(n + 1)
	t.eq(ed.model.get_value("timeline.hold.effects.%d.type" % (n + 1)), "pulse", "new effect is last")
	t.ok(mp.field_for("timeline.hold.effects.%d.scale" % (n + 1)) != null, "hold params rendered")
	last.get_node("%Up").pressed.emit()
	await t.tree.process_frame
	t.eq(ed.model.get_value("timeline.hold.effects.%d.type" % n), "pulse", "move up sends list_move")
	items.get_child(n).get_node("%Remove").pressed.emit()
	await t.tree.process_frame
	t.eq((ed.model.get_value("timeline.hold.effects") as Array).size(), n + 1, "remove sends list_remove")
	mp.get_node("%Scroll").button_pressed = true
	await t.tree.process_frame
	t.ok(ed.model.get_value("timeline.scroll") is Dictionary, "scroll switch sets timeline.scroll")
	t.ok(mp.field_for("timeline.scroll.speed") != null, "scroll speed field appears")
	mp.get_node("%Scroll").button_pressed = false


func _decor(t, ed) -> void:
	ed.select_tab("decor")
	await t.tree.process_frame
	var dp: Node = ed.panel("decor")
	var n: int = (ed.model.get_value("decorations") as Array).size()
	dp.open_add_picker()
	await t.tree.process_frame
	t.eq(ed.picker.get_node("%Grid").get_child_count(), 6, "decoration picker lists the types")
	ed.picker.pick("frame")
	dp.add_decoration("band")
	await t.tree.process_frame
	t.eq((ed.model.get_value("decorations") as Array).size(), n + 2, "decorations added")
	var color: Node = dp.field_for("decorations.%d.color" % (n + 1))
	t.ok(color != null, "per-item fields exist")
	color.get_node("%Picker").color_changed.emit(Color(0, 1, 0, 1))
	t.eq(ed.model.get_value("decorations.%d.color" % (n + 1)), "#00FF00FF", "item color sends set")
	dp.field_for("decorations.%d.animate" % n).button_for("fade").pressed.emit()
	t.eq(ed.model.get_value("decorations.%d.animate" % n), "fade", "item choice sends set")
	dp.get_node("%Items").get_child(n).get_node("%Down").pressed.emit()
	await t.tree.process_frame
	t.eq(ed.model.get_value("decorations.%d.type" % (n + 1)), "frame", "move down reorders")


func _font(t, ed) -> void:
	ed.select_tab("font")
	await t.tree.process_frame
	var fp: Node = ed.panel("font")
	fp.get_node("%Main").get_node("%Pick").pressed.emit()
	await t.tree.process_frame
	t.ok(ed.font_picker.visible, "font button opens the font picker")
	t.ok(ed.font_picker.get_node("%Bundled").get_child_count() >= 3, "bundled fonts are listed")
	ed.font_picker.choose_bundled("Cinzel")
	t.eq(ed.model.get_value("font.family"), "Cinzel", "bundled card sets the font")
	t.eq(ed.model.get_value("font.source"), "bundled", "bundled source")
	var sys: PackedStringArray = OS.get_system_fonts()
	if sys.size() > 0:
		ed.font_picker.choose_system(sys[0])
		t.eq(ed.model.get_value("font.source"), "system", "system font sets source=system")
		ed.font_picker.get_node("%Search").text_changed.emit(sys[0].substr(0, 3))
		t.ok(ed.font_picker.get_node("%List").item_count >= 1, "search filters the system list")
	else:
		t.log("no system fonts in this environment; skipped")
	ed.font_picker.hide()
	await t.tree.process_frame
	t.eq(fp.get_node("%Main").get_node("%Pick").text, ed.model.get_value("font.family"), "font button shows the family")
	fp.field_for("font.weight").get_node("%Slider").value = 400.0
	t.eq(ed.model.get_value("font.weight"), 400.0, "weight slider sends set")
	fp.get_node("%SubToggle").button_pressed = true
	await t.tree.process_frame
	t.ok(ed.model.get_value("sub_font") is Dictionary, "separate sub font creates sub_font")
	t.ok(fp.get_node("%Sub").visible and fp.field_for("sub_font.italic") != null, "sub font section shows")
	fp.field_for("sub_font.italic").get_node("%Check").button_pressed = true
	t.eq(ed.model.get_value("sub_font.italic"), true, "sub font italic sends set")
