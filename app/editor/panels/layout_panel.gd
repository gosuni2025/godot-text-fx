extends "res://app/editor/panels/panel_base.gd"
## 배치 탭: 캔버스 크기(프리셋/직접), 방향·정렬·기준점, 크기·간격, 줄바꿈, 보조 문구 위치, 시드.

const PRESETS := {"1280x720": [1280, 720], "1920x1080": [1920, 1080], "1080x1080": [1080, 1080]}

var _custom := false


func structural_paths() -> Array:
	return ["canvas"]


func _setup() -> void:
	for key in PRESETS:
		(get_node("%Preset_" + key) as Button).pressed.connect(set_canvas_preset.bind(key))
	(%Preset_custom as Button).pressed.connect(func():
		_custom = true
		rebuild())


func _build() -> void:
	var box := %Sections as VBoxContainer
	clear_box(box)
	var cf := %CanvasFields as VBoxContainer
	clear_box(cf)
	if _custom or _preset_key() == "":
		add_field(cf, "canvas.width", {"max": 4096.0})
		add_field(cf, "canvas.height", {"max": 4096.0})
	var pos := add_section(box, "Direction and position")
	for p in ["layout.direction", "layout.align", "layout.valign"]:
		add_field(pos.fields_box(), p)
	add_field(pos.fields_box(), "layout.anchor", {"step": 0.01})
	add_field(pos.fields_box(), "layout.offset", {"step": 1.0})
	var size_s := add_section(box, "Size and spacing")
	add_field(size_s.fields_box(), "layout.font_size", {"max": 300.0})
	for p in ["layout.letter_spacing", "layout.line_height", "layout.max_width", "layout.max_height"]:
		add_field(size_s.fields_box(), p)
	var wrap := add_section(box, "Line breaks")
	add_field(wrap.fields_box(), "layout.wrap")
	add_field(wrap.fields_box(), "layout.kinsoku")
	add_field(wrap.fields_box(), "layout.auto_shrink")
	add_field(wrap.fields_box(), "layout.min_font_size", {"max": 200.0})
	var sub := add_section(box, "Sub text")
	add_field(sub.fields_box(), "layout.sub.position")
	add_field(sub.fields_box(), "layout.sub.font_size", {"max": 200.0})
	add_field(sub.fields_box(), "layout.sub.gap")
	add_field(sub.fields_box(), "layout.sub.letter_spacing")
	var bg := add_section(box, "Output background")
	for key in ["type", "color", "opacity", "extent", "sync_fade"]:
		add_field(bg.fields_box(), "background." + key)
	var adv := add_section(box, "Random seed")
	add_field(adv.fields_box(), "seed", {"max": 99999.0})
	var reroll: Button = preload("res://app/editor/fields/action_button.tscn").instantiate()
	reroll.name = "Reroll"
	reroll.text = "New seed"
	reroll.icon = ctx.ui_icon("randomize")
	reroll.pressed.connect(next_seed)
	adv.fields_box().add_child(reroll)


func _refresh() -> void:
	var key := _preset_key()
	for k in PRESETS:
		(get_node("%Preset_" + k) as Button).set_pressed_no_signal(k == key and not _custom)
	(%Preset_custom as Button).set_pressed_no_signal(_custom or key == "")


func _preset_key() -> String:
	var w := int(ctx.model.get_value("canvas.width"))
	var h := int(ctx.model.get_value("canvas.height"))
	for k in PRESETS:
		if PRESETS[k][0] == w and PRESETS[k][1] == h:
			return k
	return ""


func set_canvas_preset(key: String) -> void:
	_custom = false
	var wh: Array = PRESETS[key]
	ctx.send({"op": "set", "path": "canvas", "value": {"width": float(wh[0]), "height": float(wh[1])}})
	rebuild()


## 다음 시드: 현재 시드에서 정해지는 값(전역 난수 미사용).
func next_seed() -> void:
	var s := int(ctx.model.get_value("seed"))
	ctx.send({"op": "set", "path": "seed", "value": float((s * 1103515245 + 12345) % 99991)})
