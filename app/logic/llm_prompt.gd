extends RefCounted
## LLM 프롬프트 내보내기: 문서를 다른 엔진(Unity·Unreal·웹 등)에서 다시 구현하도록 LLM에게 줄 영어 명세 문서로 만든다.
## 레이아웃·타임라인은 런타임 evaluator로 계산한 기준값(글자 위치·지연·페이지 구간)을 넣고, 효과 수식은 참조표에서 가져온다.
## 결과는 문서·폰트가 같으면 항상 같은 문자열이다(결정론).

const Ref := preload("res://app/logic/llm_prompt_reference.gd")
const EVALUATOR_PATH := "res://addons/text_fx/core/fx_evaluator.gd"
const ENTER_PATH := "res://addons/text_fx/core/fx_effects_enter.gd"
const MAX_GLYPH_ROWS := 400


## { ok, text } 또는 { ok:false, error }.
static func build(doc: Dictionary) -> Dictionary:
	if not ResourceLoader.exists(EVALUATOR_PATH) or not ResourceLoader.exists(ENTER_PATH):
		return {"ok": false, "error": "llm prompt unavailable: runtime addon missing"}
	var ev = load(EVALUATOR_PATH).new(doc.duplicate(true))
	var enter_fx = load(ENTER_PATH)
	var d: Dictionary = ev.doc
	var out := PackedStringArray()
	_intro(out, d)
	_overview(out, d, ev)
	_layout_and_style(out, d, ev)
	_timeline(out, d, ev, enter_fx)
	_glyphs(out, ev)
	_decor(out, d)
	_effect_reference(out, d, enter_fx)
	out.append("## 9. Deterministic randomness\n\n" + Ref.HASH + "\n")
	out.append("## Appendix: source document (text_fx format_version %d, source of truth)\n" % int(d.get("format_version", 3)))
	out.append("```json\n" + JSON.stringify(doc, "  ", true) + "\n```\n")
	return {"ok": true, "text": "\n".join(out)}


static func _intro(out: PackedStringArray, d: Dictionary) -> void:
	out.append("# Text animation spec: %s\n" % _q(d.get("name", "")))
	out.append("""Implement the text animation described below in my engine/framework: **[TARGET ENGINE / LANGUAGE — e.g. Unity C#, Unreal, Cocos, Phaser, CSS+JS]**.
It was authored in the Godot Text FX editor and exported as an engine-independent spec. Sections 1-8 explain it; the JSON appendix is the source of truth for every value.

Requirements:
- Build a reusable component that plays this animation for any main text (and optional sub text). Keep every number as a named, tweakable parameter.
- Separate logic from rendering: a pure function `evaluate(t)` returns per-glyph state (position, scale, rotation, alpha, tint, blur, clip...) for time t; the renderer only draws that state. No per-frame accumulation, so seek/scrub/reverse give identical frames.
- Coordinates: a virtual canvas in px, origin top-left, y down. Fit it to the screen (contain) by scaling.
- Draw each character as its own sprite/quad around its center (pivot = glyph box center).
- API: play(from = 0), stop(), seek(t), finish() (ends a loop_hold early by playing the exit), plus events: started, entered (enter finished), finished.
- Use the seeded hash in section 9 for all randomness; never a global random generator.
- Where the engine cannot match a feature exactly (blur, glow, outline, gradient), use the closest equivalent and list the approximations you made.
""")


static func _overview(out: PackedStringArray, d: Dictionary, ev) -> void:
	var tl: Dictionary = d["timeline"]
	out.append("## 1. Overview\n")
	out.append("- Mode: %s (message = cut-in, trailer = multi-page, caption = place/time caption)" % d["mode"])
	out.append("- Canvas: %d x %d px" % [int(d["canvas"]["width"]), int(d["canvas"]["height"])])
	out.append("- Main text: %s" % _q(d["text"]))
	out.append("- Sub text: %s" % (_q(d["sub_text"]) if str(d["sub_text"]) != "" else "(none)"))
	out.append("- Pages: %d (a blank line splits pages in trailer mode)" % int(ev.timeline.page_count))
	out.append("- Total duration: %s s; loop: %s (%s)" % [_n(ev.get_duration()), tl["loop"], {
		"once": "play once and stop", "loop_all": "repeat the whole animation",
		"loop_hold": "after entering, repeat the hold section until finish() is called, then exit",
	}.get(str(tl["loop"]), "")])
	out.append("- Seed: %d\n" % int(d["seed"]))


