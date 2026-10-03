extends RefCounted
## No endpoint, project ID or credential is embedded in the reusable module.
var project_id: String = ""
var endpoint: String = ""
var build_label: String = ""
var detailed_diagnostics: bool = false
var build_from_project_settings: bool = false
var measurement_schema_version: int = 1
var render_path: String = "default"

func is_valid() -> bool:
	return not project_id.is_empty() and endpoint.begins_with("https://")
