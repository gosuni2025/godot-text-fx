class_name TextFxGlyphState
extends RefCounted
## 시간 t에서 글자 하나의 상태(DESIGN §3). evaluator가 만들고 플레이어는 그리기만 한다.
## pos는 글자 박스 중심(캔버스 좌표), rotation은 라디안(세로쓰기 기본 회전 포함).

var index := 0
var character := ""
var role := "main"
var page := 0
var visible := false
var pos := Vector2.ZERO
var scale := Vector2.ONE
var rotation := 0.0
var alpha := 1.0
var tint := Color.WHITE
## 채우기와 장식층을 함께 흰색으로 섞는 비율, 글로우만의 세기 배율.
var brightness := 0.0
var glow_multiplier := 1.0
## 드러난 비율 0..1, clip_dir: 0 왼→오, 1 오→왼, 2 위→아래, 3 아래→위
var clip := 1.0
var clip_dir := 0
## 페이지 전체에 적용하는 캔버스 좌표 마스크. invert는 중앙부터 지우는 퇴장에 쓴다.
var clip_enabled := false
var clip_rect := Rect2()
var clip_invert := false
var clip_feather := 0.0
## 실제 흐림 반경(px)과 방향(0이면 사방). 문서·기존 상태 이름과의 호환을 위해 ghost를 유지한다.
var ghost := 0.0
var ghost_dir := Vector2.ZERO
## 글리치: 수평 조각 x 오프셋(px), 색수차(px)와 두 색
var slices := PackedFloat32Array()
var slices_global := false
var slice_origin_y := 0.0
var slice_height := 1.0
var split := 0.0
var split_color_a := Color(1.0, 0.16, 0.43)
var split_color_b := Color(0.16, 0.88, 1.0)
## center_stamp 오버레이 글자(화면 중앙 큰 글자)
var overlay := false
var overlay_scale := 1.0
## 추가 연출의 순수 평가 결과. fragment rect는 원본 스프라이트의 0..1 영역이다.
var cinematic: Dictionary = {}
var fragments: Array = []
var echoes: Array = []
## 본문과 다른 문자 스프라이트를 사용하는 문장 변이용 명시 키.
var sprite_key := ""


func to_dict() -> Dictionary:
	return {
		"index": index, "char": character, "role": role, "page": page, "visible": visible,
		"pos": pos, "scale": scale, "rotation": rotation, "alpha": alpha, "tint": tint,
		"brightness": brightness, "glow_multiplier": glow_multiplier,
		"clip": clip, "clip_dir": clip_dir, "ghost": ghost, "ghost_dir": ghost_dir,
		"clip_enabled": clip_enabled, "clip_rect": clip_rect, "clip_invert": clip_invert, "clip_feather": clip_feather,
		"slices": slices, "split": split, "split_color_a": split_color_a, "split_color_b": split_color_b,
		"slices_global": slices_global, "slice_origin_y": slice_origin_y, "slice_height": slice_height,
		"overlay": overlay, "overlay_scale": overlay_scale,
		"cinematic": cinematic, "fragments": fragments, "echoes": echoes, "sprite_key": sprite_key,
	}


func copy() -> RefCounted:
	var s = get_script().new()
	s.index = index
	s.character = character
	s.role = role
	s.page = page
	s.visible = visible
	s.pos = pos
	s.scale = scale
	s.rotation = rotation
	s.alpha = alpha
	s.tint = tint
	s.brightness = brightness
	s.glow_multiplier = glow_multiplier
	s.clip = clip
	s.clip_dir = clip_dir
	s.clip_enabled = clip_enabled
	s.clip_rect = clip_rect
	s.clip_invert = clip_invert
	s.clip_feather = clip_feather
	s.ghost = ghost
	s.ghost_dir = ghost_dir
	s.slices = slices.duplicate()
	s.slices_global = slices_global
	s.slice_origin_y = slice_origin_y
	s.slice_height = slice_height
	s.split = split
	s.split_color_a = split_color_a
	s.split_color_b = split_color_b
	s.overlay = overlay
	s.overlay_scale = overlay_scale
	s.cinematic = cinematic.duplicate(true)
	s.fragments = fragments.duplicate(true)
	s.echoes = echoes.duplicate(true)
	s.sprite_key = sprite_key
	return s