static func _layout_and_style(out: PackedStringArray, d: Dictionary, ev) -> void:
	var L: Dictionary = d["layout"]
	out.append("## 2. Layout\n")
	out.append("- Direction %s, align %s / %s, anchor %s (canvas ratio) + offset %s px" % [L["direction"], L["align"], L["valign"], _v(L["anchor"]), _v(L["offset"])])
	out.append("- Font size %s px (after auto-shrink: %s px), letter spacing %s em, line height %s em, wrap %s, max box %s x %s of canvas" % [
		_n(L["font_size"]), _n(ev.layout["font_size"]), _n(L["letter_spacing"]), _n(L["line_height"]), L["wrap"], _n(L["max_width"]), _n(L["max_height"])])
	out.append("- Sub text: %s px, %s the main text, gap %s em" % [_n(L["sub"]["font_size"]), L["sub"]["position"], _n(L["sub"]["gap"])])
	if L["direction"] == "vertical":
		out.append("- Vertical writing: columns run right to left; Latin letters and long marks are rotated 90 degrees.")
	out.append("- Section 5 lists the computed glyph positions; use them as the reference result.\n")
	out.append("## 3. Look\n")
	for role in ["main", "sub"]:
		var font: Dictionary = d["font"] if role == "main" or d.get("sub_font") == null else d["sub_font"]
		var style: Dictionary = d["style"] if role == "main" or d.get("sub_style") == null else d["sub_style"]
		out.append("- %s font: %s, weight %d%s" % [role.capitalize(), _q(font.get("family", "")), int(font.get("weight", 400)), ", italic" if font.get("italic", false) else ""])
		out.append("  %s" % _style_text(style))
	out.append("- Layer order per glyph: glow (behind) < shadow < outline2 < outline < fill. Draw all glyph backs before any glyph fill so thick outlines never cover a neighbour's fill.\n")


static func _style_text(s: Dictionary) -> String:
	var fill: Dictionary = s["fill"]
	var parts := PackedStringArray()
	if fill["type"] == "gradient":
		var g: Dictionary = fill["gradient"]
		parts.append("fill gradient %s deg (0 = left->right, 90 = top->bottom) over %s, stops %s" % [_n(g["angle"]), g["space"], JSON.stringify(g["stops"])])
	else:
		parts.append("fill %s" % fill["color"])
	for k in ["outline", "outline2"]:
		if s[k]["enabled"]:
			parts.append("%s %s px %s" % [k, _n(s[k]["size"]), s[k]["color"]])
	if s["shadow"]["enabled"]:
		parts.append("shadow offset %s blur %s px %s" % [_v(s["shadow"]["offset"]), _n(s["shadow"]["blur"]), s["shadow"]["color"]])
	if s["glow"]["enabled"]:
		parts.append("glow %s px %s strength %s" % [_n(s["glow"]["size"]), s["glow"]["color"], _n(s["glow"]["strength"])])
	parts.append("opacity %s" % _n(s["opacity"]))
	return "; ".join(parts)


