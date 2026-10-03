class_name TextFxDecorations
extends RefCounted
## 장식 기하·애니메이션(DESIGN §2 decorations). 결과는 채운 사각형 목록이라 플레이어는 draw_rect만 한다.
## 기준 영역은 페이지의 본문(main) 영역. margin은 em(본문 글자 크기) 비율, thickness는 px.
## length: underline/overline/band/frame/brackets는 영역 크기 비율, side_lines는 한쪽 선 길이 = 영역 폭 × length × 0.5.
## 세로쓰기에서는 축을 바꾼다: underline은 영역 왼쪽 세로선, overline은 오른쪽, side_lines는 위·아래.
## 시간: 페이지 등장 시작(center_stamp는 내려찍기 시작) 기준 delay/duration, 퇴장 중에는 퇴장 진행만큼 투명해진다.

const Easing := preload("res://addons/text_fx/core/fx_easing.gd")
const Shapes := preload("res://addons/text_fx/core/fx_decoration_shapes.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")


## 반환: [{ type, rects: Array[Rect2], color, outline(bool), outline_color, outline_size, alpha }]
static func evaluate(doc: Dictionary, layout: Dictionary, timeline: RefCounted, s: Dictionary, offset: Vector2) -> Array:
	var out: Array = []
	if s["phase"] in ["end", "gap", "lead_in", "lead_out"]:
		return out
	var page := int(s["page"])
	if page >= layout["pages"].size():
		return out
	var pg: Dictionary = layout["pages"][page]
	var tp: Dictionary = timeline.pages[page]
	var fs := float(layout["font_size"])
	var vertical: bool = layout["direction"] == "vertical"
	var style: Dictionary = Doc.style_for(doc, "main")
	for d: Dictionary in doc.get("decorations", []):
		var type := str(d["type"])
		var area: Rect2 = pg["rect"] if type == "box" or (type == "band" and d.get("full_span", false)) else pg["main_rect"]
		area.position += offset
		var time := float(s["page_time"]) - (0.0 if d.get("lead_text", false) else float(tp.get("stamp_seq", 0.0)))
		var progress := _progress(time - float(d["delay"]), float(d["duration"]))
		var leave := 0.0
		if s["phase"] == "exit":
			var exit_duration := float(d.get("exit_duration", 0.0))
			if exit_duration <= 0.0:
				exit_duration = float(tp["exit_len"])
			leave = _progress(float(s["local"]) - float(d.get("exit_delay", 0.0)), exit_duration)
		var animation := str(d["animate"])
		var alpha := 1.0 - leave
		var grow := 1.0
		if animation == "fade":
			alpha *= progress
		elif animation in ["grow_center", "grow_start"]:
			grow = progress
		elif animation == "shape":
			alpha = 1.0 if progress > 0.0 and leave < 1.0 else 0.0
		if alpha <= 0.0 or grow <= 0.0:
			continue
		var thickness := float(d["thickness"])
		var sub: Rect2 = pg["sub_rect"]
		sub.position += offset
		var margin := float(d["margin"]) * fs
		var rects := geometry(type, area, fs, thickness, margin, float(d["length"]), vertical)
		if type == "frame" and (d.get("protect_sub", false) or d.get("clamp_canvas", false)):
			var extension := (area.size * (float(d["length"]) - 1.0) * 0.5).max(Vector2.ZERO)
			var frame := area.grow_individual(margin + extension.x, margin + extension.y, margin + extension.x, margin + extension.y)
			if d.get("protect_sub", false) and sub.has_area():
				frame = _protect(frame, area, sub, vertical)
			if d.get("clamp_canvas", false):
				frame = frame.intersection(Rect2(Vector2.ZERO, layout["canvas"]))
			rects = geometry(type, frame, fs, thickness, 0.0, 1.0, vertical)
		if type == "underline" and d.get("protect_sub", false) and sub.has_area():
			var r: Rect2 = rects[0]
			if vertical and sub.end.x <= area.position.x:
				r.position.x = (sub.end.x + area.position.x - thickness) * 0.5
			elif not vertical and sub.position.y >= area.end.y:
				r.position.y = (sub.position.y + area.end.y - thickness) * 0.5
			rects[0] = r
		if type in ["band", "tape"] and bool(d.get("full_span", false)):
			for i in rects.size():
				var r: Rect2 = rects[i]
				if vertical:
					r.position.y = 0.0
					r.size.y = layout["canvas"].y
				else:
					r.position.x = 0.0
					r.size.x = layout["canvas"].x
				rects[i] = r
		if type == "brackets":
			for i in rects.size():
				var r: Rect2 = rects[i]
				var old := maxf(r.size.x, r.size.y)
				var arm := minf(area.size.x, area.size.y) * float(d.get("arm_length", 0.3))
				if r.size.x > r.size.y:
					if i in [2, 6]: r.position.x += old - arm
					r.size.x = arm
				else:
					if i in [5, 7]: r.position.y += old - arm
					r.size.y = arm
				rects[i] = r
		var fill_rect := area.grow(float(d["margin"]) * fs)
		if type == "frame" and rects.size() == 4:
			fill_rect = Rect2(rects[0].position, Vector2(rects[0].size.x, rects[1].end.y - rects[0].position.y))
		if type == "box" and not rects.is_empty():
			fill_rect = rects[0]
		if animation == "shape":
			rects = Shapes.animate(rects, type, progress, leave, vertical, area)
			if type == "box" and not rects.is_empty(): fill_rect = rects[0]
		elif grow < 1.0:
			rects = _grow(rects, grow, animation == "grow_start")
		var blink := float(d.get("blink_period", 0.0))
		var phase := int(floor(maxf(0.0, time) / maxf(0.001, blink))) % 2
		out.append({"follow_block": bool(d.get("follow_block", false)), "type": type, "rects": rects, "color": Doc.parse_color(d["color"]),
			"outline": bool(d["use_outline"]) and bool(style["outline"]["enabled"]),
			"outline_color": Doc.parse_color(style["outline"]["color"]), "outline_size": float(style["outline"]["size"]),
			"outline2": bool(d["use_outline"]) and bool(style["outline2"]["enabled"]),
			"outline2_color": Doc.parse_color(style["outline2"]["color"]), "outline2_size": float(style["outline2"]["size"]),
			"alpha": alpha, "fill_rect": fill_rect, "fill_color": Doc.parse_color(d.get("fill_color", "#18243CCC")),
			"fill_opacity": float(d.get("fill_opacity", 0.0)) * (progress if animation == "shape" else 1.0),
			"radius": float(d.get("radius", 0.0)), "thickness": thickness,
			"softness": float(d.get("softness", 0.0)), "end_fade": float(d.get("end_fade", 0.0)),
			"stripe_width": float(d.get("stripe_width", 24.0)), "stripe_phase": time * float(d.get("stripe_speed", 40.0)),
			"blink_strength": float(d.get("blink_strength", 1.0)), "blink": blink > 0.0, "blink_phase": phase, "vertical": vertical})
	return out


