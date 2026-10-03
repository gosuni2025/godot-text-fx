extends RefCounted
## TextFxDoc normalize/validate/경로 도우미, TextFxCodec 왕복.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Codec := preload("res://addons/text_fx/core/fx_codec.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")


func run(t) -> void:
	var d := Doc.normalize({})
	t.eq(d["format"], "text_fx", "format")
	t.eq(d["format_version"], Doc.FORMAT_VERSION, "format_version")
	t.eq(Doc.validate(d).size(), 0, "normalized defaults validate: %s" % str(Doc.validate(d)))
	t.eq(Doc.normalize(d), d, "normalize idempotent")

	var raw := {
		"text": "교전 개시", "canvas": {"width": 640.0}, "mode": "nope", "unknown_field": {"keep": 1},
		"layout": {"offset": [3, 4], "font_size": 64.0, "align": "left"},
		"style": {"outline": {"size": 9}, "fill": {"color": "#ff0000"}},
		"sub_style": {"fill": {"color": "#00FF00"}},
		"decorations": [{"type": "frame", "color": "#123456"}, {"type": "bogus"}],
		"timeline": {"enter": {"effect": "slide", "params": {"distance": 2}}, "hold": {"effects": [{"type": "wave"}, {"type": "nope"}]},
			"scroll": {"speed": 30}},
	}
	var errs := Doc.validate(raw)
	t.ok(errs.size() >= 3, "validate reports bad mode/decoration/hold type: %s" % str(errs))
	var n := Doc.normalize(raw)
	t.eq(n["mode"], "message", "invalid enum corrected")
	t.eq(n["unknown_field"], {"keep": 1}, "unknown field preserved")
	t.eq(typeof(n["canvas"]["width"]), TYPE_INT, "canvas width coerced to int")
	t.eq(n["canvas"]["height"], 720, "missing canvas height default")
	t.eq(n["layout"]["offset"], [3.0, 4.0], "vector coerced to floats")
	t.eq(typeof(n["layout"]["font_size"]), TYPE_INT, "font_size int")
	t.eq(n["style"]["fill"]["color"], "#FF0000FF", "color canonical")
	t.eq(n["style"]["outline"]["size"], 9.0, "outline size float")
	t.eq(n["sub_style"]["outline"]["size"], 9.0, "sub_style inherits style")
	t.eq(n["sub_style"]["fill"]["color"], "#00FF00FF", "sub_style override")
	t.eq(n["decorations"].size(), 2, "decorations kept")
	t.eq(n["decorations"][1]["type"], "underline", "bad decoration type corrected")
	t.eq(n["decorations"][0]["animate"], "grow_center", "decoration defaults")
	t.eq(n["timeline"]["enter"]["params"]["distance"], 2.0, "params merged")
	t.eq(n["timeline"]["enter"]["params"]["dir"], "up", "params default filled")
	t.eq(n["timeline"]["hold"]["effects"].size(), 1, "unknown hold effect dropped")
	t.eq(n["timeline"]["hold"]["effects"][0]["wavelength"], 8.0, "hold defaults")
	t.eq(n["timeline"]["scroll"]["speed"], 30.0, "scroll merged")
	t.eq(Doc.normalize(n), n, "normalize idempotent (complex)")
	t.eq(Doc.validate(n).size(), 0, "normalized complex validates: %s" % str(Doc.validate(n)))

	# JSON 왕복: 모든 숫자가 float이 되어도 normalize 후 동일
	var json := Doc.to_json(n)
	var back := Doc.normalize(Doc.parse_json(json))
	t.eq(back, n, "json round trip")
	var nb := back.duplicate(true)
	var nn := n.duplicate(true)
	nb.erase("unknown_field")
	nn.erase("unknown_field")
	t.eq(JSON.stringify(nb, "", true), JSON.stringify(nn, "", true), "json canonical string equal (known fields)")
	t.eq(Doc.parse_json("{bad"), {}, "bad json -> {}")

	# 클립보드 코덱
	var s := Codec.encode(n)
	t.ok(s.begins_with("TFX1:") and s.find("\n") < 0, "codec single line prefix")
	t.eq(Doc.normalize(Codec.decode(s)), n, "codec round trip")
	t.eq(Codec.decode("TFX1:@@@"), null, "codec bad -> null")
	t.eq(Codec.encode(n), s, "codec deterministic")

	# 경로
	var c := Doc.normalize({})
	t.ok(Doc.set_value(c, "style.outline.size", 12.0), "set_value")
	t.eq(Doc.get_value(c, "style.outline.size"), 12.0, "get_value")
	t.eq(Doc.get_value(c, "no.such.path", "x"), "x", "get_value default")
	c["decorations"] = [Doc.default_decoration("band")]
	t.ok(Doc.set_value(c, "decorations.0.color", "#FF00FFFF"), "set_value array index")
	t.eq(Doc.get_value(c, "decorations.0.color"), "#FF00FFFF", "get_value array index")

	# 표 일관성
	for id in Enter.IDS:
		t.ok(Enter.DEFAULTS.has(id), "enter defaults for " + id)
	for ty in Hold.TYPES:
		t.eq(Hold.default_params(ty)["type"], ty, "hold default type " + ty)
	for e in Easing.NAMES:
		t.near(Easing.apply(e, 0.0), 0.0, 0.001, "ease %s(0)" % e)
		t.near(Easing.apply(e, 1.0), 1.0, 0.001, "ease %s(1)" % e)
	t.near(Easing.apply("cubic_in", 0.5), 0.125, 0.0001, "cubic_in")
	t.near(Easing.apply("quad_in_out", 0.25), 0.125, 0.0001, "quad_in_out")
	t.ok(Easing.apply("back_out", 0.6) > 1.0, "back_out overshoots")
	t.near(Doc.parse_color("#11223344").a, 0x44 / 255.0, 0.002, "parse rgba alpha")
	t.eq(Doc.color_to_hex(Color(1, 0, 0, 1)), "#FF0000FF", "color_to_hex")
