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
## 드러난 비율 0..1, clip_dir: 0 왼→오, 1 오→왼, 2 위→아래, 3 아래→위
var clip := 1.0
var clip_dir := 0
## 잔상 흐림 반경(px)과 방향(0이면 사방)
var ghost := 0.0
var ghost_dir := Vector2.ZERO
## 글리치: 수평 조각 x 오프셋(px), 색수차(px)와 두 색
var slices := PackedFloat32Array()
var split := 0.0
var split_color_a := Color(1.0, 0.16, 0.43)
var split_color_b := Color(0.16, 0.88, 1.0)
## center_stamp 오버레이 글자(화면 중앙 큰 글자)
var overlay := false
var overlay_scale := 1.0


func to_dict() -> Dictionary:
	return {
		"index": index, "char": character, "role": role, "page": page, "visible": visible,
		"pos": pos, "scale": scale, "rotation": rotation, "alpha": alpha, "tint": tint,
		"clip": clip, "clip_dir": clip_dir, "ghost": ghost, "ghost_dir": ghost_dir,
		"slices": slices, "split": split, "split_color_a": split_color_a, "split_color_b": split_color_b,
		"overlay": overlay, "overlay_scale": overlay_scale,
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
	s.clip = clip
	s.clip_dir = clip_dir
	s.ghost = ghost
	s.ghost_dir = ghost_dir
	s.slices = slices.duplicate()
	s.split = split
	s.split_color_a = split_color_a
	s.split_color_b = split_color_b
	s.overlay = overlay
	s.overlay_scale = overlay_scale
	return s
