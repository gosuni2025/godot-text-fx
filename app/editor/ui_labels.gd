extends RefCounted
## 편집기 UI 표시 이름. 값은 app/i18n/ui.csv 의 번역 키(영문 문구)이며 tr()로 번역해 쓴다.
## 문서 값(효과 id 등)은 바꾸지 않고 표시 이름만 고른다.

const ENTER_EFFECTS := {
	"flip": "Flip",
	"flicker": "Flicker",
	"slam": "Block slam",
	"block_zoom": "Block zoom",
	"emerge": "Block emerge",
	"shutter": "Shutter",
	"flash": "Flash",
	"erase": "Erase",
	"block_wipe": "Block wipe",
	"block_glitch": "Block glitch",
	"bounce": "Bounce",
	"same": "Match the main entrance",
	"fade": "Fade", "slide": "Slide", "zoom": "Zoom", "pop": "Pop", "drop": "Drop", "rise": "Rise",
	"blur": "Blur", "spin": "Spin", "converge": "Converge", "tracking": "Tracking", "center_split": "Center split",
	"scatter": "Scatter", "wipe": "Wipe", "typewriter": "Typewriter", "glitch": "Glitch", "center_stamp": "Center stamp",
}
const HOLD_EFFECTS := {
	"heartbeat": "Heartbeat",
	"glow_pulse": "Glow pulse",
	"block_shake": "Block shake",
	"block_glitch": "Block glitch",
	"blink": "Blink", "flicker": "Flicker", "shake": "Shake", "wave": "Wave", "float": "Float",
	"pulse": "Pulse", "glitch": "Glitch", "color_cycle": "Color cycle",
}
const DECORATIONS := {
	"tape": "Striped tapes",
	"box": "Rounded box",
	"bar": "Accent bar",
	"lines": "Parallel lines",
	"underline": "Underline", "overline": "Overline", "band": "Band", "side_lines": "Flanking strokes",
	"frame": "Frame", "brackets": "Brackets",
}
const EASING_KINDS := {
	"linear": "Linear", "sine": "Sine", "quad": "Quad", "cubic": "Cubic", "quart": "Quart", "quint": "Quint",
	"expo": "Expo", "circ": "Circ", "back": "Back curve", "elastic": "Elastic", "bounce": "Bounce",
}
const EASING_MODES := {"in": "Ease in", "out": "Ease out", "in_out": "Ease in-out"}
const MODES := {"message": "Message", "trailer": "Trailer", "caption": "Place / time"}
const GROUPS := {
	"battle": "Battle", "explore": "Explore", "narrator": "Narrator", "scene_time": "Scene / time", "check": "Check",
	"converge": "Converge", "rise": "Rise", "tracking": "Tracking", "center_split": "Center split",
	"vertical": "Vertical", "slide": "Slide", "typewriter": "Typewriter", "line": "Reveal successive lines",
	"flow": "Flow", "all_at_once": "Reveal the full text", "scroll": "Scroll", "center_stamp": "Center stamp",
}
const GROUP_ICONS := {
	"battle": "group_battle", "explore": "group_explore", "narrator": "group_narrator",
	"scene_time": "group_scene_time", "check": "group_check",
}