static func _timeline(out: PackedStringArray, d: Dictionary, ev, enter_fx) -> void:
	var tl: Dictionary = d["timeline"]
	out.append("## 4. Timeline\n")
	out.append("Order: lead_in (%s s) -> for each page: enter -> hold -> exit (gap %s s between pages) -> lead_out (%s s)." % [_n(tl["lead_in"]), _n(tl["page_gap"]), _n(tl["lead_out"])])
	out.append("Per glyph: enter local time = t - page.start - enter_delay; exit local time = t - page.hold_end - exit_delay; p = clamp(local / duration, 0, 1).")
	out.append("Enter: k = 1 - ease(p) (glyph hidden before its delay). Exit: k = ease(p) (hidden after it ends). k = 0 means the glyph sits at rest.\n")
	if tl.get("scroll") is Dictionary:
		out.append("Scroll mode: no pages; the whole block scrolls at %s px/s (horizontal text bottom->top, vertical text left->right), edge fade %s of canvas. Hold effects run the whole time.\n" % [_n(tl["scroll"]["speed"]), _n(tl["scroll"].get("edge_fade", 0.0))])
	out.append("| page | start | enter_end | hold_end | exit_end | exit played |\n|---|---|---|---|---|---|")
	for i in ev.timeline.pages.size():
		var pg: Dictionary = ev.timeline.pages[i]
		out.append("| %d | %s | %s | %s | %s | %s |" % [i, _n(pg["start"]), _n(pg["enter_end"]), _n(pg["hold_end"]), _n(pg["exit_end"]), "yes" if pg["exit_performed"] else "no"])
	out.append("")
	out.append(_segment("Enter", tl["enter"], enter_fx, false))
	if tl.get("sub_enter") is Dictionary:
		out.append(_segment("Sub text enter (starts %s s after the main enter ends)" % _n(tl["sub_enter"].get("delay", 0.0)), tl["sub_enter"], enter_fx, false))
	var hold: Dictionary = tl["hold"]
	var effects := PackedStringArray()
	for e in hold["effects"]:
		var params: Dictionary = e.duplicate()
		params.erase("type")
		effects.append("%s %s" % [e.get("type", ""), JSON.stringify(params, "", true)])
	out.append("- Hold: %s s, effects applied in order (scope %s: %s): %s" % [_n(hold["duration"]), hold.get("scope", "hold"),
		"only during hold" if hold.get("scope", "hold") == "hold" else "from enter to exit, time = time since page start (blink still starts at hold)",
		", ".join(effects) if not effects.is_empty() else "none"])
	if tl["exit"]["enabled"]:
		out.append(_segment("Exit", tl["exit"], enter_fx, true))
	else:
		out.append("- Exit: disabled (the last page stays on screen; middle pages %s)" % ("still exit" if tl.get("exit_between_pages", true) else "switch instantly"))
	out.append("")


static func _segment(title: String, seg: Dictionary, enter_fx, is_exit: bool) -> String:
	var effect := str(seg.get("effect", ""))
	var easing: String = enter_fx.resolve_easing(effect, str(seg.get("easing", "auto")), is_exit)
	# 순서 공통 params는 기본값과 다를 때만 적는다.
	var params: Dictionary = seg.get("params", {}).duplicate()
	for key in enter_fx.COMMON:
		if params.has(key) and params[key] == enter_fx.COMMON[key]:
			params.erase(key)
	return "- %s: effect `%s`, order `%s` (%s), duration %s s, stagger %s s, easing %s, params %s" % [title, effect, seg.get("order", "all"),
		Ref.ORDER.get(str(seg.get("order", "all")), ""), _n(seg.get("duration", 0.0)), _n(seg.get("stagger", 0.0)), easing, JSON.stringify(params, "", true)]


static func _glyphs(out: PackedStringArray, ev) -> void:
	var glyphs: Array = ev.layout["glyphs"]
	out.append("## 5. Computed glyphs (reference layout with the original font)\n")
	out.append("pos = glyph box center in canvas px. Delays in seconds relative to page.start (enter) and page.hold_end (exit). Your engine's font metrics may differ slightly; keep the same structure.\n")
	out.append("| i | char | role | page | line | x | y | size | enter_delay | exit_delay |\n|---|---|---|---|---|---|---|---|---|---|")
	for i in mini(glyphs.size(), MAX_GLYPH_ROWS):
		var g: Dictionary = glyphs[i]
		var p: Vector2 = g["pos"]
		out.append("| %d | %s | %s | %d | %d | %s | %s | %s | %s | %s |" % [i, _q(g["char"]), g["role"], int(g["page"]), int(g["line"]),
			_n(p.x), _n(p.y), _n(g["font_size"]), _n(ev.timeline.enter_delay[i]), _n(ev.timeline.exit_delay[i])])
	if glyphs.size() > MAX_GLYPH_ROWS:
		out.append("| ... | %d more glyphs omitted | | | | | | | | |" % (glyphs.size() - MAX_GLYPH_ROWS))
	out.append("")


