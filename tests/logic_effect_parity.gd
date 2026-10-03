extends RefCounted
## v2 연출 편집이 명령·실행 취소·저장·리플레이 경로를 끝까지 보존하는지 검사한다.

const Model := preload("res://app/logic/editor_model.gd")
const DocApi := preload("res://app/logic/doc_api.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const Replay := preload("res://app/logic/replay.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")


func run(t) -> void:
	_migration(t)
	_selection(t)
	_round_trip_replay(t)
	_validation(t)


func _migration(t) -> void:
	var old := {"format": "text_fx", "format_version": 1, "text": "기록", "sub_text": "첫 종",
		"layout": {"letter_spacing": 0.2},
		"timeline": {"enter": {"effect": "pop", "easing": "elastic_out", "params": {"from_scale": 0.35}},
			"exit": {"easing": "sine_in"}}}
	var original := old.duplicate(true)
	var d := DocApi.normalize(old)
	t.eq(old, original, "migration leaves input untouched")
	t.eq(d["format_version"], 2.0, "v1 migrates to document v2")
	t.eq(DocApi.normalize(d), d, "migration is idempotent")
	t.near(d["layout"]["sub"]["letter_spacing"], 0.2, 0.00001, "v1 sub keeps inherited letter spacing")
	t.eq(d["timeline"]["enter"]["easing"], "elastic_out", "v1 explicit entrance easing survives")
	t.eq(d["timeline"]["exit"]["easing"], "sine_in", "v1 explicit exit easing survives")
	t.near(d["timeline"]["enter"]["params"]["from_scale"], 0.35, 0.00001, "v1 effect parameters survive")
	t.eq(d["timeline"]["hold"]["scope"], "hold", "v1 keeps hold-only scope")
	t.eq(d["timeline"]["sub_enter"], null, "v1 keeps shared sub timing")
	t.eq(d["background"]["type"], "none", "v1 remains transparent")
	var m = Model.new()
	t.ok(m.apply({"op": "load_doc", "doc": old}), "v1 imports through command path")
	t.eq(m.doc_hash(), JsonUtil.stable_hash(d), "load and normalize migrate identically")
	var ev := Evaluator.new(m.doc)
	t.ok(ev.evaluate(0.2)[0].visible, "migrated runtime still renders entrance")


func _selection(t) -> void:
	var m = Model.new()
	m.apply({"op": "set", "path": "timeline.enter.params.distance", "value": 4.0})
	m.apply({"op": "set", "path": "timeline.enter.easing", "value": "linear"})
	var before := m.doc_hash()
	var changes: Array = []
	m.changed.connect(func(paths): changes.append(paths))
	t.ok(m.apply({"op": "select_effect", "segment": "enter", "effect": "pop"}), "select pop command")
	var after := m.doc_hash()
	t.eq(changes.size(), 1, "selection emits one atomic document change")
	t.eq(m.get_value("timeline.enter.easing"), "auto", "new selection uses effect-aware easing")
	t.eq(Enter.resolve_easing("pop", m.get_value("timeline.enter.easing")), "back_out", "selected pop actually overshoots")
	t.eq(m.get_value("timeline.enter.params.distance"), null, "old effect parameters are removed")
	t.near(m.get_value("timeline.enter.params.from_scale"), 0.2, 0.00001, "new effect uses its own parameters")
	t.ok(m.apply({"op": "undo"}), "undo selection")
	t.eq(m.doc_hash(), before, "one undo restores effect, parameters and easing together")
	t.ok(m.apply({"op": "redo"}), "redo selection")
	t.eq(m.doc_hash(), after, "one redo restores selected effect")
	t.ok(m.apply({"op": "select_effect", "segment": "enter", "effect": "typewriter"}), "select typewriter")
	t.near(m.get_value("timeline.enter.duration"), 0.0, 0.00001, "selected typewriter reveals each glyph instantly")
	t.near(m.get_value("timeline.enter.params.pop"), 0.0, 0.00001, "selected typewriter has no extra pop")
	t.ok(float(m.get_value("timeline.enter.stagger")) > 0.0, "typewriter retains character rhythm")
	t.ok(m.apply({"op": "select_effect", "segment": "exit", "effect": "erase"}), "select sequential erase")
	t.eq(m.get_value("timeline.exit.order"), "reverse", "erase removes characters in reverse")
	t.near(m.get_value("timeline.exit.duration"), 0.0, 0.00001, "erase transition is instantaneous")
	t.ok(m.apply({"op": "select_effect", "segment": "enter", "effect": "block_zoom"}), "select block effect")
	t.eq(m.get_value("timeline.enter.order"), "all", "block selection acts on whole text")
	t.ok(float(m.get_value("timeline.enter.duration")) > 0.0, "moving from instant to animated effect restores transition")
	t.ok(m.apply({"op": "select_effect", "segment": "sub_enter", "effect": "rise"}), "selection enables independent sub")
	t.eq(m.get_value("timeline.sub_enter.effect"), "rise", "sub effect selected")
	t.ok(m.apply({"op": "select_effect", "segment": "sub_enter", "effect": "same"}), "sub effect may inherit main")
	t.eq(m.get_value("timeline.sub_enter.effect"), "same", "same remains explicit for runtime timing")


func _round_trip_replay(t) -> void:
	var m = Model.new()
	var log = OpLog.create(91, m.doc, "ko")
	var commands := [
		{"op": "set_text", "text": "첫 종\n\n둘째 종", "sub_text": "서리목 등대"},
		{"op": "set_mode", "mode": "trailer"},
		{"op": "select_effect", "segment": "enter", "effect": "center_split"},
		{"op": "set", "path": "timeline.enter.params.overlap_hold", "value": 0.45},
		{"op": "set", "path": "timeline.enter.order", "value": "sweep"},
		{"op": "set", "path": "timeline.enter.params.line_stagger", "value": 0.3},
		{"op": "set", "path": "timeline.enter.params.sweep_duration", "value": 0.5},
		{"op": "set", "path": "timeline.enter.params.cursor", "value": true},
		{"op": "set", "path": "timeline.enter.params.cursor_color", "value": "#33BBFFFF"},
		{"op": "set", "path": "timeline.lead_in", "value": 0.2},
		{"op": "set", "path": "timeline.lead_out", "value": 0.3},
		{"op": "set", "path": "timeline.split_pages", "value": false},
		{"op": "set", "path": "timeline.exit_between_pages", "value": false},
		{"op": "set", "path": "timeline.hold.scope", "value": "visible"},
		{"op": "select_effect", "segment": "sub_enter", "effect": "blur"},
		{"op": "set", "path": "timeline.sub_enter.delay", "value": -0.2},
		{"op": "set", "path": "layout.sub.letter_spacing", "value": 0.15},
		{"op": "list_add", "path": "timeline.hold.effects", "value": "glow_pulse"},
		{"op": "list_add", "path": "decorations", "value": "tape"},
		{"op": "set", "path": "decorations.0.stripe_speed", "value": -48.0},
		{"op": "set", "path": "decorations.0.lead_text", "value": true},
		{"op": "set", "path": "decorations.0.exit_duration", "value": 0.4},
		{"op": "set", "path": "background.type", "value": "vignette"},
		{"op": "set", "path": "background.color", "value": "#14263AFF"},
		{"op": "set", "path": "style.fill.gradient.space", "value": "line"},
		{"op": "undo"}, {"op": "redo"}, {"op": "seek", "t": 0.8},
		{"op": "export", "kind": "doc_string"},
	]
	for cmd in commands:
		log.append(cmd)
		t.ok(m.apply(cmd), "v2 command %s: %s" % [str(cmd), m.last_error])
	var saved: String = m.last_export["text"]
	t.ok(saved.begins_with("TFX1:") and not saved.contains("\n"), "v2 document uses the single-line container")
	var loaded = Model.new()
	t.ok(loaded.apply({"op": "load_doc", "string": saved}), "v2 document string reloads")
	t.eq(loaded.doc_hash(), m.doc_hash(), "all v2 fields round-trip without drift")
	t.ok(loaded.apply({"op": "export", "kind": "doc_json"}), "v2 document exports as JSON")
	var from_json = Model.new()
	t.ok(from_json.apply({"op": "load_doc", "doc": JsonUtil.parse(loaded.last_export["text"])}), "v2 JSON reloads")
	t.eq(from_json.doc_hash(), m.doc_hash(), "JSON and string documents agree")
	var replay := Replay.run_string(log.serialize())
	t.ok(replay["ok"], "v2 operation log parses")
	t.eq(replay["rejected"], 0, "all saved v2 operations replay")
	t.eq(replay["hash"], m.doc_hash(), "v2 replay reproduces document hash")
	t.eq(replay["export_hash"], m.last_export["hash"], "v2 replay reproduces export hash")
	t.eq(replay["model"].time, 0.8, "v2 replay restores seek")
	var a := Evaluator.new(m.doc)
	var b := Evaluator.new(replay["doc"])
	t.eq(a.evaluate(0.8)[0].to_dict(), b.evaluate(0.8)[0].to_dict(), "v2 replay reproduces runtime state")


func _validation(t) -> void:
	var m = Model.new()
	m.apply({"op": "select_effect", "segment": "sub_enter", "effect": "fade"})
	m.apply({"op": "set", "path": "timeline.scroll", "value": Doc.default_scroll()})
	m.apply({"op": "list_add", "path": "decorations", "value": "tape"})
	var before := m.doc_hash()
	var bad := [
		["timeline.lead_in", -0.1], ["timeline.lead_out", 61.0], ["timeline.hold.scope", "everywhere"],
		["timeline.sub_enter.delay", -31.0], ["timeline.scroll.edge_fade", 0.6],
		["layout.sub.letter_spacing", 3.0], ["timeline.enter.params.overlap_hold", -1.0],
		["timeline.enter.params.cursor_color", "red"], ["timeline.enter.params.cursor", "yes"],
		["timeline.enter.params.impact_brightness", 2.0], ["timeline.enter.params.slices", 2.5],
		["decorations.0.stripe_width", 0.0], ["decorations.0.stripe_speed", 501.0],
		["decorations.0.exit_duration", -1.0], ["background.opacity", 1.1],
		["background.extent", 0.0], ["timeline.split_pages", 1],
	]
	for pair in bad:
		t.ok(not m.apply({"op": "set", "path": pair[0], "value": pair[1]}), "invalid v2 value rejected: %s" % pair[0])
	for cmd in [
		{"op": "select_effect", "segment": "hold", "effect": "fade"},
		{"op": "select_effect", "segment": "enter", "effect": "same"},
		{"op": "select_effect", "segment": "exit", "effect": "missing"},
		{"op": "load_doc", "doc": {"timeline": {"sub_enter": {"effect": "missing"}}}},
		{"op": "load_doc", "doc": {"background": {"color": "red"}}},
		{"op": "load_doc", "doc": {"timeline": {"lead_in": -1.0}}},
	]:
		t.ok(not m.apply(cmd), "invalid v2 command/source rejected: %s" % str(cmd))
	t.eq(m.doc_hash(), before, "rejected v2 changes leave document intact")
