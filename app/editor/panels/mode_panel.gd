extends "res://app/editor/panels/panel_base.gd"
## 모드·템플릿 탭: 모드 토글(set_mode), 분류 칩(화면 전용 필터), 템플릿 카드(apply_template).

const Templates := preload("res://app/logic/templates.gd")
const ChipScene := preload("res://app/editor/fields/chip_button.tscn")
const CardScene := preload("res://app/editor/popups/picker_card.tscn")
const MODES := ["message", "trailer", "caption"]

var group_filter := ""
var _cards: Dictionary = {}


func structural_paths() -> Array:
	return ["mode"]


func _setup() -> void:
	for m in MODES:
		var b := get_node("%Mode_" + m) as Button
		b.pressed.connect(_on_mode.bind(m))
	(%Grid as GridContainer).resized.connect(_fit_columns)


func on_state_changed(paths: PackedStringArray) -> void:
	if "$locale" in paths:
		mark_rebuild()
	elif "$history" in paths and is_visible_in_tree():
		_refresh()


func _build() -> void:
	var mode := str(ctx.model.get_value("mode"))
	var groups := Templates.groups(mode)
	if group_filter != "" and not group_filter in groups:
		group_filter = ""
	var chips := %Groups as HFlowContainer
	clear_box(chips)
	var all: Button = ChipScene.instantiate()
	all.text = "All"
	all.name = "Group_all"
	all.pressed.connect(_on_group.bind(""))
	chips.add_child(all)
	for g in groups:
		var b: Button = ChipScene.instantiate()
		b.text = Labels.group(g)
		b.name = "Group_" + g
		b.icon = ctx.ui_icon(Labels.GROUP_ICONS.get(g, "mode_" + mode))
		b.pressed.connect(_on_group.bind(g))
		chips.add_child(b)
	var grid := %Grid as GridContainer
	clear_box(grid)
	_cards.clear()
	for tpl: Dictionary in Templates.by_mode(mode, group_filter):
		var card: Button = CardScene.instantiate()
		card.custom_minimum_size = ctx.scaled(Vector2(132, 124))
		grid.add_child(card)
		card.id = tpl.id
		card.name = "Tpl_" + tpl.id
		card.set_label(Templates.localized(tpl, "name", ctx.model.locale), false)
		card.set_icon(ctx.template_icon(str(tpl.get("icon", "")), Labels.GROUP_ICONS.get(tpl.group, "mode_" + mode)))
		card.tooltip_text = Templates.localized(tpl, "text", ctx.model.locale).replace("\n\n", " / ")
		card.pressed.connect(apply_template.bind(tpl.id))
		_cards[tpl.id] = card
	_fit_columns()


func _refresh() -> void:
	var mode := str(ctx.model.get_value("mode"))
	for m in MODES:
		(get_node("%Mode_" + m) as Button).set_pressed_no_signal(m == mode)
	for c in (%Groups as HFlowContainer).get_children():
		(c as Button).set_pressed_no_signal(c.name == "Group_" + (group_filter if group_filter != "" else "all"))
	for id in _cards:
		(_cards[id] as Button).set_pressed_no_signal(id == ctx.model.template_id)


func _fit_columns() -> void:
	var grid := %Grid as GridContainer
	var w := grid.size.x if grid.size.x > 0.0 else size.x
	var card_w: float = ctx.scaled(Vector2(132, 0)).x + grid.get_theme_constant("h_separation")
	grid.columns = maxi(2, int(w / card_w))


func apply_template(id: String) -> void:
	ctx.send({"op": "apply_template", "id": id, "keep_text": (%KeepText as Button).button_pressed})
	_refresh()


func card(id: String) -> Button:
	return _cards.get(id)


func _on_mode(m: String) -> void:
	ctx.send({"op": "set_mode", "mode": m})
	_refresh()


func _on_group(g: String) -> void:
	group_filter = g
	rebuild()
