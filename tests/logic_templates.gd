extends RefCounted
## 에디터 로직: 템플릿 등록부, 적용 결과 유효성, 언어 전환 시 견본 문장 교체.

const Templates := preload("res://app/logic/templates.gd")
const EditorModel := preload("res://app/logic/editor_model.gd")
const DocApi := preload("res://app/logic/doc_api.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")

const REQUIRED_GROUPS := {
	"message": ["battle", "explore", "narrator", "scene_time", "check"],
	"trailer": ["typewriter", "line", "flow", "all_at_once", "scroll", "center_stamp", "center_split"],
	"caption": ["converge", "rise", "tracking", "center_split"],
}
const GALMURI := "res://assets/fonts/galmuri/Galmuri11.ttf"
const CINEMATIC_EFFECTS := ["fragment_assemble", "ink_bleed", "ember_dissolve", "dimensional_rift",
	"afterimage_overtake", "liquid_merge", "frost_crystal", "thread_stitch", "surface_pressure", "text_morph"]


func run(t) -> void:
	t.eq(Templates.load_errors().size(), 0, "templates load cleanly: %s" % str(Templates.load_errors()))
	var n := Templates.ids().size()
	t.ok(n >= 47, "original and cinematic templates are registered (%d)" % n)
	for mode in REQUIRED_GROUPS:
		for g in REQUIRED_GROUPS[mode]:
			t.ok(not Templates.by_mode(mode, g).is_empty(), "group %s/%s has templates" % [mode, g])
	for tpl in Templates.all():
		_check_template(t, tpl)
	_locale_switch(t)
	_cinematic(t)


func _check_template(t, tpl: Dictionary) -> void:
	var id: String = tpl.id
	t.ok(tpl.get("icon") is String and tpl.icon != "", "%s icon" % id)
	t.ok(tpl.group in Templates.groups(tpl.mode), "%s group listed" % id)
	var want_loop := "loop_hold" if tpl.group in ["narrator", "check"] else "once"
	t.eq(tpl.get("loop"), want_loop, "%s loop default" % id)
	var texts := {}
	for loc in DocSchema.LOCALES:
		t.ok(tpl.name.has(loc) and tpl.text.has(loc), "%s has %s name/text" % [id, loc])
		var m = EditorModel.new({}, loc)
		var ok: bool = m.apply({"op": "apply_template", "id": id})
		t.ok(ok, "%s applies in %s (%s)" % [id, loc, m.last_error])
		if not ok:
			continue
		var doc: Dictionary = m.doc
		t.eq(DocApi.validate(doc).size(), 0, "%s/%s valid" % [id, loc])
		t.eq(DocApi.normalize(doc), doc, "%s/%s normalized (idempotent)" % [id, loc])
		t.eq(doc.mode, tpl.mode, "%s mode" % id)
		t.eq(doc.timeline.loop, want_loop, "%s doc loop" % id)
		t.ok(doc.text != "", "%s/%s text" % [id, loc])
		texts[loc] = doc.text
		if loc == "ja":
			t.ok(doc.font.path == GALMURI, "%s ja uses Galmuri" % id)
		t.ok(ResourceLoader.exists(doc.font.path), "%s/%s font exists" % [id, loc])
		if doc.sub_font is Dictionary:
			t.ok(ResourceLoader.exists(doc.sub_font.path), "%s/%s sub_font exists" % [id, loc])
	t.ok(texts.get("ko") != texts.get("en") and texts.get("ko") != texts.get("ja"), "%s texts differ per locale" % id)
	if tpl.mode == "trailer" and tpl.group != "center_stamp":
		t.ok(str(texts.get("ko", "")).count("\n") >= 2, "%s trailer is multi-line" % id)
	if tpl.mode == "caption":
		t.ok(tpl.get("sub_text") is Dictionary, "%s caption has sub_text" % id)


