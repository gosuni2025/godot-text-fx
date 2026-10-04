extends Control
## 편집기 화면(DESIGN §7). EditorModel 하나를 들고, 모든 사용자 조작을 명령으로 바꿔 send()로 보낸다.
## 화면 갱신은 model.changed(paths)에서만 한다. 문서를 직접 바꾸는 UI 코드는 없다.
## 패널·필드·팝업은 이 노드를 ctx로 받아 model 읽기, send(), 아이콘·팝업·파일 요청을 쓴다.
## 셸 연결: AppShell.play_bgm() / open_options(true) / go_to_title() (셸이 없으면 생략).

const EditorModel := preload("res://app/logic/editor_model.gd")
const DocApi := preload("res://app/logic/doc_api.gd")
const OpLog := preload("res://app/logic/op_log.gd")
const Templates := preload("res://app/logic/templates.gd")
const DocSchema := preload("res://app/logic/doc_schema.gd")
const JsonUtil := preload("res://app/logic/json_util.gd")
const FxFont := preload("res://addons/text_fx/core/fx_font.gd")
const Shortcuts := preload("res://app/editor/editor_shortcuts.gd")

const DEFAULT_TEMPLATE := "msg_battle_engage"
const FONT_DIR := "user://fonts"
const BASE_SIZE := Vector2(1600, 900)
const BASE_FONT := 20
const BASE_ICON := 26
const TABS := ["mode", "text", "motion", "style", "font", "decor", "layout", "export"]

signal command_sent(cmd: Dictionary, ok: bool)

## 자동 저장 경로(테스트는 다른 경로를 넣고 트리에 붙인다). ""이면 자동 저장하지 않는다.
@export var autosave_path := "user://autosave.json"
@export var autosave_delay := 1.0

var model
var op_log
var ui_scale := 1.0
var current_tab := "mode"
var _panels: Dictionary = {}
var _icons: Dictionary = {}
var _doc_dirty := true
var _file_cb: Callable
var _shortcuts

@onready var preview: Control = %Preview
@onready var picker: PopupPanel = %PickerPopup
@onready var font_picker: PopupPanel = %FontPicker
@onready var _autosave_timer: Timer = %AutosaveTimer


func _ready() -> void:
	_init_model()
	_shortcuts = Shortcuts.new(self)
	model.changed.connect(_on_model_changed)
	_autosave_timer.wait_time = autosave_delay
	_autosave_timer.timeout.connect(save_autosave)
	(%FileDialog as FileDialog).file_selected.connect(_on_file_selected)
	(%Undo as Button).pressed.connect(func(): send({"op": "undo"}))
	(%Redo as Button).pressed.connect(func(): send({"op": "redo"}))
	(%Settings as Button).pressed.connect(open_options)
	(%Back as Button).pressed.connect(go_to_title)
	for id in TABS:
		var panel: Node = get_node("%Panel_" + id)
		_panels[id] = panel
		(get_node("%Tab_" + id) as Button).pressed.connect(select_tab.bind(id))
	get_viewport().size_changed.connect(_apply_scale)
	(%Right as Control).resized.connect(_fit_tabs)
	_apply_scale()
	preview.setup(self)
	for id in _panels:
		_panels[id].setup(self)
	select_tab("mode")
	_refresh_top()
	preview.set_document(model.doc)
	_doc_dirty = false
	var shell := _shell()
	if shell:
		shell.play_bgm()
	(get_node("%Tab_mode") as Button).grab_focus.call_deferred()


func _exit_tree() -> void:
	if not _autosave_timer.is_stopped():
		save_autosave()


# --- 모델·명령 -----------------------------------------------------------

func _init_model() -> void:
	var loc := ui_locale()
	var restored := load_autosave()
	model = EditorModel.new(restored, loc)
	if restored.is_empty() or JsonUtil.canonical_json(model.doc) == JsonUtil.canonical_json(DocApi.defaults()):
		var id := DEFAULT_TEMPLATE if Templates.has(DEFAULT_TEMPLATE) else Templates.ids()[0]
		model.apply({"op": "apply_template", "id": id})
	model.apply({"op": "play", "from": 0.0})
	op_log = OpLog.create(0, model.doc, model.locale)