static func _progress(time: float, duration: float) -> float:
	if time < 0.0: return 0.0
	return Easing.apply("cubic_out", 1.0 if duration <= 0.0 else clampf(time / duration, 0.0, 1.0))


static func geometry(type: String, r: Rect2, fs: float, th: float, margin: float, length: float, vertical: bool) -> Array:
	var c := r.get_center()
	match type:
		"box":
			return [r.grow(margin)]
		"bar":
			return [Rect2(r.position.x, r.position.y - margin - th, r.size.x * length, th)] if vertical else [Rect2(r.position.x - margin - th, r.position.y, th, r.size.y * length)]
		"lines", "tape":
			var width := maxf(th, fs * 0.2) if type == "tape" else th
			return geometry("underline", r, fs, width, margin, length, vertical) + geometry("overline", r, fs, width, margin, length, vertical)
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


static func _protect(frame: Rect2, main: Rect2, sub: Rect2, vertical: bool) -> Rect2:
	var lo := frame.position
	var hi := frame.end
	if vertical:
		if sub.end.x <= main.position.x:
			lo.x = maxf(lo.x, (main.position.x + sub.end.x) * 0.5)
		else:
			hi.x = minf(hi.x, (main.end.x + sub.position.x) * 0.5)
	else:
		if sub.position.y >= main.end.y:
			hi.y = minf(hi.y, (main.end.y + sub.position.y) * 0.5)
		else:
			lo.y = maxf(lo.y, (main.position.y + sub.end.y) * 0.5)
	return Rect2(lo, (hi - lo).max(Vector2.ZERO))
