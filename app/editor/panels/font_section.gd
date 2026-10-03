extends PanelContainer
## 글꼴 탭의 묶음 하나(본문 font 또는 보조 sub_font): 글꼴 고르기 버튼(팝업) + 굵기 + 기울임.

const FxFont := preload("res://addons/text_fx/core/fx_font.gd")

var ctx
var panel
var path := "font"


func setup(p_ctx, p_panel, p_path: String, title: String) -> void:
	ctx = p_ctx
	panel = p_panel
	path = p_path
	(%Title as Label).text = title
	(%Pick as Button).pressed.connect(func(): ctx.open_font_picker(path))


func build() -> void:
	var box := %Fields as VBoxContainer
	panel.clear_box(box)
	if not (ctx.model.get_value(path) is Dictionary):
		return
	panel.add_field(box, path + ".weight", {"step": 100.0})
	panel.add_field(box, path + ".italic")
	refresh()


func refresh() -> void:
	var spec = ctx.model.get_value(path)
	if not (spec is Dictionary):
		return
	var b := %Pick as Button
	b.text = str(spec.get("family", ""))
	b.add_theme_font_override("font", FxFont.resolve(spec))
	var src := str(spec.get("source", "bundled"))
	(%Source as Label).text = {"system": "System font", "path": "Font file"}.get(src, "Bundled font")
	(%Path as Label).text = str(spec.get("path", "")) if src == "path" else ""
	(%Path as Label).visible = src == "path"
