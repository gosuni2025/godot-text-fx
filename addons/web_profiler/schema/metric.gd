extends RefCounted
## Explicit wire contract. Read native typed properties; reject invalid enum/numeric values.
enum Kind { INTEGER, NUMBER, BOOLEAN, CODE, ENUM, VECTOR2, VECTOR3I, SAMPLE }
var property: StringName
var key: StringName
var kind: Kind
var unit: String
var meaning: String
var choices: PackedStringArray
var minimum: float
var maximum: float
var presence: StringName
var omit_zero: bool
var resolution: float

func _init(field: StringName, type: Kind, units: String, description: String,
	allowed: PackedStringArray = [], low: float = -INF, high: float = INF,
	present_if: StringName = &"", skip_zero: bool = false, step: float = 0.0) -> void:
	property = field
	key = field
	kind = type
	unit = units
	meaning = description
	choices = allowed.duplicate()
	minimum = low
	maximum = high
	presence = present_if
	omit_zero = skip_zero
	resolution = step

func error(value: Variant) -> String:
	var valid := false
	match kind:
		Kind.INTEGER: valid = value is int and value >= minimum and value <= maximum
		Kind.NUMBER: valid = (value is int or value is float) and is_finite(value) and value >= minimum and value <= maximum
		Kind.BOOLEAN: valid = value is bool
		Kind.CODE: valid = value is String and value in choices
		Kind.ENUM: valid = value is int and value >= 0 and value < choices.size()
		Kind.VECTOR2: valid = value is Vector2 and value.is_finite()
		Kind.VECTOR3I: valid = value is Vector3i
		Kind.SAMPLE: valid = value is RefCounted and value.has_method("validation_errors") and value.validation_errors().is_empty()
	return "" if valid else "Invalid metric: " + str(key)

func encode(value: Variant) -> Variant:
	match kind:
		Kind.ENUM: return choices[value]
		Kind.VECTOR2: return [snappedf(value.x, resolution), snappedf(value.y, resolution)] if resolution > 0 else [value.x, value.y]
		Kind.VECTOR3I: return [value.x, value.y, value.z]
		Kind.SAMPLE: return value.serialize()
	return value
