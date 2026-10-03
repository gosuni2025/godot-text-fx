extends RefCounted
## TextFxBakedExport: 베이크 JSON 형태·결정론·center_stamp 오버레이 슬롯.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Baked := preload("res://addons/text_fx/core/fx_baked_export.gd")


func run(t) -> void:
	var d := Doc.defaults()
	d["text"] = "교전 개시"
	d["timeline"]["hold"]["duration"] = 0.5
	var b := Baked.bake(d, 20.0)
	t.eq(b["format"], "text_fx_baked", "format")
	t.eq(b["format_version"], 1, "version")
	t.eq(b["fps"], 20.0, "fps")
	t.eq(b["canvas"], {"width": 1280, "height": 720}, "canvas")
	t.eq(b["glyphs"].size(), 4, "glyph count (no spaces)")
	t.eq(b["frames"].size(), int(round(float(b["duration"]) * 20.0)), "frame count = duration * fps")
	var ok_shape := true
	for fr in b["frames"]:
		if fr.size() != 4:
			ok_shape = false
		for v in fr:
			if v.size() != 6:
				ok_shape = false
	t.ok(ok_shape, "frames [frame][glyph][6]")
	var g0: Dictionary = b["glyphs"][0]
	for k in ["index", "char", "role", "font_size", "base", "rot"]:
		t.ok(g0.has(k), "glyph has " + k)
	t.eq(b["frames"][0][0][5], 0.0, "first glyph hidden at t=0")
	var mid: Array = b["frames"][int(b["frames"].size() / 2)][0]
	t.eq(mid[5], 1.0, "visible in hold")
	t.eq(mid[0], 0.0, "no offset in hold")
	# 3자리 반올림
	var all_rounded := true
	for fr in b["frames"]:
		for v in fr:
			for x in v:
				if absf(float(x) * 1000.0 - round(float(x) * 1000.0)) > 0.001:
					all_rounded = false
	t.ok(all_rounded, "values rounded to 3 decimals")
	t.eq(JSON.stringify(Baked.bake(d, 20.0)), JSON.stringify(b), "bake deterministic")
	var parsed: Variant = JSON.parse_string(JSON.stringify(b))
	t.ok(parsed is Dictionary and parsed["frames"].size() == b["frames"].size(), "json serializable")
	# loop_hold 마커
	d["timeline"]["loop"] = "loop_hold"
	var bh := Baked.bake(d, 10.0)
	t.eq(bh["loop"], "loop_hold", "loop field")
	t.ok(float(bh["markers"]["hold_end"]) > float(bh["markers"]["hold_start"]), "hold markers")
	# center_stamp 오버레이 슬롯
	d["timeline"]["loop"] = "once"
	d["timeline"]["enter"]["effect"] = "center_stamp"
	var bs := Baked.bake(d, 30.0)
	t.eq(bs["glyphs"].size(), 8, "overlay glyph slots appended")
	t.eq(bs["glyphs"][4]["role"], "overlay", "overlay role")
	t.eq(bs["frames"][2][4][5] > 0.0, true, "overlay visible early")
	t.eq(bs["frames"][2][0][5], 0.0, "normal glyph hidden early")
