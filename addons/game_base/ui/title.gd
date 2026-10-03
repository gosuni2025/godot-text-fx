extends Control
signal start_requested
signal options_requested
var _navigation := preload("res://addons/game_base/ui/menu_focus_navigation.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config = preload("res://addons/game_base/project_config.gd").current()
	config.apply_title($SafeArea/Rows, $Background)
	if config.theme != null: theme = config.theme
	preload("res://addons/game_base/ui/menu_layout.gd").apply($SafeArea/Rows/Actions,
		[%Start, %Options, %Quit], config.menu_size_multiplier)
	%Build.text = preload("res://addons/game_base/build_info.gd").display_text()
	%Build.visible = config.show_build
	%Start.pressed.connect(func(): start_requested.emit())
	%Options.pressed.connect(func(): options_requested.emit())
	configure_quit_button(%Quit)
	get_viewport().size_changed.connect(_layout)
	_layout()
	focus_default.call_deferred()

func focus_default() -> void:
	_navigation.reset()
	var buttons := _focus_buttons()
	if not buttons.is_empty(): buttons[0].grab_focus()

func _layout() -> void:
	preload("res://addons/game_base/safe_area.gd").apply(self, $SafeArea)
	preload("res://addons/game_base/ui/menu_layout.gd").fit_touch_targets(self, [%Start, %Options, %Quit])

func _focus_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button in [%Start, %Options, %Quit]:
		if button.is_visible_in_tree() and not button.disabled: buttons.append(button)
	return buttons

func _owns_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return is_visible_in_tree() and (focus == null or is_ancestor_of(focus))

func _process(delta: float) -> void:
	if _owns_focus(): _navigation.process(delta, _focus_buttons(), get_viewport())
	else: _navigation.reset()

func _input(event: InputEvent) -> void:
	if _owns_focus() and _navigation.forward_pad_accept(event, get_viewport()): return
	if _owns_focus() and _navigation.handle_input(event, _focus_buttons(), get_viewport()):
		get_viewport().set_input_as_handled()

static func configure_quit_button(button: Button) -> void:
	button.visible = OS.has_feature("pc") and not OS.has_feature("web")
	button.pressed.connect(button.get_tree().quit)
