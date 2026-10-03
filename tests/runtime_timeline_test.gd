extends RefCounted
## TextFxTimeline: 구간 길이, 순서 rank, 루프 방식, 페이지, finish, 스크롤.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Timeline := preload("res://addons/text_fx/core/fx_timeline.gd")


func _make(patch: Dictionary) -> Timeline:
	var d := Doc.defaults()
	for k in patch:
		Doc.set_value(d, k, patch[k])
	d = Doc.normalize(d)
	return Timeline.new(d, Layout.compute(d))


func run(t) -> void:
	# 기본: 5글자(공백 제외 4) forward, stagger 0.1, dur 0.5, hold 1, exit all 0.3
	var tl := _make({"text": "AB CD", "timeline.enter.stagger": 0.1, "timeline.enter.duration": 0.5,
		"timeline.hold.duration": 1.0, "timeline.exit.duration": 0.3, "timeline.exit.order": "all"})
	t.near(tl.pages[0]["enter_len"], 0.3 + 0.5, 0.0001, "enter len = last delay + duration")
	t.near(tl.get_duration(), 0.8 + 1.0 + 0.3, 0.0001, "total duration")
	t.near(tl.enter_delay[2], 0.2, 0.0001, "space does not take rank")
	t.eq(tl.sample(0.1)["phase"], "enter", "enter phase")
	t.eq(tl.sample(1.0)["phase"], "hold", "hold phase")
	t.near(tl.sample(1.0)["local"], 0.2, 0.0001, "hold local")
	var ex := tl.sample(1.9)
	t.eq(ex["phase"], "exit", "exit phase")
	t.ok(ex["final"], "final exit flagged")
	t.eq(tl.sample(2.2)["phase"], "end", "end after total")
	t.ok(tl.sample(2.2)["done"], "done flag")
	t.eq(tl.get_end_time(), tl.get_duration(), "once end time")

	# 순서 rank
	tl = _make({"text": "ABCDE", "timeline.enter.order": "reverse", "timeline.enter.stagger": 0.1})
	t.near(tl.enter_delay[0], 0.4, 0.0001, "reverse first glyph last")
	tl = _make({"text": "ABCDE", "timeline.enter.order": "all", "timeline.enter.stagger": 0.1})
	t.near(tl.enter_delay[4], 0.0, 0.0001, "all simultaneous")
	tl = _make({"text": "AB\nCD", "timeline.enter.order": "line", "timeline.enter.stagger": 0.2})
	t.near(tl.enter_delay[1], 0.0, 0.0001, "line rank same line")
	t.near(tl.enter_delay[2], 0.2, 0.0001, "line rank second line")
	tl = _make({"text": "ab cd ef", "timeline.enter.order": "word", "timeline.enter.stagger": 0.1})
	t.near(tl.enter_delay[5], 0.2, 0.0001, "word rank")
	tl = _make({"text": "ABCDE", "timeline.enter.order": "center_out", "timeline.enter.stagger": 0.1, "font.family": "Galmuri11", "font.path": "res://assets/fonts/galmuri/Galmuri11.ttf"})
	t.ok(tl.enter_delay[2] < tl.enter_delay[0], "center_out: middle first")
	tl = _make({"text": "ABCDE", "timeline.enter.order": "edges_in", "timeline.enter.stagger": 0.1})
	t.ok(tl.enter_delay[0] < tl.enter_delay[2], "edges_in: edges first")
	var r1 := _make({"text": "ABCDEFGH", "timeline.enter.order": "random", "seed": 1})
	var r2 := _make({"text": "ABCDEFGH", "timeline.enter.order": "random", "seed": 2})
	var r1b := _make({"text": "ABCDEFGH", "timeline.enter.order": "random", "seed": 1})
	t.eq(Array(r1.enter_delay), Array(r1b.enter_delay), "random order deterministic")
	t.ne(Array(r1.enter_delay), Array(r2.enter_delay), "random order differs by seed")
	var sorted := Array(r1.enter_delay)
	sorted.sort()
	t.near(sorted[7], 7 * 0.06, 0.0001, "random is a permutation")
	# 구두점 쉼
	tl = _make({"text": "あ、いう", "font.path": "res://assets/fonts/galmuri/Galmuri11.ttf", "timeline.enter.stagger": 0.1,
		"timeline.enter.params": {"punct_pause": 0.5}})
	t.near(tl.enter_delay[2], 0.2 + 0.5, 0.0001, "punct pause after comma")
	t.near(tl.enter_delay[1], 0.1, 0.0001, "comma itself not delayed")

	# 페이지
	tl = _make({"mode": "trailer", "text": "AA\n\nBBB", "timeline.enter.stagger": 0.0, "timeline.enter.duration": 0.5,
		"timeline.hold.duration": 1.0, "timeline.exit.duration": 0.25, "timeline.page_gap": 0.5, "timeline.exit.enabled": false})
	t.eq(tl.page_count, 2, "two pages")
	t.ok(tl.pages[0]["exit_performed"], "non-last page always exits")
	t.ok(not tl.pages[1]["exit_performed"], "last page no exit when disabled")
	t.near(tl.pages[1]["start"], 0.5 + 1.0 + 0.25 + 0.5, 0.0001, "page 2 start after gap")
	t.near(tl.get_duration(), 2.25 + 1.5, 0.0001, "total with pages")
	t.eq(tl.sample(1.6)["phase"], "exit", "page 0 exit")
	t.ok(not tl.sample(1.6)["final"], "page exit not final")
	t.eq(tl.sample(2.0)["phase"], "gap", "gap")
	t.eq(tl.sample(2.3)["page"], 1, "page 1")
	var after := tl.sample(10.0)
	t.eq(after["phase"], "hold", "exit disabled ends in hold")
	t.ok(after["done"], "but done")
	t.near(after["local"], 10.0 - 2.75, 0.0001, "hold time keeps growing")

	# loop_all
	tl = _make({"text": "AB", "timeline.loop": "loop_all"})
	var total := tl.get_duration()
	var s := tl.sample(total * 2.0 + 0.05)
	t.eq(s["loop_index"], 2, "loop index")
	t.eq(s["phase"], "enter", "wrapped to enter")
	t.eq(tl.get_end_time(), INF, "loop_all infinite")
	# loop_hold
	tl = _make({"text": "AB", "timeline.loop": "loop_hold", "timeline.hold.duration": 1.0, "timeline.exit.duration": 0.4})
	var h0: float = tl.pages[0]["enter_end"]
	s = tl.sample(h0 + 100.0)
	t.eq(s["phase"], "hold", "loop_hold stays in hold")
	t.near(s["local"], 100.0, 0.0001, "unbounded hold time")
	t.eq(tl.get_end_time(), INF, "loop_hold infinite until finish")
	var f := h0 + 50.0
	t.eq(tl.sample(f + 0.1, f)["phase"], "exit", "finish -> exit")
	t.ok(tl.sample(f + 0.1, f)["final"], "finish exit final")
	t.eq(tl.sample(f + 0.5, f)["phase"], "end", "finish -> end")
	t.near(tl.get_end_time(f), f + 0.4, 0.0001, "end time after finish")
	# finish during enter waits for enter end
	s = tl.sample(h0 * 0.5 + 0.01, h0 * 0.5)
	t.eq(s["phase"], "enter", "finish during enter continues enter")
	t.eq(tl.sample(h0 + 0.1, h0 * 0.5)["phase"], "exit", "then exits")
	# finish with exit disabled ends immediately
	tl = _make({"text": "AB", "timeline.loop": "loop_hold", "timeline.exit.enabled": false})
	t.eq(tl.sample(5.0, 4.0)["phase"], "end", "finish without exit ends")

	# center_stamp
	tl = _make({"text": "ABC", "sub_text": "s", "timeline.enter.effect": "center_stamp", "timeline.enter.duration": 0.3,
		"timeline.enter.params": {"hold_each": 0.2, "pause": 0.4}})
	t.ok(tl.stamp_enabled, "stamp enabled")
	t.eq(tl.pages[0]["stamp_count"], 3, "stamp counts main glyphs")
	t.near(tl.pages[0]["enter_len"], 3 * 0.2 + 0.4 + 0.3, 0.0001, "stamp enter len")

	# scroll
	tl = _make({"mode": "trailer", "text": "A\n\nB", "timeline.scroll": {"speed": 100.0}})
	t.eq(tl.page_count, 1, "scroll ignores pages")
	t.ok(tl.get_duration() > 7.2, "scroll duration covers canvas height")
	t.eq(tl.sample(1.0)["phase"], "hold", "scroll is hold")
