extends PanelContainer
## 연출 탭의 등장/퇴장 묶음: 효과·이징 카드(팝업 선택), 순서 버튼 묶음, 길이·간격, 효과 params.

const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const Labels := preload("res://app/editor/ui_labels.gd")

var ctx
var panel
var seg := "enter"


func setup(p_ctx, p_panel, p_seg: String) -> void:
	ctx = p_ctx
	panel = p_panel
	seg = p_seg
	(%Title as Label).text = "Enter" if seg == "enter" else "Exit"
	(%Enabled as Control).visible = seg == "exit"
	(%EffectCard as Button).pressed.connect(open_effect_picker)
	(%EasingCard as Button).pressed.connect(open_easing_picker)
	(%Enabled as Button).toggled.connect(func(on: bool):
		ctx.send({"op": "set", "path": "timeline.exit.enabled", "value": on}))
	for c: Button in [%EffectCard, %EasingCard]:
		c.toggle_mode = false
		c.custom_minimum_size = ctx.scaled(Vector2(150, 112))


func base() -> String:
	return "timeline." + seg


func build() -> void:
	var box := %Fields as VBoxContainer
	panel.clear_box(box)
	panel.add_field(box, base() + ".order")
	panel.add_field(box, base() + ".duration", {"max": 3.0})
	panel.add_field(box, base() + ".stagger", {"max": 1.0})
	var params := %Params as VBoxContainer
	panel.clear_box(params)
	var effect := str(ctx.model.get_value(base() + ".effect"))
	for key in Enter.default_params(effect):
		panel.add_field(params, base() + ".params." + key)
	refresh()


func refresh() -> void:
	var effect := str(ctx.model.get_value(base() + ".effect"))
	var easing := str(ctx.model.get_value(base() + ".easing"))
	var ec := %EffectCard as Button
	ec.set_label(Labels.enter_effect(effect))
	ec.set_preview(seg, effect, ctx.preview_sample())
	ec.tooltip_text = "Effect: click to choose"
	var gc := %EasingCard as Button
	gc.set_label(Labels.easing_text(easing), false)
	gc.set_preview("easing", easing, "")
	gc.tooltip_text = "Easing: click to choose"
	var enabled: bool = seg == "enter" or ctx.model.get_value("timeline.exit.enabled") == true
	(%Enabled as Button).set_pressed_no_signal(enabled)
	(%Body as Control).modulate.a = 1.0 if enabled else 0.55


func open_effect_picker() -> void:
	var items: Array = []
	for id in Enter.IDS:
		items.append({"id": id, "label": Labels.enter_effect(id), "preview": [seg, id, ctx.preview_sample()]})
	var title := "Enter effect" if seg == "enter" else "Exit effect"
	ctx.open_picker(title, items, str(ctx.model.get_value(base() + ".effect")), _set_value.bind(".effect"))


func open_easing_picker() -> void:
	var items: Array = []
	for id in Easing.NAMES:
		items.append({"id": id, "label": Labels.easing_text(id), "translate": false, "preview": ["easing", id, ""]})
	ctx.open_picker("Easing", items, str(ctx.model.get_value(base() + ".easing")), _set_value.bind(".easing"))


func _set_value(id: String, suffix: String) -> void:
	ctx.send({"op": "set", "path": base() + suffix, "value": id})
