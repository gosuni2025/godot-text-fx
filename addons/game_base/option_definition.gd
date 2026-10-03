@tool
extends Resource
enum Kind { TOGGLE, RANGE, CHOICE }
@export var id: StringName = &"custom_option"
@export var label := "Custom option"
@export var category := "General"
@export var kind: Kind = Kind.TOGGLE
@export var enabled := true
@export var default_toggle := false
@export var default_number := 1.0
@export var minimum := 0.0
@export var maximum := 1.0
@export var step := 0.05
@export var choices := PackedStringArray()
@export var choice_labels := PackedStringArray()
@export var default_choice := ""

func default_value() -> Variant:
	match kind:
		Kind.TOGGLE: return default_toggle
		Kind.RANGE: return default_number
		Kind.CHOICE: return default_choice
	return null

func valid(value: Variant) -> bool:
	match kind:
		Kind.TOGGLE: return value is bool
		Kind.RANGE:
			return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum
		Kind.CHOICE: return value is String and value in choices
	return false

func valid_definition() -> bool:
	return not str(id).is_empty() and not label.is_empty() and minimum <= maximum and step > 0 \
		and (kind != Kind.CHOICE or (not choices.is_empty() and choices.size() == choice_labels.size())) \
		and valid(default_value())