static func _decor(out: PackedStringArray, d: Dictionary) -> void:
	var decorations: Array = d["decorations"]
	var bg: Dictionary = d["background"]
	out.append("## 6. Decorations and background\n")
	if decorations.is_empty():
		out.append("- Decorations: none")
	for dec in decorations:
		out.append("- Decoration `%s` (%s): %s" % [dec.get("type", ""), Ref.DECORATION.get(str(dec.get("type", "")), ""), JSON.stringify(dec, "", true)])
	if not decorations.is_empty():
		out.append("  margin/length/arm_length are ratios of the main text block (margin in em), thickness/radius/stripe_width in px, times in s. animate: none | fade | grow_center | grow_start | shape (shape-specific path). lead_text=true delays the text until the decoration has entered.")
	if bg["type"] == "none":
		out.append("- Result background: none")
	else:
		out.append("- Result background `%s` (solid fill / vignette / bottom or top gradient covering `extent` of the canvas): color %s, opacity %s, fades with the text: %s" % [bg["type"], bg["color"], _n(bg["opacity"]), bg.get("sync_fade", true)])
	out.append("")


static func _effect_reference(out: PackedStringArray, d: Dictionary, enter_fx) -> void:
	var tl: Dictionary = d["timeline"]
	var used := PackedStringArray()
	var segments: Array = [tl["enter"]]
	if tl.get("sub_enter") is Dictionary:
		segments.append(tl["sub_enter"])
	if tl["exit"]["enabled"]:
		segments.append(tl["exit"])
	for seg in segments:
		var id := str(seg.get("effect", ""))
		if Ref.ENTER.has(id) and not used.has(id):
			used.append(id)
	out.append("## 7. Effect reference (only effects used here)\n")
	out.append("Symbols: k = hidden amount (0 at rest, 1 fully hidden), kc = clamp(k, 0, 1), em = glyph font size px, i = glyph index, local = seconds since the glyph's segment started, H/S = hash (section 9). Effects multiply/add onto the rest state (pos, scale 1, rotation 0, alpha 1).\n")
	for id in used:
		out.append("- `%s`: %s" % [id, Ref.ENTER[id]])
		if id in enter_fx.BLOCK_EFFECTS:
			out.append("  " + Ref.BLOCK_NOTE)
		if id in Ref.CINEMATIC_IDS:
			out.append("  " + Ref.CINEMATIC_NOTE)
	var holds := PackedStringArray()
	for e in tl["hold"]["effects"]:
		var type := str(e.get("type", ""))
		if Ref.HOLD.has(type) and not holds.has(type):
			holds.append(type)
			out.append("- hold `%s` (ht = hold time): %s" % [type, Ref.HOLD[type]])
	var common: Dictionary = tl["enter"].get("params", {})
	if bool(common.get("cursor", false)):
		out.append("- Typing cursor: a caret follows the last shown glyph during the enter, blinks every %s s after it and hides on exit (color %s)." % [_n(common.get("cursor_blink", 0.6)), common.get("cursor_color") if common.get("cursor_color") != null else "text fill"])
	out.append("\nOrder pauses (params): punct_pause after short punctuation, punct_long_pause after long punctuation, line_pause at line breaks (seconds, added to later glyphs' delays).\n")
	out.append("## 8. Easing\n\n" + Ref.EASING + "\n")


static func _n(v) -> String:
	var f := snappedf(float(v), 0.001)
	return str(int(f)) if f == floorf(f) and absf(f) < 1e9 else str(f)


static func _v(a) -> String:
	return "(%s, %s)" % [_n(a[0]), _n(a[1])]


static func _q(s) -> String:
	return JSON.stringify(str(s))
