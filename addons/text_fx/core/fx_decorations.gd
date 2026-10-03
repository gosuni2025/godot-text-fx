class_name TextFxDecorations
extends RefCounted
## 장식 기하·애니메이션(DESIGN §2 decorations). 결과는 채운 사각형 목록이라 플레이어는 draw_rect만 한다.
## 기준 영역은 페이지의 본문(main) 영역. margin은 em(본문 글자 크기) 비율, thickness는 px.
## length: underline/overline/band/frame/brackets는 영역 크기 비율, side_lines는 한쪽 선 길이 = 영역 폭 × length × 0.5.
## 세로쓰기에서는 축을 바꾼다: underline은 영역 왼쪽 세로선, overline은 오른쪽, side_lines는 위·아래.
## 시간: 페이지 등장 시작(center_stamp는 내려찍기 시작) 기준 delay/duration, 퇴장 중에는 퇴장 진행만큼 투명해진다.

const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")


## 반환: [{ type, rects: Array[Rect2], color, outline(bool), outline_color, outline_size, alpha }]
static func evaluate(doc: Dictionary, layout: Dictionary, timeline: RefCounted, s: Dictionary, offset: Vector2) -> Array:
	var out: Array = []
	var decos: Array = doc.get("decorations", [])
	if decos.is_empty() or s["phase"] == "end" or s["phase"] == "gap":
		return out
	var p: int = s["page"]
	if p >= layout["pages"].size():
		return out
	var pg: Dictionary = layout["pages"][p]
	var tp: Dictionary = timeline.pages[p]
	var area: Rect2 = pg["main_rect"]
	area.position += offset
	var fs := float(layout["font_size"])
	var vertical: bool = layout["direction"] == "vertical"
	var t := float(s["page_time"]) - float(tp.get("stamp_seq", 0.0))
	var exit_alpha := 1.0
	if s["phase"] == "exit":
		var el := maxf(0.0001, float(tp["exit_len"]))
		exit_alpha = 1.0 - Easing.apply(str(doc["timeline"]["exit"]["easing"]), float(s["local"]) / el)
	var style: Dictionary = Doc.style_for(doc, "main")
	for d in decos:
		var dur := maxf(0.0, float(d["duration"]))
		var prog := 1.0
		if d["animate"] != "none":
			prog = 1.0 if dur <= 0.0 else clampf((t - float(d["delay"])) / dur, 0.0, 1.0)
			if dur <= 0.0 and t < float(d["delay"]):
				prog = 0.0
		prog = Easing.apply("cubic_out", prog)
		var alpha := exit_alpha
		var grow := 1.0
		match str(d["animate"]):
			"fade":
				alpha *= prog
			"grow_center", "grow_start":
				grow = prog
		if alpha <= 0.0 or grow <= 0.0:
			continue
		var rects := geometry(str(d["type"]), area, fs, float(d["thickness"]), float(d["margin"]) * fs, float(d["length"]), vertical)
		if grow < 1.0:
			rects = _grow(rects, grow, d["animate"] == "grow_start")
		out.append({
			"type": d["type"], "rects": rects, "color": Doc.parse_color(d["color"]),
			"outline": bool(d["use_outline"]) and bool(style["outline"]["enabled"]),
			"outline_color": Doc.parse_color(style["outline"]["color"]),
			"outline_size": float(style["outline"]["size"]), "alpha": alpha,
		})
	return out


static func geometry(type: String, r: Rect2, fs: float, th: float, margin: float, length: float, vertical: bool) -> Array:
	var c := r.get_center()
	match type:
		"underline", "overline":
			var under := type == "underline"
			if vertical:
				var h := r.size.y * length
				var x := (r.position.x - margin - th) if under else (r.end.x + margin)
				return [Rect2(x, c.y - h * 0.5, th, h)]
			var w := r.size.x * length
			var y := (r.end.y + margin) if under else (r.position.y - margin - th)
			return [Rect2(c.x - w * 0.5, y, w, th)]
		"band":
			if vertical:
				var bw := r.size.x + margin * 2.0
				var bh := maxf(r.size.y * length, r.size.y)
				return [Rect2(c.x - bw * 0.5, c.y - bh * 0.5, bw, bh)]
			var bw2 := maxf(r.size.x * length, r.size.x)
			var bh2 := r.size.y + margin * 2.0
			return [Rect2(c.x - bw2 * 0.5, c.y - bh2 * 0.5, bw2, bh2)]
		"side_lines":
			if vertical:
				var l := r.size.y * length * 0.5
				return [Rect2(c.x - th * 0.5, r.position.y - margin - l, th, l), Rect2(c.x - th * 0.5, r.end.y + margin, th, l)]
			var l2 := r.size.x * length * 0.5
			return [Rect2(r.position.x - margin - l2, c.y - th * 0.5, l2, th), Rect2(r.end.x + margin, c.y - th * 0.5, l2, th)]
		"frame", "brackets":
			var ext := Vector2(r.size.x * (length - 1.0) * 0.5, r.size.y * (length - 1.0) * 0.5).max(Vector2.ZERO)
			var f := r.grow_individual(margin + ext.x, margin + ext.y, margin + ext.x, margin + ext.y)
			if type == "frame":
				return [
					Rect2(f.position.x, f.position.y, f.size.x, th), Rect2(f.position.x, f.end.y - th, f.size.x, th),
					Rect2(f.position.x, f.position.y + th, th, f.size.y - th * 2.0), Rect2(f.end.x - th, f.position.y + th, th, f.size.y - th * 2.0),
				]
			var arm := maxf(th * 2.0, minf(f.size.x, f.size.y) * 0.3)
			return [
				Rect2(f.position.x, f.position.y, arm, th), Rect2(f.position.x, f.position.y, th, arm),
				Rect2(f.end.x - arm, f.position.y, arm, th), Rect2(f.end.x - th, f.position.y, th, arm),
				Rect2(f.position.x, f.end.y - th, arm, th), Rect2(f.position.x, f.end.y - arm, th, arm),
				Rect2(f.end.x - arm, f.end.y - th, arm, th), Rect2(f.end.x - th, f.end.y - arm, th, arm),
			]
	return []


## 사각형을 긴 축 방향으로 중심(또는 시작점)에서 늘린다.
static func _grow(rects: Array, k: float, from_start: bool) -> Array:
	var out: Array = []
	for r: Rect2 in rects:
		if r.size.x >= r.size.y:
			var w := r.size.x * k
			var x := r.position.x if from_start else r.get_center().x - w * 0.5
			out.append(Rect2(x, r.position.y, w, r.size.y))
		else:
			var h := r.size.y * k
			var y := r.position.y if from_start else r.get_center().y - h * 0.5
			out.append(Rect2(r.position.x, y, r.size.x, h))
	return out
