extends Control
## Game-owned preparation returns an empty String on success, or an error to display.
signal exit_confirmed(target: StringName)
signal canceled
@export var ui_scale := 1.0
var busy := false
var _target: StringName
var _prepare := Callable()
var _can_save := false
var _previous_focus: Control
var _navigation := preload("res://addons/game_base/ui/menu_focus_navigation.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Panel.custom_minimum_size.x = 480 * ui_scale
	for side in ["left", "top", "right", "bottom"]:
		%Padding.add_theme_constant_override("margin_" + side, roundi(16 * ui_scale))
	for button in [%SaveExit, %DiscardExit, %Cancel]:
		button.custom_minimum_size.y = 48 * ui_scale
		button.add_theme_font_size_override("font_size", roundi(20 * ui_scale))
	for label in [%Heading, %Message]:
		label.add_theme_font_size_override("font_size", roundi(20 * ui_scale))
	%SaveExit.pressed.connect(_confirm.bind(true))
	%DiscardExit.pressed.connect(_confirm.bind(false))
	%Cancel.pressed.connect(cancel)
	get_viewport().gui_focus_changed.connect(_keep_focus)

func open_for(target: StringName, can_save: bool, prepare := Callable()) -> void:
	if visible or busy: return
	_target = target
	_prepare = prepare
	_can_save = can_save and prepare.is_valid()
	_previous_focus = get_viewport().gui_get_focus_owner()
	%Heading.text = tr("Return to title?") if target == &"title" else tr("Quit to desktop?")
	%Message.text = tr("Save before leaving? Previously saved progress will be kept.") if _can_save else tr("Are you sure you want to leave?")
	%SaveExit.text = tr("Save and exit") if _can_save else tr("Yes")
	%DiscardExit.visible = _can_save
	_set_busy(false)
	show()
	_navigation.reset()
	var buttons := _buttons()
	for i in buttons.size():
		buttons[i].focus_next = buttons[i].get_path_to(buttons[posmod(i + 1, buttons.size())])
		buttons[i].focus_previous = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
	%Cancel.grab_focus()

func cancel() -> void:
	if not visible or busy: return
	_dismiss()
	canceled.emit()

func _confirm(save: bool) -> void:
	if not visible or busy: return
	_set_busy(true)
	var message := ""
	if _prepare.is_valid(): message = await _prepare.call(save and _can_save)
	if not message.is_empty():
		_set_busy(false)
		%Message.text = message
		%Cancel.grab_focus()
		return
	_dismiss()
	exit_confirmed.emit(_target)

func _set_busy(value: bool) -> void:
	busy = value
	_navigation.reset()
	for button in [%SaveExit, %DiscardExit, %Cancel]: button.disabled = value
	if value: %Message.text = tr("Preparing to leave...")

func _dismiss() -> void:
	hide()
	_set_busy(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree(): _previous_focus.grab_focus()

func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button in [%SaveExit, %DiscardExit, %Cancel]:
		if button.visible and not button.disabled: buttons.append(button)
	return buttons

func _keep_focus(control: Control) -> void:
	if visible and not busy and (control == null or not is_ancestor_of(control)): %Cancel.grab_focus()

func _process(delta: float) -> void:
	if visible and not busy: _navigation.process(delta, _buttons(), get_viewport())

func _input(event: InputEvent) -> void:
	if not visible: return
	if busy:
		get_viewport().set_input_as_handled()
	elif _navigation.cancel_pressed(event):
		cancel()
		get_viewport().set_input_as_handled()
	elif _navigation.forward_pad_accept(event, get_viewport()): return
	elif _navigation.handle_input(event, _buttons(), get_viewport()) or preload("res://addons/game_base/ui/menu_focus_navigation.gd").category_step(event) != 0:
		get_viewport().set_input_as_handled()
