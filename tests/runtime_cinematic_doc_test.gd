extends RefCounted
## 새 연출의 문서 호환·검증·정규화. 잘못된 입력은 보정 전에 거부한다.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Rules := preload("res://addons/text_fx/core/fx_cinematic_validation.gd")
const Codec := preload("res://addons/text_fx/core/fx_codec.gd")


func run(t) -> void:
	for version in [1, 2]:
		var old := {"format": "text_fx", "format_version": version, "text": "이전 문서",
			"timeline": {"enter": {"effect": "fade", "duration": 0.7, "easing": "sine_in"}}}
		var before := old.duplicate(true)
		t.ok(Doc.validate(old).is_empty(), "version %d still loads" % version)
		var d := Doc.normalize(old)
		t.eq(d.format_version, 3, "old document migrates to v3")
		t.eq(d.timeline.enter.effect, "fade", "old effect unchanged")
		t.eq(d.timeline.enter.easing, "sine_in", "old timing unchanged")
		t.eq(old, before, "migration leaves source intact")
		t.eq(Doc.normalize(d), d, "migration is idempotent")
	for id in Rules.IDS:
		for segment in ["enter", "exit", "sub_enter"]:
			var d := Doc.defaults()
			if segment == "sub_enter":
				d.timeline.sub_enter = Doc.default_sub_enter()
			d.timeline[segment].effect = id
			d.timeline[segment].params = {"intensity": 1.7, "distance": 2.0, "detail": 12, "color": "#ab12cd"}
			t.ok(Doc.validate(d).is_empty(), "%s %s valid" % [segment, id])
			var n := Doc.normalize(d)
			t.eq(n.timeline[segment].params.color, "#AB12CDFF", "effect color canonical")
			t.eq(Doc.normalize(n), n, "new params normalize idempotently")
			t.eq(Doc.normalize(Codec.decode(Codec.encode(n))), n, "new params survive single-line codec")
			for pair in [["intensity", -1], ["intensity", INF], ["distance", 5.1],
					["detail", 1], ["detail", 8.5], ["color", "bad"]]:
				var invalid: Dictionary = d.duplicate(true)
				invalid.timeline[segment].params[pair[0]] = pair[1]
				t.ok(not Doc.validate(invalid).is_empty(), "%s rejects %s" % [id, str(pair)])
	for segment in ["enter", "sub_enter"]:
		var d := Doc.defaults()
		if segment == "sub_enter":
			d.timeline.sub_enter = Doc.default_sub_enter()
		d.timeline[segment].effect = "text_morph"
		d.timeline[segment].params = {"from_text": "닫힌 등대\n기억의 문", "readable_ratio": 0.3, "intensity": 1.0}
		t.ok(Doc.validate(d).is_empty(), "morph source string accepted")
		var n := Doc.normalize(d)
		t.eq(Doc.normalize(Codec.decode(Codec.encode(n))), n, "morph text round trips")
		for pair in [["from_text", 7], ["from_text", "x".repeat(4001)], ["readable_ratio", 0.9], ["readable_ratio", NAN]]:
			var invalid: Dictionary = d.duplicate(true)
			invalid.timeline[segment].params[pair[0]] = pair[1]
			t.ok(not Doc.validate(invalid).is_empty(), "invalid morph source/ratio rejected")
	var bad_exit := Doc.defaults()
	bad_exit.timeline.exit.effect = "text_morph"
	t.ok(not Doc.validate(bad_exit).is_empty(), "morph is entrance-only")
