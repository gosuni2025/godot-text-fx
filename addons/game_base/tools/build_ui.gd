extends SceneTree
## Author editable native scenes once; no static UI is constructed at runtime.
const OUT := "res://addons/game_base/ui/"
var scene: Node
var ui_theme: Theme

func _initialize() -> void:
	ui_theme = Theme.new()
	ui_theme.default_font = load("res://addons/game_base/fonts/Galmuri11.ttf")
	ui_theme.default_font_size = 20
	ResourceSaver.save(ui_theme, OUT + "theme.tres")
	_wordmark()
	_row()
	_options()
	_title()
	_loading()
	_boot("game_boot", "res://addons/game_base/boot.gd")
	quit()

func add(node: Node, parent: Node, label: String, unique := false) -> Node:
	node.name = label
	parent.add_child(node)
	node.owner = scene
	node.unique_name_in_owner = unique
	return node

func fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func save_scene(filename: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, OUT + filename + ".tscn") == OK)
	scene.free()

func root_control(label: String, script: String) -> Control:
	scene = Control.new()
	scene.name = label
	fill(scene)
	scene.theme = ui_theme
	if not script.is_empty(): scene.set_script(load(script))
	return scene

func label(parent: Node, node_name: String, text: String, size := 20, unique := false) -> Label:
	var node: Label = add(Label.new(), parent, node_name, unique)
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(parent: Node, node_name: String, text: String) -> Button:
	var node: Button = add(Button.new(), parent, node_name, true)
	node.text = text
	node.custom_minimum_size = Vector2(180, 48)
	return node

func background(parent: Node) -> void:
	var color: ColorRect = add(ColorRect.new(), parent, "Backdrop")
	fill(color)
	color.color = Color("151b22")
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture: TextureRect = add(TextureRect.new(), parent, "Background")
	fill(texture)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _wordmark() -> void:
	root_control("Wordmark", OUT + "wordmark.gd")
	scene.custom_minimum_size = Vector2(0, 44)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.set("font_size", 28)
	var group: CanvasGroup = add(CanvasGroup.new(), scene, "Effect")
	group.fit_margin = 52
	group.clear_margin = 52
	group.material = load(OUT + "title_material.tres")
	var text := label(group, "Title", "MY GAME", 28)
	text.add_theme_font_override("font", ui_theme.default_font)
	text.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_scene("wordmark")

func _row() -> void:
	scene = HBoxContainer.new()
	scene.name = "OptionRow"
	scene.set_script(load(OUT + "option_row.gd"))
	scene.custom_minimum_size = Vector2(0, 52)
	var caption := label(scene, "Caption", "Option")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.custom_minimum_size.x = 240
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toggle: CheckButton = add(CheckButton.new(), scene, "Toggle")
	toggle.custom_minimum_size = Vector2(220, 48)
	var range_row: HBoxContainer = add(HBoxContainer.new(), scene, "Range")
	range_row.custom_minimum_size.x = 220
	var slider: HSlider = add(HSlider.new(), range_row, "Slider")
	slider.custom_minimum_size = Vector2(150, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(range_row, "Value", "1.0", 18).custom_minimum_size.x = 60
	var choice: OptionButton = add(OptionButton.new(), scene, "Choice")
	choice.custom_minimum_size = Vector2(220, 48)
	save_scene("option_row")

func _options() -> void:
	root_control("Options", OUT + "options.gd")
	scene.visible = false
	background(scene)
	var margin: MarginContainer = add(MarginContainer.new(), scene, "SafeArea")
	fill(margin)
	var column: VBoxContainer = add(VBoxContainer.new(), margin, "Column")
	label(column, "Heading", "OPTIONS", 30)
	var tabs: TabBar = add(TabBar.new(), column, "Categories", true)
	tabs.custom_minimum_size.y = 48
	tabs.focus_mode = Control.FOCUS_ALL
	var scroll: ScrollContainer = add(ScrollContainer.new(), column, "Scroll", true)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var pages: VBoxContainer = add(VBoxContainer.new(), scroll, "Pages")
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows: VBoxContainer = add(VBoxContainer.new(), pages, "Rows", true)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(column, "Status", "Changes save automatically.", 18, true)
	var actions: HBoxContainer = add(HBoxContainer.new(), column, "Actions")
	button(actions, "Reset", "Reset defaults")
	var system: VBoxContainer = add(VBoxContainer.new(), pages, "SystemPage", true)
	system.hide()
	button(system, "ReturnTitle", "Return to title")
	button(system, "QuitDesktop", "Quit to desktop")
	button(actions, "Report", "Send profile").visible = false
	button(actions, "Back", "Back")
	add(load(OUT + "exit_confirmation.tscn").instantiate(), scene, "ExitConfirmation")
	save_scene("options")

func _title() -> void:
	root_control("Title", OUT + "title.gd")
	background(scene)
	var margin: MarginContainer = add(MarginContainer.new(), scene, "SafeArea")
	fill(margin)
	var rows: VBoxContainer = add(VBoxContainer.new(), margin, "Rows")
	label(rows, "Eyebrow", "", 18)
	var mark: Control = add(load(OUT + "wordmark.tscn").instantiate(), rows, "Title")
	mark.custom_minimum_size.y = 90
	mark.set("font_size", 52)
	label(rows, "Tagline", "", 18)
	var spacer: Control = add(Control.new(), rows, "Space")
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions: VBoxContainer = add(VBoxContainer.new(), rows, "Actions")
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button(actions, "Start", "Start game")
	button(actions, "Options", "Options")
	button(actions, "Quit", "Quit")
	label(rows, "Build", "BUILD DEV", 16, true)
	save_scene("title")

func _loading() -> void:
	scene = CanvasLayer.new()
	scene.name = "LoadingScreen"
	scene.layer = 20
	scene.set_script(load(OUT + "loading_screen.gd"))
	var surface: Control = add(Control.new(), scene, "Surface")
	fill(surface)
	surface.theme = ui_theme
	background(surface)
	var margin: MarginContainer = add(MarginContainer.new(), surface, "SafeArea")
	fill(margin)
	var align: HBoxContainer = add(HBoxContainer.new(), margin, "Align")
	align.alignment = BoxContainer.ALIGNMENT_END
	var panel: PanelContainer = add(PanelContainer.new(), align, "Panel")
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rows: VBoxContainer = add(VBoxContainer.new(), panel, "Rows")
	rows.add_theme_constant_override("separation", 14)
	label(rows, "Eyebrow", "", 18)
	label(rows, "Title", "MY GAME", 32)
	label(rows, "Status", "Loading...", 20).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(rows, "Detail", "", 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add(ProgressBar.new(), rows, "Progress").custom_minimum_size.y = 22
	button(rows, "Retry", "Retry").visible = false
	save_scene("loading")

func _boot(filename: String, script: String) -> void:
	scene = Node.new()
	scene.name = "Boot"
	scene.set_script(load(script))
	add(load(OUT + "loading.tscn").instantiate(), scene, "LoadingScreen")
	save_scene(filename)
