extends Button
## 팝업·격자의 카드 하나: 미리보기(효과/이징) 또는 아이콘 또는 글꼴 견본 + 이름.
## 마우스를 올리거나 포커스가 오면 미리보기가 움직인다.

var id := ""


func _ready() -> void:
	mouse_entered.connect(_set_active.bind(true))
	mouse_exited.connect(_set_active.bind(false))
	focus_entered.connect(_set_active.bind(true))
	focus_exited.connect(_set_active.bind(false))


func set_label(text: String, translate := true) -> void:
	var l := %Name as Label
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	tooltip_text = text if not translate else ""


func set_preview(kind: String, value: String, sample: String) -> void:
	(%Preview as Control).visible = true
	%Preview.configure(kind, value, sample)


func set_icon(tex: Texture2D) -> void:
	(%Icon as TextureRect).visible = tex != null
	(%Icon as TextureRect).texture = tex


func set_sample(font: Font, text: String) -> void:
	var l := %Sample as Label
	l.visible = true
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)


func _set_active(on: bool) -> void:
	if (%Preview as Control).visible:
		%Preview.active = on or has_focus() or is_hovered()
