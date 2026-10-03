@tool
extends RefCounted
## Export-time hints only. Never changes a shader or its uniforms.

static func build(directory: String = "res://shaders") -> Dictionary:
	if not DirAccess.dir_exists_absolute(directory): return {}
	var symbols := RegEx.create_from_string("\\b[A-Za-z_][A-Za-z_0-9]*\\b")
	var comments := RegEx.create_from_string("(?s)/\\*.*?\\*/|//[^\\n]*")
	var owners := {}
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".gdshader"): continue
		var path := directory.path_join(file)
		var code := comments.sub(_expanded(path, []), "", true)
		var seen := {}
		for found in symbols.search_all(code):
			var symbol: String = found.get_string()
			if seen.has(symbol): continue
			seen[symbol] = true
			if not owners.has(symbol): owners[symbol] = []
			owners[symbol].append(path)
	var catalog := {}
	for symbol: String in owners:
		# Godot GLES3 prefixes user identifiers, including function locals, with m_.
		# Keep all candidates: a match is evidence, not an asserted material instance.
		if owners[symbol].size() > 3: continue
		var generated := "m_" + symbol.replace("__", "_dus_").replace("__", "_dus_")
		catalog[generated] = owners[symbol]
	return catalog

static func _expanded(path: String, stack: Array) -> String:
	if path in stack: return ""
	var next := stack + [path]
	var code := FileAccess.get_file_as_string(path)
	var includes := RegEx.create_from_string('#include\\s+"([^"]+)"')
	for found in includes.search_all(code):
		var included: String = found.get_string(1)
		if not included.begins_with("res://"): included = path.get_base_dir().path_join(included)
		code += "\n" + _expanded(included, next)
	return code
