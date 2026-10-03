extends RefCounted
## doc_schema 규칙 → 필드 씬. 필드 종류마다 별도 .tscn을 인스턴싱한다.

const DocSchema := preload("res://app/logic/doc_schema.gd")
const MultilineScene := preload("res://app/editor/fields/multiline_text_field.tscn")

const SCENES := {
	"num": preload("res://app/editor/fields/slider_field.tscn"),
	"int": preload("res://app/editor/fields/slider_field.tscn"),
	"bool": preload("res://app/editor/fields/toggle_field.tscn"),
	"enum": preload("res://app/editor/fields/choice_field.tscn"),
	"null_or_color": preload("res://app/editor/fields/color_field.tscn"),
	"color": preload("res://app/editor/fields/color_field.tscn"),
	"vec2": preload("res://app/editor/fields/vector_field.tscn"),
	"str": preload("res://app/editor/fields/text_field.tscn"),
}


## 경로의 규칙으로 필드를 만들어 parent에 붙인다. 규칙이 없거나 지원하지 않는 형식이면 null.
static func make(ctx, parent: Node, path: String, opts: Dictionary = {}) -> Node:
	var rule = DocSchema.rule_for(path)
	if rule == null or not SCENES.has(rule.t):
		return null
	var scene: PackedScene = MultilineScene if rule.t == "str" and opts.get("multiline", false) else SCENES[rule.t]
	var field: Node = scene.instantiate()
	field.name = path.replace(".", "_")
	parent.add_child(field)
	field.setup(ctx, path, rule, opts)
	return field
