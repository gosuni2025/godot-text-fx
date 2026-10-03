extends PopupPanel
## 글꼴 고르기 팝업: 번들 글꼴 카드, 시스템 글꼴 목록(검색), 파일에서 불러오기.
## 고르면 ctx.send({op:"set", path:<font|sub_font>, value:spec})를 보낸다. 굵기·기울임은 현재 값을 유지한다.
## 연속으로 고르면 같은 경로의 set이라 실행 취소 기록은 하나로 합쳐진다.

const FxFont := preload("res://addons/text_fx/core/fx_font.gd")
const CardScene := preload("res://app/editor/popups/picker_card.tscn")
const SAMPLE := "가나 あア 字 Aa 123"
const CARD_SAMPLE := "가 あ Aa"

var ctx
var target := "font"
var card_size := Vector2(170, 100)
var _system: PackedStringArray = PackedStringArray()
var _shown: PackedStringArray = PackedStringArray()
var _cards: Dictionary = {}


var _return_focus: Control = null


func _ready() -> void:
	(%Close as Button).pressed.connect(hide)
	popup_hide.connect(_restore_focus)
	(%Search as LineEdit).text_changed.connect(_filter)
	(%List as ItemList).item_selected.connect(_on_system_selected)
	(%FromFile as Button).pressed.connect(_on_file)


func open_for(p_ctx, p_target: String, rect: Rect2i) -> void:
	ctx = p_ctx
	target = p_target
	var cur = _current()
	_build_bundled(cur)
	if _system.is_empty():
		_system = OS.get_system_fonts()
		_system.sort()
	(%Search as LineEdit).text = ""
	_filter("")
	_select_system(cur)
	_update_preview(cur)
	_return_focus = get_tree().root.gui_get_focus_owner()
	popup(rect)
	var first: Button = _cards.get(str(cur.get("family", "")), null)
	if first == null and _cards.size() > 0:
		first = _cards.values()[0]
	if first:
		_focus_later.call_deferred(first)


func _current() -> Dictionary:
	var v = ctx.model.get_value(target)
	if not (v is Dictionary):
		v = ctx.model.get_value("font")
	return v if v is Dictionary else {}


func _build_bundled(cur: Dictionary) -> void:
	var box := %Bundled as HFlowContainer
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	_cards.clear()
	for fam: String in FxFont.BUNDLED:
		var card: Button = CardScene.instantiate()
		card.custom_minimum_size = card_size
		card.size_flags_horizontal = Control.SIZE_FILL
		box.add_child(card)
		card.id = fam
		card.name = "Font_" + fam
		card.set_label(fam, false)
		card.set_sample(FxFont.resolve({"source": "bundled", "family": fam, "path": FxFont.BUNDLED[fam], "weight": 400}), CARD_SAMPLE)
		card.set_pressed_no_signal(cur.get("source") == "bundled" and cur.get("family") == fam)
		card.pressed.connect(choose_bundled.bind(fam))
		_cards[fam] = card


func _filter(q: String) -> void:
	var list := %List as ItemList
	list.clear()
	_shown.clear()
	var needle := q.strip_edges().to_lower()
	for f in _system:
		if needle == "" or f.to_lower().contains(needle):
			_shown.append(f)
			list.add_item(f)
	(%Count as Label).text = tr("%d system fonts") % _shown.size()


func _select_system(cur: Dictionary) -> void:
	if cur.get("source") != "system":
		return
	var i := _shown.find(str(cur.get("family", "")))
	if i >= 0:
		(%List as ItemList).select(i)
		(%List as ItemList).ensure_current_is_visible()


func _on_system_selected(i: int) -> void:
	if i >= 0 and i < _shown.size():
		choose_system(_shown[i])


func choose_bundled(family: String) -> void:
	_choose({"source": "bundled", "family": family, "path": FxFont.BUNDLED.get(family, "")})


func choose_system(family: String) -> void:
	_choose({"source": "system", "family": family, "path": ""})


func _choose(spec: Dictionary) -> void:
	var cur := _current()
	spec["weight"] = float(cur.get("weight", 700.0))
	spec["italic"] = bool(cur.get("italic", false))
	ctx.send({"op": "set", "path": target, "value": spec})
	for k in _cards:
		(_cards[k] as Button).set_pressed_no_signal(spec.source == "bundled" and k == spec.family)
	_update_preview(spec)


func _update_preview(spec: Dictionary) -> void:
	var l := %Preview as Label
	l.add_theme_font_override("font", FxFont.resolve(spec))
	l.text = SAMPLE
	(%Current as Label).text = "%s (%s)" % [str(spec.get("family", "")), tr(_source_key(str(spec.get("source", ""))))]


static func _source_key(source: String) -> String:
	match source:
		"system": return "System font"
		"path": return "Font file"
	return "Bundled font"


func _on_file() -> void:
	hide()
	ctx.request_font_file(target)


func _focus_later(c: Control) -> void:
	if is_instance_valid(c) and c.is_visible_in_tree():
		c.grab_focus()


## 팝업을 닫으면 연 버튼으로 포커스를 돌려준다(키보드·패드 조작 유지).
func _restore_focus() -> void:
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