## UI의 모든 조작은 여기로 온다. 조작 기록에 남기고(연속 seek·export는 마지막 하나로) 모델에 적용한다.
func send(cmd: Dictionary) -> bool:
	var last: Dictionary = op_log.commands[-1] if not op_log.commands.is_empty() else {}
	if cmd.get("op") in ["seek", "export"] and last.get("op") == cmd.get("op"):
		op_log.commands[-1] = JsonUtil.canon(cmd)
	else:
		op_log.append(cmd)
	var ok: bool = model.apply(cmd.duplicate(true))
	if not ok:
		set_status(tr("Rejected: %s") % model.last_error, true)
	command_sent.emit(cmd, ok)
	return ok


func _on_model_changed(paths: PackedStringArray) -> void:
	var doc_paths := PackedStringArray()
	var state := PackedStringArray()
	for p in paths:
		if p.begins_with("$"):
			state.append(p)
		else:
			doc_paths.append(p)
	if not doc_paths.is_empty():
		_doc_dirty = true
		if autosave_path != "":
			_autosave_timer.start()
		for id in _panels:
			_panels[id].on_doc_changed(doc_paths)
	if "$locale" in state:
		for id in _panels:
			_panels[id].mark_rebuild()
	if not state.is_empty():
		for id in _panels:
			_panels[id].on_state_changed(state)
	if "$time" in state or "$playing" in state:
		preview.show_time()
	if "$history" in state or "*" in doc_paths or "name" in doc_paths:
		_refresh_top()


func _process(delta: float) -> void:
	if _doc_dirty:
		_doc_dirty = false
		preview.set_document(model.doc)
	if model.playing:
		model.advance(delta, preview.end_time())
		if preview.is_ended():
			send({"op": "pause"})


func _refresh_top() -> void:
	(%Undo as Button).disabled = not model.can_undo()
	(%Redo as Button).disabled = not model.can_redo()
	(%DocName as Label).text = str(model.get_value("name"))


func set_status(text: String, is_error := false) -> void:
	var l := %Status as Label
	l.text = text
	l.tooltip_text = text
	l.modulate = Color(1.0, 0.55, 0.5) if is_error else Color(0.7, 0.95, 0.75)


# --- 탭 ------------------------------------------------------------------

func select_tab(id: String) -> void:
	if not _panels.has(id):
		return
	current_tab = id
	for t in TABS:
		(get_node("%Tab_" + t) as Button).set_pressed_no_signal(t == id)
		(_panels[t] as Control).visible = t == id
	_panels[id].sync()
	_link_tab_focus.call_deferred()


## 아래 줄 탭에서 ↓/D패드 아래로 가면 현재 패널의 첫 컨트롤로 간다.
func _link_tab_focus() -> void:
	var first := _first_focusable(_panels[current_tab])
	var cols: int = (%Tabs as GridContainer).columns
	for i in TABS.size():
		var b := get_node("%Tab_" + TABS[i]) as Button
		var last_row := i >= TABS.size() - cols
		b.focus_neighbor_bottom = b.get_path_to(first) if first and last_row else NodePath()


static func _first_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			if (c as Control).focus_mode == Control.FOCUS_ALL:
				return c
			var inner := _first_focusable(c)
			if inner:
				return inner
	return null


## 탭 버튼이 한 줄에 들어가면 8열, 아니면 4열 두 줄.
func _fit_tabs() -> void:
	var grid := %Tabs as GridContainer
	var need := 0.0
	for id in TABS:
		need += (get_node("%Tab_" + id) as Control).get_combined_minimum_size().x + 2.0
	grid.columns = TABS.size() if need <= (%Right as Control).size.x else TABS.size() / 2
	_link_tab_focus()


func step_tab(step: int) -> void:
	select_tab(TABS[posmod(TABS.find(current_tab) + step, TABS.size())])
	(get_node("%Tab_" + current_tab) as Button).grab_focus()


func panel(id: String) -> Node:
	return _panels.get(id)


# --- ctx 도우미(패널·필드·팝업용) ---------------------------------------

