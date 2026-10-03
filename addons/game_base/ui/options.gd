extends Control
signal closed
signal title_requested
signal quit_requested
signal report_requested
var settings: RefCounted
const Navigation = preload("res://addons/game_base/ui/menu_focus_navigation.gd")
var _categories: Array[String] = []
var _in_game := false
var _prepare_exit := Callable()
@onready var rows: VBoxContainer = %Rows

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Categories.tab_changed.connect(_select_category)
	%Back.pressed.connect(func(): hide(); closed.emit())
	%ReturnTitle.pressed.connect(_request_exit.bind(&"title"))
	%QuitDesktop.pressed.connect(_request_exit.bind(&"desktop"))
	$ExitConfirmation.exit_confirmed.connect(_finish_exit)
	%Report.pressed.connect(func(): report_requested.emit())
	%Reset.pressed.connect(_reset)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	preload("res://addons/game_base/safe_area.gd").apply(self, $SafeArea)

func open_menu(store: RefCounted, in_game: bool, profiling: bool, prepare_exit := Callable()) -> void:
	settings = store
	_in_game = in_game
	_prepare_exit = prepare_exit
	%ReturnTitle.disabled = not in_game
	%QuitDesktop.visible = OS.has_feature("pc") and not OS.has_feature("web")
	%Report.visible = profiling
	%Status.text = "Changes save automatically."
	_rebuild()
	show()
	_select_category(maxi(0, %Categories.current_tab))

func _rebuild() -> void:
	_categories.clear()
	%Categories.set_block_signals(true)
	%Categories.clear_tabs()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry in settings.definitions:
		if not entry.enabled: continue
		if not entry.category in _categories:
			_categories.append(entry.category)
			%Categories.add_tab(tr(entry.category))
		var row = preload("res://addons/game_base/ui/option_row.tscn").instantiate()
		rows.add_child(row)
		row.bind(entry, settings.values[entry.id])
		row.edited.connect(_edit)
		if row.focus_control() is OptionButton:
			var popup: PopupMenu = row.focus_control().get_popup()
			popup.window_input.connect(_popup_input.bind(popup))
	if not "System" in _categories:
		_categories.append("System")
		%Categories.add_tab(tr("System"))
	%Categories.visible = _categories.size() > 1
	%Categories.set_block_signals(false)
	_select_category(0)

func _edit(id: StringName, value: Variant) -> void:
	%Status.text = "Saved." if settings.set_value(id, value) == OK else "Applied, but settings could not be saved."

func _reset() -> void:
	%Status.text = "Saved." if settings.reset_defaults() == OK else "Applied, but settings could not be saved."
	_rebuild()
	%Reset.grab_focus()

func _input(event: InputEvent) -> void:
	if $ExitConfirmation.visible: return
	if is_visible_in_tree() and _category_input(event):
		get_viewport().set_input_as_handled()
		return
	if is_visible_in_tree() and Navigation.forward_pad_accept(event, get_viewport()): return
	if visible and Navigation.cancel_pressed(event):
		hide()
		closed.emit()
		get_viewport().set_input_as_handled()

func _select_category(index: int) -> void:
	var first: Control
	for row in rows.get_children():
		var control: Control = row.focus_control()
		if control is OptionButton: control.get_popup().hide()
		row.visible = index >= 0 and index < _categories.size() and row.definition.category == _categories[index]
		if row.visible and first == null: first = control
	var system := index >= 0 and index < _categories.size() and _categories[index] == "System"
	%SystemPage.visible = system
	%Reset.visible = not system
	if system and first == null:
		if not %ReturnTitle.disabled: first = %ReturnTitle
		elif %QuitDesktop.visible: first = %QuitDesktop
	%Scroll.scroll_vertical = 0
	if is_visible_in_tree():
		if first != null: first.grab_focus()
		else: %Back.grab_focus()

func _category_input(event: InputEvent) -> bool:
	if $ExitConfirmation.visible: return false
	var step := Navigation.category_step(event)
	if step == 0 or _categories.is_empty(): return false
	%Categories.current_tab = posmod(%Categories.current_tab + step, _categories.size())
	# A single category does not emit tab_changed, but still dismisses its popup.
	if _categories.size() == 1: _select_category(0)
	return true

func _popup_input(event: InputEvent, popup: PopupMenu) -> void:
	if is_visible_in_tree() and _category_input(event): popup.set_input_as_handled()

func _request_exit(target: StringName) -> void:
	$ExitConfirmation.open_for(target, _in_game, _prepare_exit)

func _finish_exit(target: StringName) -> void:
	if target == &"title": title_requested.emit()
	elif quit_requested.get_connections().is_empty(): get_tree().quit()
	else: quit_requested.emit()