func _locale_switch(t) -> void:
	var m = EditorModel.new({}, "ko")
	m.apply({"op": "apply_template", "id": "msg_explore_tide"})
	t.eq(m.doc.text, "썰물이 시작된다", "ko sample")
	m.apply({"op": "set", "path": "style.outline.size", "value": 9})
	t.ok(m.apply({"op": "set_locale", "locale": "ja"}), "switch to ja")
	t.eq(m.doc.text, "引き潮が始まる", "ja sample replaces untouched text")
	t.eq(m.doc.font.path, GALMURI, "ja font override applied")
	t.eq(m.doc.style.outline.size, 9.0, "user style edit kept")
	m.apply({"op": "set_locale", "locale": "en"})
	t.eq(m.doc.text, "The Tide Recedes", "en sample")
	t.eq(m.doc.name, "Ebb Tide", "en name")
	m.apply({"op": "set_text", "text": "My own words"})
	m.apply({"op": "set_locale", "locale": "ko"})
	t.eq(m.doc.text, "My own words", "edited text is not replaced")
	t.eq(m.doc.name, "썰물", "untouched name still follows locale")
	# Cinzel 영어 덮어쓰기 + 보조 글꼴
	var c = EditorModel.new({}, "en")
	c.apply({"op": "apply_template", "id": "cap_converge"})
	t.ok(str(c.doc.font.path).find("Cinzel") >= 0, "en caption uses Cinzel")
	t.ok(c.doc.sub_font is Dictionary, "en caption sub_font set")
	c.apply({"op": "set_locale", "locale": "ko"})
	t.ok(str(c.doc.font.path).find("Pretendard") >= 0, "ko caption back to Pretendard")
	t.eq(c.doc.sub_font, null, "ko caption sub_font reset")
	# keep_text
	var k = EditorModel.new({}, "ko")
	k.apply({"op": "set_text", "text": "내 문장"})
	k.apply({"op": "apply_template", "id": "msg_battle_engage", "keep_text": true})
	t.eq(k.doc.text, "내 문장", "keep_text preserves text")


func _cinematic(t) -> void:
	for effect in CINEMATIC_EFFECTS:
		var id: String = "msg_cinematic_" + effect
		t.ok(Templates.has(id), "cinematic template exists: %s" % effect)
		var m = EditorModel.new({}, "ko")
		t.ok(m.apply({"op": "apply_template", "id": id}), "%s template applies" % effect)
		var segment := "exit" if effect == "ember_dissolve" else "enter"
		t.eq(m.get_value("timeline." + segment + ".effect"), effect, "%s template uses the new effect" % effect)
		t.ok(m.apply({"op": "select_effect", "segment": segment, "effect": effect}), "%s is command-selectable" % effect)
		if effect != "text_morph":
			for param in ["intensity", "detail", "color", "distance"]:
				var path: String = "timeline." + segment + ".params." + param
				t.ok(DocSchema.rule_for(path) != null, "%s has editable %s" % [effect, param])
				t.ok(m.apply({"op": "set", "path": path, "value": m.get_value(path)}), "%s parameter uses set command" % param)
	var morph = EditorModel.new({}, "ko")
	morph.apply({"op": "apply_template", "id": "msg_cinematic_text_morph"})
	morph.apply({"op": "set_locale", "locale": "ja"})
	t.eq(morph.get_value("timeline.enter.params.from_text"), "灯火は生きている", "morph source follows template locale")
	t.eq(morph.doc.text, "灯火は消えている", "morph target follows template locale")
	morph.apply({"op": "set", "path": "timeline.enter.params.from_text", "value": "내가 쓴 첫 문장"})
	morph.apply({"op": "set_locale", "locale": "en"})
	t.eq(morph.get_value("timeline.enter.params.from_text"), "내가 쓴 첫 문장", "edited morph source survives locale change")
	morph.apply({"op": "set_text", "text": "마지막 기록", "sub_text": "등지기"})
	t.ok(morph.apply({"op": "select_effect", "segment": "sub_enter", "effect": "text_morph"}), "sub text morph selectable")
	t.eq(morph.get_value("timeline.sub_enter.params.from_text"), "등지기", "sub morph captures current sub text")
	t.ok(not morph.apply({"op": "select_effect", "segment": "exit", "effect": "text_morph"}), "morph cannot be selected for exit")
	t.ok(morph.apply({"op": "select_effect", "segment": "enter", "effect": "text_morph"}), "main morph selectable")
	t.eq(morph.get_value("timeline.enter.params.from_text"), "마지막 기록", "main morph captures current text")
	t.eq(morph.get_value("timeline.enter.order"), "all", "morph selects one shared transition")
	t.ok(not morph.apply({"op": "set", "path": "timeline.enter.params.readable_ratio", "value": 0.9}), "morph readable ratio is bounded")
