class_name TextFxPlayer
extends Control
## 문자 연출 JSON을 읽어 재생하는 노드(DESIGN §4).
## 시간 t의 글자 상태는 TextFxEvaluator가 계산하고, 이 노드는 구운 스프라이트를 그리기만 한다.
## 글자마다 스타일을 구운 뒤 독립 글로우·블러·마스크 셰이더로 그린다. 페이드 중에 테두리가 채우기 안으로 비치지 않는다.
##
## 사용: load_file(path) 또는 set_document(dict) → set_text(main, sub) → play().
## loop = "loop_hold"인 문서는 유지 구간을 반복하다가 finish() 호출 시 퇴장하고 finished를 보낸다.

signal started
signal entered
signal page_changed(page: int)
signal exit_started
signal finished
signal looped
signal baked

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const GlyphState := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Baker := preload("res://addons/text_fx/render/fx_glyph_baker.gd")
const Plan := preload("res://addons/text_fx/render/fx_bake_plan.gd")
const Drawer := preload("res://addons/text_fx/render/fx_glyph_drawer.gd")
const GlyphRenderer := preload("res://addons/text_fx/render/fx_glyph_renderer.gd")
const BackgroundDrawer := preload("res://addons/text_fx/render/fx_background_drawer.gd")
const DecorationDrawer := preload("res://addons/text_fx/render/fx_decoration_drawer.gd")

## 다시 굽는 배율 변화 임계값(축소 쪽)과 크기 변경 후 대기 시간. 확대는 흐려지므로 한 단계(0.05)만 커져도 다시 굽는다.
const REBAKE_RATIO := 0.12
const REBAKE_DELAY := 0.15

@export_file("*.json") var document_path := "":
	set(v):
		document_path = v
		if is_inside_tree() and v != "":
			load_file(v)
@export var autoplay := true
@export_enum("contain", "cover", "none") var fit := "contain":
	set(v):
		fit = v
		_schedule_rebake()
		queue_redraw()
@export var speed := 1.0
@export var paused := false

var _doc: Dictionary = {}
var _ev: Evaluator = null
var _fonts: Dictionary = {}
var _time := 0.0
var _finish_at := -1.0
var _playing := false
var _pending_start := false
var _finished_emitted := false
var _last: Dictionary = {}
var _entered_keys: Dictionary = {}
var _exit_emitted := false
var _baker: Baker = null
var _sprites: Dictionary = {}
var _plan: Dictionary = {}
var _bake_scale := 0.0
var _bake_sig := ""
var _baking := false
var _bake_again := false
var _rebake_timer := -1.0
var _glyph_renderer := GlyphRenderer.new()
var _background_drawer := BackgroundDrawer.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 게임 프로젝트의 기본 텍스처 필터가 nearest여도 구운 글자를 확대·축소할 때 계단이 생기지 않게 한다.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = mat


func _ready() -> void:
	_baker = Baker.new()
	_baker.name = "GlyphBaker"
	add_child(_baker, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_schedule_rebake)
	if _doc.is_empty() and document_path != "":
		load_file(document_path)
	elif not _doc.is_empty():
		_request_bake()
		if autoplay and not _playing:
			play()


func _exit_tree() -> void:
	_glyph_renderer.clear()


# ---- 공개 API ----

func load_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("TextFxPlayer: 파일을 열 수 없음 %s" % path)
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		push_warning("TextFxPlayer: JSON 오류 %s" % path)
		return false
	return set_document(json.data)


## 생략된 필드는 기본값으로 채운다(v1/부분 문서 지원). 잘못된 문서는 현재 재생을 보존하고 false를 돌려준다.
func set_document(doc: Dictionary) -> bool:
	var errors := Doc.validate(doc)
	if not errors.is_empty():
		push_warning("TextFxPlayer: 문서 오류: " + "; ".join(errors))
		return false
	_doc = Doc.normalize(doc)
	_rebuild(true)
	return true


func get_document() -> Dictionary:
	return _doc.duplicate(true)


## 본문·보조 문구만 바꾼다. 재생 중이었다면 처음부터 다시 재생한다.
func set_text(main: String, sub: String = "") -> void:
	if _doc.is_empty():
		_doc = Doc.normalize({})
	_doc["text"] = main
	_doc["sub_text"] = sub
	_rebuild(false)


func play(from: float = 0.0) -> void:
	if _ev == null:
		return
	_time = maxf(0.0, from)
	_finish_at = -1.0
	_playing = true
	_finished_emitted = false
	_exit_emitted = false
	_entered_keys.clear()
	_last = {}
	_pending_start = _baking
	if not _pending_start:
		_update_events()
	queue_redraw()


func stop() -> void:
	_playing = false
	_pending_start = false
	_time = 0.0
	_finish_at = -1.0
	_last = {}
	queue_redraw()


func seek(t: float) -> void:
	_time = maxf(0.0, t)
	if _ev:
		_last = _ev.timeline.sample(_time, _finish_at)
	queue_redraw()


## loop_hold 등에서 퇴장으로 넘어간다(현재 페이지 등장이 끝난 뒤).
func finish() -> void:
	if _ev and _finish_at < 0.0:
		_finish_at = _time


func is_playing() -> bool:
	return _playing and not _finished_emitted


func is_baked() -> bool:
	return not _baking and (not _sprites.is_empty() or not Baker.can_bake())


func get_duration() -> float:
	return _ev.get_duration() if _ev else 0.0


func get_time() -> float:
	return _time


func get_evaluator() -> Evaluator:
	return _ev


