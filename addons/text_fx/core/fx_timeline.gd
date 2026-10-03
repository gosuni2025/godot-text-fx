class_name TextFxTimeline
extends RefCounted
## 페이지·구간(등장/유지/퇴장)·글자별 지연·루프(DESIGN §2.1, §2.4).
## sample(t, finish_at)은 순수 함수다: 같은 문서·t·finish_at → 같은 결과.
##
## 샘플 Dictionary: { page, phase("enter"|"hold"|"exit"|"gap"|"end"), local(구간 경과 초),
##   page_time(페이지 시작 후 경과 초), loop_index, loop_base, done, final(마지막 퇴장 여부) }
## finish_at >= 0 이면 그 시각에 finish()가 호출된 것으로 본다. 현재 페이지의 등장이 끝난 뒤 바로 퇴장하고 끝난다.
## exit.enabled = false 이면 finish 시 즉시 끝난다.

const Hash := preload("res://addons/text_fx/core/fx_hash.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const Timing := preload("res://addons/text_fx/core/fx_timing_helpers.gd")

const SALT_RANDOM := 7001

var doc: Dictionary
var layout: Dictionary
var page_count := 1
## 페이지별 { start, enter_end, hold_end, exit_end, next_start, enter_len, exit_len, exit_performed, stamp_seq, stamp_count }
var pages: Array = []
var enter_delay := PackedFloat32Array()
var exit_delay := PackedFloat32Array()
var total := 0.0
var loop_mode := "once"
var exit_enabled := true
var scroll_speed := 0.0
var stamp_enabled := false
var lead_in := 0.0
var lead_out := 0.0
var content_end := 0.0


func _init(p_doc: Dictionary, p_layout: Dictionary) -> void:
	doc = p_doc
	layout = p_layout
	_build()


func get_duration() -> float:
	return total


func _build() -> void:
	var tl: Dictionary = doc["timeline"]
	var enter: Dictionary = tl["enter"]
	var exit: Dictionary = tl["exit"]
	var hold_len := maxf(0.0, float(tl["hold"]["duration"]))
	var gap := maxf(0.0, float(tl["page_gap"]))
	lead_in = maxf(0.0, float(tl.get("lead_in", 0.0)))
	lead_out = maxf(0.0, float(tl.get("lead_out", 0.0)))
	exit_enabled = bool(exit["enabled"])
	loop_mode = str(tl["loop"])
	stamp_enabled = enter["effect"] == "center_stamp"
	var glyphs: Array = layout["glyphs"]
	enter_delay.resize(glyphs.size())
	exit_delay.resize(glyphs.size())
	page_count = maxi(1, int(layout["page_count"]))
	var seed := int(doc["seed"])
	pages.clear()
	if tl.get("scroll") is Dictionary:
		scroll_speed = maxf(1.0, float(tl["scroll"]["speed"]))
		var rect: Rect2 = layout["pages"][0]["rect"] if layout["pages"].size() > 0 else Rect2()
		var vertical: bool = layout["direction"] == "vertical"
		var length := (float(layout["canvas"].x) + rect.size.x) if vertical else (float(layout["canvas"].y) + rect.size.y)
		var scroll_duration := length / scroll_speed
		content_end = lead_in + scroll_duration
		total = content_end + lead_out
		if loop_mode == "loop_hold":
			loop_mode = "loop_all"
		stamp_enabled = false
		pages.append({"start": lead_in, "enter_end": lead_in, "hold_end": content_end, "exit_end": content_end, "next_start": total,
			"enter_len": 0.0, "exit_len": 0.0, "text_exit_len": 0.0, "exit_performed": false,
			"text_start": 0.0, "stamp_seq": 0.0, "stamp_count": 0})
		return
	var t := lead_in
	var text_start := _decoration_lead()
	var independent_sub: bool = tl.get("sub_enter") is Dictionary
	var sub := Timing.sub_segment(doc)
	for p in page_count:
		var pg: Dictionary = layout["pages"][p] if p < layout["pages"].size() else {"glyph_first": 0, "glyph_count": 0}
		var first := int(pg["glyph_first"])
		var count := int(pg["glyph_count"])
		var enter_len := 0.0
		var stamp_seq := 0.0
		var stamp_count := 0
		var slots: Array = []
		var main_count := Timing.main_count(glyphs, first, count)
		var timed_main := main_count if independent_sub else count
		if stamp_enabled:
			var params: Dictionary = enter["params"]
			var seq := Timing.stamp_slots(glyphs, first, count, params)
			slots = seq["slots"]
			stamp_count = slots.size()
			stamp_seq = float(seq["duration"]) + text_start
			for i in range(first, first + timed_main):
				enter_delay[i] = stamp_seq
			enter_len = stamp_seq + maxf(0.0, float(enter["duration"])) if count > 0 else text_start
		else:
			enter_len = text_start + _assign_delays(enter_delay, glyphs, first, timed_main, enter, seed)
			_shift_delays(enter_delay, first, timed_main, text_start)
		var main_enter_len := enter_len
		var sub_start := 0.0
		if independent_sub and count > main_count:
			var same_block: bool = tl["sub_enter"].get("effect", "same") == "same" and enter["effect"] in Enter.BLOCK_EFFECTS
			sub_start = text_start if same_block else maxf(text_start, main_enter_len + float(tl["sub_enter"].get("delay", 0.0)))
			var sub_len := _assign_delays(enter_delay, glyphs, first + main_count, count - main_count, sub, seed)
			_shift_delays(enter_delay, first + main_count, count - main_count, sub_start)
			enter_len = maxf(enter_len, sub_start + sub_len)
		var text_exit_len := _assign_delays(exit_delay, glyphs, first, count, exit, seed + 1, true)
		var exit_len := maxf(text_exit_len, _decoration_exit())
		var last := p == page_count - 1
		var performed := ((not last) and bool(tl.get("exit_between_pages", true))) or exit_enabled
		var page := {
			"start": t, "enter_end": t + enter_len, "hold_end": t + enter_len + hold_len,
			"enter_len": enter_len, "main_enter_len": main_enter_len, "sub_enter_start": sub_start,
			"exit_len": exit_len, "text_exit_len": text_exit_len, "exit_performed": performed,
			"text_start": text_start, "stamp_seq": stamp_seq, "stamp_count": stamp_count, "stamp_slots": slots,
		}
		page["exit_end"] = float(page["hold_end"]) + (exit_len if performed else 0.0)
		page["next_start"] = float(page["exit_end"]) + (gap if not last else 0.0)
		pages.append(page)
		t = page["next_start"]
	content_end = t
	total = content_end + lead_out


func _decoration_lead() -> float:
	var lead := 0.0
	for deco in doc.get("decorations", []):
		if bool(deco.get("lead_text", false)):
			lead = maxf(lead, maxf(0.0, float(deco.get("delay", 0.0))) + maxf(0.0, float(deco.get("duration", 0.0))))
	return lead


func _decoration_exit() -> float:
	var length := 0.0
	for deco in doc.get("decorations", []):
		if float(deco.get("exit_duration", 0.0)) > 0.0:
			length = maxf(length, maxf(0.0, float(deco.get("exit_delay", 0.0))) + float(deco["exit_duration"]))
	return length


static func _shift_delays(out: PackedFloat32Array, first: int, count: int, delay: float) -> void:
	for i in range(first, first + count):
		out[i] += delay


## 페이지 안 글자 지연을 채우고 구간 길이(마지막 지연 + duration)를 돌려준다.
func _assign_delays(out: PackedFloat32Array, glyphs: Array, first: int, count: int, seg: Dictionary, seed: int, is_exit: bool = false) -> float:
	if count <= 0:
		return 0.0
	var dur := maxf(0.0, float(seg["duration"]))
	if seg["effect"] == "erase":
		dur = 0.0
	var params: Dictionary = seg.get("params", {})
	var extra := Timing.overlap_hold(seg, is_exit)
	if seg["effect"] in Enter.BLOCK_EFFECTS:
		for i in range(first, first + count):
			out[i] = 0.0
		return dur + extra
	var stagger := maxf(0.0, float(seg["stagger"]))
	if seg["order"] == "sweep":
		var delays := Timing.sweep_delays(glyphs, layout["lines"], first, count, params, layout["direction"] == "vertical")
		var last := 0.0
		for i in count:
			out[first + i] = delays[i]
			last = maxf(last, delays[i])
		return last + dur + extra
	var line_pause := maxf(0.0, float(params.get("line_pause", 0.0)))
	var ranks := compute_ranks(glyphs, first, count, str(seg["order"]), seed)
	var order: Array = []
	for i in count:
		order.append([ranks[i], i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var acc := 0.0
	var max_delay := 0.0
	var k := 0
	var previous_line := -1
	while k < order.size():
		var r: int = order[k][0]
		var first_line := int(glyphs[first + int(order[k][1])]["line"])
		if previous_line >= 0 and first_line != previous_line and seg["order"] in ["forward", "reverse", "line", "word"]:
			acc += line_pause
		var group_pause := 0.0
		var j := k
		while j < order.size() and int(order[j][0]) == r:
			var gi: int = first + int(order[j][1])
			out[gi] = float(r) * stagger + acc
			max_delay = maxf(max_delay, out[gi])
			group_pause = maxf(group_pause, Timing.punctuation_pause(glyphs[gi], params))
			j += 1
		acc += group_pause
		previous_line = first_line
		k = j
	return max_delay + dur + extra


## 순서별 rank(DESIGN §2.1). 페이지 안 count개 글자에 대해 0부터.
static func compute_ranks(glyphs: Array, first: int, count: int, order: String, seed: int) -> PackedInt32Array:
	var ranks := PackedInt32Array()
	ranks.resize(count)
	match order:
		"forward":
			for i in count:
				ranks[i] = i
		"reverse":
			for i in count:
				ranks[i] = count - 1 - i
		"line":
			for i in count:
				ranks[i] = int(glyphs[first + i]["line_in_page"])
		"word":
			for i in count:
				ranks[i] = int(glyphs[first + i]["word"])
		"center_out", "edges_in":
			ranks = _center_ranks(glyphs, first, count, order == "edges_in")
		"center_index", "edges_index":
			for i in count:
				var distance := mini(i, count - 1 - i)
				ranks[i] = (count - 1) / 2 - distance if order == "center_index" else distance
		"random":
			var perm := Hash.permutation(seed, count, SALT_RANDOM)
			for r in count:
				ranks[perm[r]] = r
		_:
			pass
	return ranks


static func _center_ranks(glyphs: Array, first: int, count: int, reverse: bool) -> PackedInt32Array:
	# 줄 중심과의 거리(px, 반올림)를 밀집 순위로 바꾼다. 줄마다 대칭인 글자는 같은 순위.
	var line_centers := {}
	var line_extent := {}
	for i in count:
		var g: Dictionary = glyphs[first + i]
		var ln: int = g["line"]
		var p: Vector2 = g["pos"]
		if not line_extent.has(ln):
			line_extent[ln] = [p, p]
		else:
			line_extent[ln] = [Vector2(minf(line_extent[ln][0].x, p.x), minf(line_extent[ln][0].y, p.y)),
				Vector2(maxf(line_extent[ln][1].x, p.x), maxf(line_extent[ln][1].y, p.y))]
	for ln in line_extent:
		line_centers[ln] = (line_extent[ln][0] + line_extent[ln][1]) * 0.5
	var dists := PackedInt32Array()
	dists.resize(count)
	var uniq := {}
	for i in count:
		var g: Dictionary = glyphs[first + i]
		var d := int(round((g["pos"] as Vector2).distance_to(line_centers[int(g["line"])])))
		dists[i] = d
		uniq[d] = true
	var keys: Array = uniq.keys()
	keys.sort()
	var rank_of := {}
	for r in keys.size():
		rank_of[keys[r]] = (keys.size() - 1 - r) if reverse else r
	var ranks := PackedInt32Array()
	ranks.resize(count)
	for i in count:
		ranks[i] = rank_of[dists[i]]
	return ranks


func sample(t: float, finish_at: float = -1.0) -> Dictionary:
	if finish_at >= 0.0 and t >= finish_at:
		return _sample_finished(t, finish_at)
	return _sample_open(t)


## 끝나는 시각(INF = 끝나지 않음). once에서 exit가 꺼져 있으면 total(유지 상태로 끝남).
func get_end_time(finish_at: float = -1.0) -> float:
	if finish_at >= 0.0:
		var fs := _sample_open(finish_at)
		if fs["phase"] == "end" or fs["phase"] == "gap" or not exit_enabled:
			return finish_at
		var base: float = fs["loop_base"]
		var p: int = fs["page"]
		if fs["phase"] == "exit":
			return base + float(pages[p]["exit_end"])
		return maxf(finish_at, base + float(pages[p]["enter_end"])) + float(pages[p]["exit_len"])
	if loop_mode == "once":
		return total
	return INF


func _make(page: int, phase: String, local: float, page_time: float, loop_index: int = 0, loop_base: float = 0.0) -> Dictionary:
	return {"page": page, "phase": phase, "local": local, "page_time": page_time, "loop_index": loop_index,
		"loop_base": loop_base, "done": phase == "end", "final": false}


func _end() -> Dictionary:
	return _make(page_count - 1, "end", 0.0, 0.0)


func _sample_open(t: float) -> Dictionary:
	t = maxf(0.0, t)
	var last := page_count - 1
	match loop_mode:
		"loop_all":
			if total <= 0.0:
				return _make(last, "hold", t, t)
			var li := int(floor(t / total))
			var s := _linear(t - float(li) * total)
			s["loop_index"] = li
			s["loop_base"] = float(li) * total
			return s
		"loop_hold":
			var h0: float = pages[last]["enter_end"]
			if t >= h0:
				return _make(last, "hold", t - h0, t - float(pages[last]["start"]))
			return _linear(t)
	if t >= total:
		if bool(pages[last]["exit_performed"]) or lead_out > 0.0 or scroll_speed > 0.0:
			return _end()
		var s := _make(last, "hold", t - float(pages[last]["enter_end"]), t - float(pages[last]["start"]))
		s["done"] = true
		return s
	return _linear(t)


func _linear(t: float) -> Dictionary:
	var last := page_count - 1
	if t < lead_in:
		return _make(0, "gap", t, t - lead_in)
	if t >= content_end and lead_out > 0.0:
		return _make(last, "gap", t - content_end, t - float(pages[last]["start"]))
	for p in page_count:
		var pg: Dictionary = pages[p]
		var st: float = pg["start"]
		if t < float(pg["enter_end"]):
			return _make(p, "enter", t - st, t - st)
		if t < float(pg["hold_end"]):
			return _make(p, "hold", t - float(pg["enter_end"]), t - st)
		if bool(pg["exit_performed"]) and t < float(pg["exit_end"]):
			var s := _make(p, "exit", t - float(pg["hold_end"]), t - st)
			s["final"] = p == last
			return s
		if p < last and t < float(pg["next_start"]):
			return _make(p, "gap", t - float(pg["exit_end"]), t - st)
	if bool(pages[last]["exit_performed"]):
		return _end()
	return _make(last, "hold", t - float(pages[last]["enter_end"]), t - float(pages[last]["start"]))


func _sample_finished(t: float, f: float) -> Dictionary:
	var fs := _sample_open(f)
	if fs["phase"] == "end" or fs["phase"] == "gap" or not exit_enabled:
		return _end()
	var base: float = fs["loop_base"]
	var p: int = fs["page"]
	var pg: Dictionary = pages[p]
	var ex_start: float
	if fs["phase"] == "exit":
		ex_start = base + float(pg["hold_end"])
	else:
		ex_start = maxf(f, base + float(pg["enter_end"]))
	if t < ex_start:
		var s := _sample_open(t)
		if s["phase"] == "enter" or s["phase"] == "hold":
			return s
		return _make(p, "hold", t - base - float(pg["enter_end"]), t - base - float(pg["start"]), fs["loop_index"], base)
	var local := t - ex_start
	if local >= float(pg["exit_len"]):
		return _end()
	var s2 := _make(p, "exit", local, t - base - float(pg["start"]), fs["loop_index"], base)
	s2["final"] = true
	return s2
