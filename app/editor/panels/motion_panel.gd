extends "res://app/editor/panels/panel_base.gd"
## 연출 탭: 등장/유지/퇴장. 유지 효과는 목록(추가는 미리보기 카드 팝업, 삭제·이동은 목록 명령).

const Hold := preload("res://addons/text_fx/core/fx_effects_hold.gd")
const ItemScene := preload("res://app/editor/panels/list_item.tscn")
const LIST := "timeline.hold.effects"


func structural_paths() -> Array:
	return ["timeline.enter.effect", "timeline.exit.effect", LIST, "timeline.scroll", "mode", "timeline.enter", "timeline.exit", "timeline.sub_enter", "timeline.sub_enter.effect"]


func _setup() -> void:
	%Enter.setup(ctx, self, "enter")
	%Exit.setup(ctx, self, "exit")
	%SubEnter.setup(ctx, self, "sub_enter")
	%SubIndependent.toggled.connect(func(on: bool):
		ctx.send({"op": "set", "path": "timeline.sub_enter", "value": preload("res://addons/text_fx/core/fx_doc.gd").default_sub_enter() if on else null}))
	(%AddHold as Button).pressed.connect(open_hold_picker)


func _build() -> void:
	%Enter.build()
	%Exit.build()
	var has_sub: bool = ctx.model.get_value("timeline.sub_enter") is Dictionary
	%SubIndependent.set_pressed_no_signal(has_sub)
	%SubEnter.visible = has_sub
	if has_sub:
		%SubEnter.build()
	var hf := %HoldFields as VBoxContainer
	clear_box(hf)
	add_field(hf, "timeline.hold.duration", {"max": 10.0})
	for path in ["timeline.hold.scope", "timeline.lead_in", "timeline.lead_out", "timeline.split_pages", "timeline.exit_between_pages"]:
		add_field(hf, path)
	if str(ctx.model.get_value("mode")) == "trailer":
		add_field(hf, "timeline.page_gap", {"max": 3.0})
	var scroll = ctx.model.get_value("timeline.scroll")
	var sc := %Scroll as Button
	sc.set_pressed_no_signal(scroll is Dictionary)
	if not sc.toggled.is_connected(_on_scroll):
		sc.toggled.connect(_on_scroll)
	if scroll is Dictionary:
		add_field(hf, "timeline.scroll.speed", {"max": 600.0, "step": 1.0})
		add_field(hf, "timeline.scroll.edge_fade")
	var list := %Effects as VBoxContainer
	clear_box(list)
	var effects: Array = ctx.model.get_value(LIST)
	for i in effects.size():
		var e: Dictionary = effects[i]
		var item: Node = ItemScene.instantiate()
		list.add_child(item)
		item.name = "Hold_%d" % i
		item.setup(ctx, LIST, i, effects.size(), Labels.hold_effect(str(e.type)))
		for key in e:
			if key != "type":
				add_field(item.fields_box(), "%s.%d.%s" % [LIST, i, key])
	(%EmptyHold as Label).visible = effects.is_empty()
	(%AddHold as Button).disabled = effects.size() >= 8


func _refresh() -> void:
	%Enter.refresh()
	%Exit.refresh()
	if ctx.model.get_value("timeline.sub_enter") is Dictionary:
		%SubEnter.refresh()


func open_hold_picker() -> void:
	var items: Array = []
	for id in Hold.TYPES:
		items.append({"id": id, "label": Labels.hold_effect(id), "preview": ["hold", id, ctx.preview_sample()]})
	ctx.open_picker("Add hold effect", items, "", add_hold, true)


func add_hold(id: String) -> void:
	ctx.send({"op": "list_add", "path": LIST, "value": id})


func _on_scroll(on: bool) -> void:
	ctx.send({"op": "set", "path": "timeline.scroll", "value": {"speed": 60.0} if on else null})