## 선택지 표시 이름: 경로 패턴(번호는 *) → {값: 키}.
const ENUMS := {
	"params.axis": {"auto": "Auto", "horizontal": "Horizontal", "vertical": "Vertical"},
	"timeline.hold.scope": {"hold": "Hold phase only", "visible": "While text is visible"},
	"background.type": {"none": "None", "solid": "Solid", "vignette": "Vignette", "bottom": "Bottom gradient", "top": "Top gradient"},
	"layout.direction": {"horizontal": "Horizontal", "vertical": "Vertical"},
	"layout.align": {"left": "Left", "center": "Center", "right": "Right"},
	"layout.valign": {"top": "Top", "center": "Middle", "bottom": "Bottom"},
	"layout.wrap": {"none": "No wrap", "char": "By character", "word": "By word", "auto": "Auto"},
	"layout.sub.position": {"above": "Above", "below": "Below"},
	"fill.type": {"solid": "Solid", "gradient": "Gradient"},
	"fill.gradient.space": {"block": "Whole block", "glyph": "Each glyph", "line": "Each line"},
	"order": {"all": "Reveal the full text", "forward": "Forward", "reverse": "Reverse", "line": "By line",
		"word": "By word", "center_out": "Center out", "edges_in": "Edges in", "random": "Random", "center_index": "Center by character", "edges_index": "Edges by character", "sweep": "Spatial sweep"},
	"params.dir": {"up": "Up", "down": "Down", "left": "Left", "right": "Right", "center": "Center"},
	"params.mode": {"alternate": "Alternate", "role": "Main up / sub down"},
	"decorations.*.animate": {"none": "None", "fade": "Fade", "grow_center": "Expand toward both ends", "grow_start": "Grow from start", "shape": "Shape animation"},
	"decorations.*.type": DECORATIONS,
	"timeline.loop": {"once": "Once", "loop_all": "Loop all", "loop_hold": "Loop hold"},
}

## 필드 이름: 마지막 키(또는 더 긴 경로 끝) → 키. 긴 접미사를 먼저 찾는다.
const FIELDS := {
	"solo_animated": "Animate each central glyph",
	"viewport_scale": "Central glyph canvas ratio", "blink_strength": "Tape blink strength",
	"protect_sub": "Protect sub text spacing", "clamp_canvas": "Keep frame inside canvas",
	"follow_block": "Follow block motion",
	"lead_in": "Leading blank (s)",
	"lead_out": "Trailing blank (s)",
	"split_pages": "Use empty lines as page breaks",
	"exit_between_pages": "Exit between pages",
	"scope": "Hold effect timing",
	"edge_fade": "Scroll edge fade",
	"line_pause": "Line pause (s)",
	"punct_long_pause": "Sentence pause (s)",
	"line_stagger": "Line interval (s)",
	"sweep_duration": "Sweep time per line (s)",
	"overlap_hold": "Overlap hold (s)",
	"space_pause": "Space pause (s)",
	"cursor": "Typing cursor",
	"cursor_blink": "Cursor blink period (s)",
	"cursor_color": "Cursor color",
	"impact_duration": "Impact duration (s)",
	"impact_brightness": "Impact brightness",
	"impact_shake": "Impact shake",
	"impact": "Impact portion",
	"brightness": "Flash brightness",
	"shake": "Impact shake",
	"glow": "Glow boost",
	"min_strength": "Minimum glow strength",
	"axis": "Axis",
	"feather": "Soft wipe edge",
	"fill_color": "Decoration fill color",
	"fill_opacity": "Decoration fill opacity",
	"decorations.*.radius": "Corner radius",
	"softness": "Band edge softness",
	"end_fade": "Band end fade",
	"full_span": "Span entire canvas",
	"stripe_width": "Stripe width",
	"stripe_speed": "Stripe speed",
	"blink_period": "Tape alternating blink (s)",
	"arm_length": "Corner arm length",
	"lead_text": "Decoration before text",
	"exit_delay": "Decoration exit delay (s)",
	"exit_duration": "Decoration exit time (s)",
	"extent": "Background gradient extent",
	"sync_fade": "Fade with text",
	"layout.font_size": "Font size", "layout.sub.font_size": "Sub font size", "letter_spacing": "Letter spacing",
	"line_height": "Line height", "max_width": "Max width", "max_height": "Max height", "direction": "Direction",
	"align": "Align", "valign": "Vertical align", "anchor": "Anchor", "offset": "Offset", "wrap": "Wrap",
	"kinsoku": "Line-break rules (kinsoku)", "auto_shrink": "Auto shrink", "min_font_size": "Min font size",
	"sub.position": "Supporting text placement", "sub.gap": "Sub text gap", "width": "Width", "height": "Height",
	"weight": "Weight", "italic": "Italic", "fill.type": "Fill", "fill.color": "Color",
	"gradient.angle": "Gradient angle", "gradient.space": "Gradient range", "enabled": "Enabled",
	"size": "Size", "color": "Color", "shadow.offset": "Shadow offset", "blur": "Blur", "strength": "Strength",
	"opacity": "Opacity", "order": "Order", "duration": "Duration (s)", "stagger": "Stagger (s)",
	"hold.duration": "Hold time (s)", "page_gap": "Page gap (s)", "scroll.speed": "Scroll speed (px/s)",
	"type": "Type", "thickness": "Thickness", "margin": "Margin", "length": "Length", "use_outline": "Use outline",
	"animate": "Animation", "delay": "Delay (s)", "name": "Document name", "seed": "Seed",
	"dir": "Direction", "mode": "Mode", "distance": "Distance (em)", "from_scale": "Start scale",
	"radius": "Blur radius (em)", "angle": "Angle", "spread": "Spread", "jitter": "Jitter", "pop": "Pop",
	"intensity": "Intensity", "big_scale": "Big scale", "hold_each": "Time per glyph (s)", "pause": "Pause (s)",
	"slam_scale": "Slam scale", "punct_pause": "Punctuation pause (s)", "period": "Period (s)",
	"min_alpha": "Min opacity", "hard": "Hard blink", "rate": "Rate", "amplitude": "Amplitude",
	"frequency": "Frequency", "wavelength": "Wavelength (glyphs)", "speed": "Speed", "scale": "Scale",
	"interval": "Interval (s)", "slices": "Slices", "color_a": "Color A", "color_b": "Color B",
	"saturation": "Saturation",
}


