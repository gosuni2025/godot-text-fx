extends RefCounted
## Stable persisted IDs and positional bindings; neutral labels in player-facing UI.
const TYPES := ["auto", "xbox", "playstation", "switch"]
const NAMES := {"xbox": "Type A", "playstation": "Type B", "switch": "Type C"}

static func detect(device_name: String, info: Dictionary = {}) -> String:
	var vendor := int(info.get("vendor_id", 0))
	if vendor == 0x054c: return "playstation"
	if vendor == 0x057e: return "switch"
	if vendor == 0x045e or info.has("xinput_index"): return "xbox"
	var names := (device_name + " " + str(info.get("raw_name", ""))).to_lower()
	for marker in ["playstation", "dualshock", "dual shock", "dualsense", "dual sense", "sony", "ps3", "ps4", "ps5", "vendor: 054c"]:
		if marker in names: return "playstation"
	for marker in ["nintendo", "switch", "joy-con", "joycon", "vendor: 057e"]:
		if marker in names: return "switch"
	if device_name.to_lower().strip_edges() == "pro controller": return "switch"
	return "xbox"