## 시간을 직접 진행한다(테스트·수동 구동용). _process는 delta * speed로 이 함수를 부른다.
func advance(delta: float) -> void:
	if not _playing or _pending_start or _ev == null:
		return
	_time += delta
	_update_events()
	queue_redraw()


# ---- 내부 ----

func _process(delta: float) -> void:
	if _rebake_timer >= 0.0:
		_rebake_timer -= delta
		if _rebake_timer < 0.0:
			_request_bake()
	if _playing and not paused:
		advance(delta * speed)


func _rebuild(reset: bool) -> void:
	var was_playing := _playing
	_fonts = Layout.resolve_fonts(_doc)
	_ev = Evaluator.new(_doc, {}, _fonts)
	_request_bake()
	if reset:
		stop()
		if autoplay and is_inside_tree():
			play()
	elif was_playing:
		play()
	queue_redraw()


func _fit_transform() -> Array:
	var canvas := Vector2(float(_doc["canvas"]["width"]), float(_doc["canvas"]["height"]))
	var s := 1.0
	if fit != "none" and size.x > 0.0 and size.y > 0.0:
		s = minf(size.x / canvas.x, size.y / canvas.y) if fit == "contain" else maxf(size.x / canvas.x, size.y / canvas.y)
	var origin := (size - canvas * s) * 0.5 if size.x > 0.0 else Vector2.ZERO
	return [origin, s]


func _desired_bake_scale() -> float:
	return clampf(snappedf(float(_fit_transform()[1]), 0.05), 0.25, 4.0)


## 구운 배율 baked로 want 배율에 그려도 되는지. 확대(흐려짐)는 바로, 축소는 REBAKE_RATIO를 넘을 때 다시 굽는다.
static func needs_rebake(baked: float, want: float) -> bool:
	if baked <= 0.0:
		return true
	if want > baked + 0.001:
		return true
	return 1.0 - want / baked > REBAKE_RATIO


func _schedule_rebake() -> void:
	if _ev == null:
		return
	if needs_rebake(_bake_scale, _desired_bake_scale()):
		_rebake_timer = REBAKE_DELAY


func _request_bake() -> void:
	if _ev == null or not is_inside_tree() or _baker == null:
		return
	if not Baker.can_bake():
		_sprites = {}
		_plan = Plan.build(_ev, _fonts, 1.0)
		return
	if _baking:
		_bake_again = true
		return
	_bake()


func _bake() -> void:
	var scale_now := _desired_bake_scale()
	var plan := Plan.build(_ev, _fonts, scale_now)
	if plan["signature"] == _bake_sig and not _sprites.is_empty():
		_plan = plan
		return
	_baking = true
	var sprites: Dictionary = await _baker.bake(plan["jobs"])
	_baking = false
	if _bake_again:
		_bake_again = false
		_bake()
		return
	_sprites = sprites
	_plan = plan
	_bake_scale = scale_now
	_bake_sig = plan["signature"]
	baked.emit()
	# 굽는 동안 크기가 바뀌었으면(시작 배율이 낡았으면) 다시 굽기를 예약한다.
	_schedule_rebake()
	if _pending_start:
		_pending_start = false
		_update_events()
	queue_redraw()


func _update_events() -> void:
	var s := _ev.timeline.sample(_time, _finish_at)
	var first := _last.is_empty()
	if first:
		started.emit()
	if not first and int(s["loop_index"]) > int(_last["loop_index"]):
		_entered_keys.clear()
		_exit_emitted = false
		looped.emit()
	if first or int(s["page"]) != int(_last["page"]) or int(s["loop_index"]) != int(_last["loop_index"]):
		page_changed.emit(int(s["page"]))
	var key := "%d:%d" % [int(s["loop_index"]), int(s["page"])]
	if s["phase"] != "enter" and s["phase"] != "gap" and not _entered_keys.has(key):
		_entered_keys[key] = true
		entered.emit()
	var skipped_exit: bool = s["phase"] == "end" and _ev.timeline.exit_enabled
	if ((s["phase"] == "exit" and s["final"]) or skipped_exit) and not _exit_emitted:
		_exit_emitted = true
		exit_started.emit()
	if s["done"] and not _finished_emitted:
		_finished_emitted = true
		if s["phase"] == "end":
			_playing = false
		finished.emit()
	_last = s


func _draw() -> void:
	_glyph_renderer.begin(get_canvas_item())
	if _ev == null:
		_glyph_renderer.end()
		return
	var frame := _ev.evaluate_frame(_time, _finish_at)
	var ft := _fit_transform()
	var origin: Vector2 = ft[0]
	var s: float = ft[1]
	draw_set_transform(origin, 0.0, Vector2(s, s))
	_background_drawer.draw(self, frame.get("background", {}))
	for deco in frame["decorations"]:
		DecorationDrawer.draw(self, deco)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if _sprites.is_empty():
		_glyph_renderer.end()
		return
	var keys: PackedStringArray = _plan.get("glyph_keys", PackedStringArray())
	var okeys: Dictionary = _plan.get("overlay_keys", {})
	var normal: Array = []
	var over: Array = []
	for st: GlyphState in frame["glyphs"]:
		if not st.visible:
			continue
		var key: String = okeys.get(st.index, "") if st.overlay else (keys[st.index] if st.index < keys.size() else "")
		var spr: Dictionary = _sprites.get(key, {})
		if spr.is_empty():
			continue
		(over if st.overlay else normal).append([st, spr])
	# 뒤 레이어(글로우·그림자·테두리)를 모두 그린 뒤 채우기를 그린다.
	for group in [normal, over]:
		for front in [false, true]:
			for item in group:
				_glyph_renderer.draw_glyph(item[0], item[1], origin, s, front)
	_glyph_renderer.end()