static func enter_effect(id: String) -> String:
	return ENTER_EFFECTS.get(id, id)


static func hold_effect(id: String) -> String:
	return HOLD_EFFECTS.get(id, id)


static func decoration(id: String) -> String:
	return DECORATIONS.get(id, id)


static func mode(id: String) -> String:
	return MODES.get(id, id)


static func group(id: String) -> String:
	return GROUPS.get(id, id)


## 이징 이름 → [종류 키, 방식 키("" = 선형)].
static func easing_parts(id: String) -> Array:
	if id == "auto":
		return ["Effect default easing", ""]
	if id == "linear":
		return ["Linear", ""]
	var mode_id := "in_out" if id.ends_with("_in_out") else id.get_slice("_", id.get_slice_count("_") - 1)
	var kind := id.trim_suffix("_" + mode_id)
	return [EASING_KINDS.get(kind, kind), EASING_MODES.get(mode_id, mode_id)]


## 번역된 이징 표시 이름.
static func easing_text(id: String) -> String:
	var p := easing_parts(id)
	if p[1] == "":
		return TranslationServer.translate(p[0])
	return "%s · %s" % [TranslationServer.translate(p[0]), TranslationServer.translate(p[1])]


## 경로에 맞는 필드 이름 키. 가장 긴 접미사가 이긴다.
static func field(path: String) -> String:
	var matched := _pattern(path)
	if FIELDS.has(matched):
		return FIELDS[matched]
	var segs := path.split(".")
	for n in range(mini(3, segs.size()), 0, -1):
		var tail := ".".join(segs.slice(segs.size() - n))
		if FIELDS.has(tail):
			return FIELDS[tail]
	return path.get_slice(".", path.get_slice_count(".") - 1)


## 선택지 값의 표시 이름 키.
static func enum_value(path: String, value: String) -> String:
	var pattern := _pattern(path)
	for key in ENUMS:
		if pattern == key or pattern.ends_with("." + key):
			return ENUMS[key].get(value, value)
	return value


static func _pattern(path: String) -> String:
	var segs := path.split(".")
	for i in segs.size():
		if segs[i].is_valid_int():
			segs[i] = "*"
	return ".".join(segs)
