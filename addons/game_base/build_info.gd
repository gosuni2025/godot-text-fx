extends RefCounted

static var _development_version := ""

static func display_text() -> String:
	# F5/F6 and source-project CLI runs use the editor binary. An old export
	# stamp must not identify today's local run; keep one DEV time per process.
	var value := development_version() if OS.has_feature("editor") else version()
	return TranslationServer.translate("BUILD %s") % value

static func development_version() -> String:
	if not _development_version.is_empty(): return _development_version
	var time := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 9 * 60 * 60)
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
	var revision := ""
	var path := ProjectSettings.globalize_path("res://")
	if DirAccess.dir_exists_absolute(path.path_join(".git")) or FileAccess.file_exists(path.path_join(".git")):
		var output: Array = []
		if OS.execute("git", ["-C", path, "rev-parse", "--short=8", "HEAD"], output, true) == 0:
			revision = str(output[0]).strip_edges()
	_development_version = stamp + "-DEV" + ("-" + revision if not revision.is_empty() else "")
	return _development_version

static func metadata() -> Dictionary:
	if FileAccess.file_exists("res://build_info.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if data is Dictionary: return data
	return {"version": "DEV", "build_number": "", "revision": ""}

static func version() -> String:
	# Export plugins run in the editor too: always embed the immutable stamp,
	# never the editor's display-only DEV run identifier.
	return str(metadata().get("version", "DEV"))