func ui_icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var path := "res://assets/icons/ui/%s.png" % icon_name
		_icons[icon_name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[icon_name]


## 템플릿 아이콘. 파일이 아직 없으면 분류/모드 UI 아이콘으로 대신한다.
func template_icon(icon_id: String, fallback: String) -> Texture2D:
	var path := "res://assets/icons/templates/%s.png" % icon_id
	if icon_id != "" and ResourceLoader.exists(path):
		return load(path)
	return ui_icon(fallback)


func scaled(v: Vector2) -> Vector2:
	return (v * ui_scale).round()


func preview_sample() -> String:
	return tr("Text FX")


func ui_locale() -> String:
	var loc := TranslationServer.get_locale().substr(0, 2)
	return loc if loc in DocSchema.LOCALES else "en"


func popup_rect() -> Rect2i:
	var r := (%Right as Control).get_global_rect()
	return Rect2i(r.grow(-4.0))


func open_picker(title: String, items: Array, current: String, callback: Callable, close_on_pick := false) -> void:
	picker.card_size = scaled(Vector2(150, 112))
	picker.open_items(title, items, current, callback, popup_rect(), close_on_pick)


func open_font_picker(target: String) -> void:
	font_picker.card_size = scaled(Vector2(170, 100))
	font_picker.open_for(self, target, popup_rect())


func request_file(mode: int, filters: PackedStringArray, suggested: String, callback: Callable) -> void:
	var d := %FileDialog as FileDialog
	d.file_mode = mode as FileDialog.FileMode
	d.filters = filters
	if suggested != "":
		d.current_file = suggested
	_file_cb = callback
	d.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	if _file_cb.is_valid():
		_file_cb.call(path)


func request_font_file(target: String) -> void:
	request_file(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.ttf, *.otf, *.woff, *.woff2 ; Fonts"]), "",
		import_font_file.bind(target))


## 글꼴 파일을 user://fonts 에 복사하고 그 경로를 참조하는 set 명령을 보낸다.
func import_font_file(path: String, target: String) -> bool:
	DirAccess.make_dir_recursive_absolute(FONT_DIR)
	var dest := "%s/%s" % [FONT_DIR, path.get_file()]
	if path != ProjectSettings.globalize_path(dest) and DirAccess.copy_absolute(path, dest) != OK:
		set_status(tr("Could not copy the font file."), true)
		return false
	FxFont.clear_cache()
	var cur = model.get_value(target)
	cur = cur if cur is Dictionary else model.get_value("font")
	var spec := {"source": "path", "family": path.get_file().get_basename(), "path": dest,
		"weight": float(cur.get("weight", 700.0)), "italic": bool(cur.get("italic", false))}
	return send({"op": "set", "path": target, "value": spec})


func request_bg_image() -> void:
	request_file(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]), "",
		load_bg_image)


func load_bg_image(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		set_status(tr("Could not read the image."), true)
		return false
	preview.set_bg_image(ImageTexture.create_from_image(img))
	return true


# --- 자동 저장 -----------------------------------------------------------

func load_autosave() -> Dictionary:
	if autosave_path == "" or not FileAccess.file_exists(autosave_path):
		return {}
	var f := FileAccess.open(autosave_path, FileAccess.READ)
	var data = JsonUtil.parse(f.get_as_text()) if f else null
	return data if data is Dictionary else {}


func save_autosave() -> void:
	_autosave_timer.stop()
	if autosave_path == "":
		return
	var f := FileAccess.open(autosave_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(model.doc, "\t", true))


# --- 셸 ------------------------------------------------------------------

func _shell() -> Node:
	return get_node_or_null("/root/AppShell")


func open_options() -> void:
	var shell := _shell()
	if shell == null:
		return
	var back := get_viewport().gui_get_focus_owner()
	if back and not shell.options_closed.is_connected(back.grab_focus):
		shell.options_closed.connect(back.grab_focus, CONNECT_ONE_SHOT)
	shell.open_options(false)


func go_to_title() -> void:
	save_autosave()
	var shell := _shell()
	if shell:
		shell.go_to_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and model != null and is_node_ready():
		if ui_locale() != model.locale:
			send({"op": "set_locale", "locale": ui_locale()})


func _apply_scale() -> void:
	var vs := get_viewport_rect().size
	var s := clampf(minf(vs.x / BASE_SIZE.x, vs.y / BASE_SIZE.y), 0.8, 2.0)
	if is_equal_approx(s, ui_scale) and theme.default_font_size == roundi(BASE_FONT * s):
		return
	ui_scale = s
	theme.default_font_size = roundi(BASE_FONT * s)
	theme.set_constant("icon_max_width", "Button", roundi(BASE_ICON * s))
	for id in _panels:
		_panels[id].mark_rebuild()


func _input(event: InputEvent) -> void:
	if _shortcuts.handle_input(event):
		get_viewport().set_input_as_handled()


func _shortcut_input(event: InputEvent) -> void:
	if _shortcuts.handle_shortcut(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _shortcuts.handle_unhandled(event):
		get_viewport().set_input_as_handled()
