extends RefCounted
## 포맷 2 장식의 형태별 등장/퇴장. 출력은 렌더러 독립적인 사각형 목록이다.

static func animate(rects: Array, type: String, enter: float, leave: float, vertical: bool, area: Rect2) -> Array:
	var out: Array = []
	var k := enter * (1.0 - leave)
	if type == "frame":
		return trace(rects, k, vertical)
	for i in rects.size():
		var r: Rect2 = rects[i]
		match type:
			"band":
				if vertical:
					r.position.x += r.size.x * (1.0 - k) * 0.5
					r.size.x *= k
				else:
					r.position.y += r.size.y * (1.0 - k) * 0.5
					r.size.y *= k
			"tape":
				var sign2 := -1.0 if i % 2 == 0 else 1.0
				if vertical:
					r.position.y += sign2 * r.size.y * ((1.0 - enter) - leave)
				else:
					r.position.x += sign2 * r.size.x * ((1.0 - enter) - leave)
			"box":
				if vertical:
					r.position.y += r.size.y * (1.0 - k) * 0.5
					r.size.y *= k
				else:
					r.position.x += r.size.x * (1.0 - k) * 0.5
					r.size.x *= k
			"brackets":
				var delta := (r.get_center() - area.get_center()) * (1.0 - k) * 0.3
				r.position += delta
				if r.size.x > r.size.y:
					r.size.x *= k
				else:
					r.size.y *= k
			_:
				var along_x := r.size.x >= r.size.y
				var start := type in ["underline", "overline", "bar"]
				if along_x:
					r.position.x += r.size.x * (leave if start else (1.0 - k) * 0.5)
					r.size.x *= k
				else:
					r.position.y += r.size.y * (leave if start else (1.0 - k) * 0.5)
					r.size.y *= k
		if r.size.x > 0.0 and r.size.y > 0.0:
			out.append(r)
	return out

static func trace(rects: Array, k: float, vertical: bool = false) -> Array:
	if rects.size() != 4:
		return rects
	# 상→우→하→좌, 끊기지 않는 한 붓 경로.
	var indices := [3, 1, 2, 0] if vertical else [0, 3, 1, 2]
	var ordered := [rects[indices[0]], rects[indices[1]], rects[indices[2]], rects[indices[3]]]
	var total := 0.0
	for r: Rect2 in ordered:
		total += maxf(r.size.x, r.size.y)
	var remaining := total * k
	var out: Array = []
	for i in ordered.size():
		var r: Rect2 = ordered[i]
		var length := maxf(r.size.x, r.size.y)
		var visible := minf(length, remaining)
		remaining -= visible
		if visible <= 0.0:
			continue
		if indices[i] in [0, 1]:
			if indices[i] == 1:
				r.position.x += length - visible
			r.size.x = visible
		else:
			if indices[i] == 2:
				r.position.y += length - visible
			r.size.y = visible
		out.append(r)
	return out
