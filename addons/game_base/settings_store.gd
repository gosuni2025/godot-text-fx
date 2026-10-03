extends RefCounted
## One store per menu. Unknown IDs stay in ConfigFile for forward compatibility.
signal changed(id: StringName, value: Variant)
const Definition = preload("res://addons/game_base/option_definition.gd")
var config_path := "user://base_settings.cfg"
var definitions: Array[Resource] = []
var values: Dictionary = {}
var _config := ConfigFile.new()

func configure(entries: Array[Resource]) -> Error:
	var seen := {}
	for entry in entries:
		if not entry is Definition or not entry.valid_definition() or seen.has(entry.id):
			return ERR_INVALID_DATA
		seen[entry.id] = true
	definitions = entries.duplicate()
	return OK

func load_settings() -> Error:
	_config.clear()
	values.clear()
	var result := _config.load(config_path)
	for entry in definitions:
		var value: Variant = _config.get_value("options", entry.id, entry.default_value())
		values[entry.id] = value if entry.valid(value) else entry.default_value()
		changed.emit(entry.id, values[entry.id])
	return OK if result == ERR_FILE_NOT_FOUND else result

func set_value(id: StringName, value: Variant) -> Error:
	for entry in definitions:
		if entry.id != id: continue
		if not entry.valid(value): return ERR_INVALID_PARAMETER
		values[id] = value
		_config.set_value("options", id, value)
		changed.emit(id, value)
		return _config.save(config_path)
	return ERR_DOES_NOT_EXIST

func reset_defaults() -> Error:
	for entry in definitions:
		values[entry.id] = entry.default_value()
		_config.set_value("options", entry.id, values[entry.id])
		changed.emit(entry.id, values[entry.id])
	return _config.save(config_path)
