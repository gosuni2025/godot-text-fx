extends PopupPanel
## 선택지가 많은 항목(효과·이징·유지 효과·장식 종류)의 카드 팝업.
## 카드를 누르면 콜백으로 id를 넘긴다. 콜백이 명령을 보내고, 팝업은 열린 채로 선택 표시만 바꾼다
## (close_on_pick이면 닫는다). Esc·바깥 클릭·닫기 버튼으로 닫는다.

const CardScene := preload("res://app/editor/popups/picker_card.tscn")

var _callback: Callable
var _cards: Dictionary = {}
var _close_on_pick := false
var card_size := Vector2(150, 112)


func _ready() -> void:
	(%Close as Button).pressed.connect(hide)
	(%Grid as HFlowContainer).resized.connect(_fit_cards)


## items: [{ id, label, translate?(기본 true), preview?: [kind, value, sample], icon?: Texture2D }]
func open_items(title: String, items: Array, current: String, callback: Callable, rect: Rect2i,
		close_on_pick := false) -> void:
	_callback = callback
	_close_on_pick = close_on_pick
	(%Title as Label).text = title
	var grid := %Grid as HFlowContainer
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	for it: Dictionary in items:
		var card: Button = CardScene.instantiate()
		card.custom_minimum_size = card_size
		card.size_flags_horizontal = Control.SIZE_FILL
		grid.add_child(card)
		card.id = str(it.id)
		card.name = "Card_" + card.id
		card.set_label(str(it.get("label", it.id)), it.get("translate", true))
		if it.has("preview"):
			var pv: Array = it.preview
			card.set_preview(pv[0], pv[1], pv[2])
		if it.get("icon") != null:
			card.set_icon(it.icon)
		card.pressed.connect(_on_card.bind(card.id))
		_cards[card.id] = card
	_mark(current)
	popup(rect)
	var focus: Button = _cards.get(current, grid.get_child(0) if grid.get_child_count() > 0 else null)
	if focus:
		_focus_later.call_deferred(focus)


## 남는 폭이 없도록 카드 폭을 열 수에 맞춰 늘린다.
func _fit_cards() -> void:
	var grid := %Grid as HFlowContainer
	var w := grid.size.x
	var sep := float(grid.get_theme_constant("h_separation"))
	if w <= 0.0 or card_size.x <= 0.0:
		return
	var cols := maxi(1, int((w + sep) / (card_size.x + sep)))
	var cw := floorf((w - sep * (cols - 1)) / cols) - 1.0
	for c in grid.get_children():
		(c as Control).custom_minimum_size = Vector2(cw, card_size.y)


func card(id: String) -> Button:
	return _cards.get(id)


func pick(id: String) -> void:
	_on_card(id)


func _mark(current: String) -> void:
	for k in _cards:
		(_cards[k] as Button).set_pressed_no_signal(k == current)


func _on_card(id: String) -> void:
	_mark(id)
	if _callback.is_valid():
		_callback.call(id)
	if _close_on_pick:
		hide()


func _focus_later(c: Control) -> void:
	if is_instance_valid(c) and c.is_visible_in_tree():
		c.grab_focus()
