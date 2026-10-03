class_name TextFxFont
extends RefCounted
## 글꼴 참조(Dictionary) → Font. DESIGN §4 "폰트 해석".
## bundled/path: res:// 리소스는 load(), 그 밖의 파일(user://, 절대 경로)은 FontFile.load_dynamic_font.
## system: SystemFont(font_names=[family], font_weight, font_italic).
## 파일 글꼴의 굵기는 가변 글꼴이면 wght 축, 아니면 FontVariation.variation_embolden으로 근사한다.
## 기울임은 variation_transform 기울이기. 가나·한자 누락을 막기 위해 갈무리11을 대체 글꼴로 붙인다.
## 해석 실패 시 ThemeDB.fallback_font.

const BUNDLED := {
	"Pretendard": "res://assets/fonts/pretendard/Pretendard-Regular.otf",
	"Galmuri11": "res://assets/fonts/galmuri/Galmuri11.ttf",
	"Cinzel": "res://assets/fonts/cinzel/Cinzel-Variable.ttf",
}
const FALLBACK_PATH := "res://assets/fonts/galmuri/Galmuri11.ttf"
const BASE_WEIGHT := 400
const ITALIC_SKEW := 0.2

static var _cache: Dictionary = {}
static var _base_cache: Dictionary = {}


static func cache_key(spec: Dictionary) -> String:
	return "%s|%s|%s|%d|%s" % [spec.get("source", "bundled"), spec.get("family", ""), spec.get("path", ""),
		int(spec.get("weight", 400)), str(bool(spec.get("italic", false)))]


static func resolve(spec: Variant) -> Font:
	var s: Dictionary = spec if spec is Dictionary else {}
	var key := cache_key(s)
	if _cache.has(key):
		return _cache[key]
	var font := _build(s)
	_cache[key] = font
	return font


static func clear_cache() -> void:
	_cache.clear()
	_base_cache.clear()


## 번들 글꼴 이름 목록(에디터용).
static func bundled_families() -> PackedStringArray:
	return PackedStringArray(BUNDLED.keys())


static func _build(s: Dictionary) -> Font:
	var source := str(s.get("source", "bundled"))
	var weight := int(s.get("weight", 400))
	var italic := bool(s.get("italic", false))
	var fallback := _load_base(FALLBACK_PATH)
	if source == "system":
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([str(s.get("family", "sans-serif"))])
		sf.font_weight = clampi(weight, 100, 999)
		sf.font_italic = italic
		if fallback:
			sf.fallbacks = [fallback]
		return sf
	var path := str(s.get("path", ""))
	if source == "bundled" and BUNDLED.has(str(s.get("family", ""))) and (path == "" or not _exists(path)):
		path = BUNDLED[str(s.get("family", ""))]
	var base := _load_base(path)
	if base == null:
		base = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	var wght_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	var axes: Dictionary = base.get_supported_variation_list() if base else {}
	if axes.has(wght_tag):
		var r: Vector3 = axes[wght_tag]
		fv.variation_opentype = {wght_tag: clampf(float(weight), r.x, r.y)}
	elif weight != BASE_WEIGHT:
		fv.variation_embolden = clampf(float(weight - BASE_WEIGHT) / 300.0 * 0.6, -0.4, 1.2)
	if italic:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(ITALIC_SKEW, 1), Vector2.ZERO)
	if fallback and path != FALLBACK_PATH:
		fv.fallbacks = [fallback]
	return fv


static func _exists(path: String) -> bool:
	if path.begins_with("res://"):
		return ResourceLoader.exists(path) or FileAccess.file_exists(path)
	return FileAccess.file_exists(path)


static func _load_base(path: String) -> Font:
	if path == "":
		return null
	if _base_cache.has(path):
		return _base_cache[path]
	var font: Font = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res := load(path)
		if res is Font:
			font = res
	if font == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			font = ff
	_base_cache[path] = font
	return font
