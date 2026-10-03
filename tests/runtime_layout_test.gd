extends RefCounted
## TextFxLayout: 줄바꿈, 금칙, 세로쓰기, 자동 축소, 페이지·보조 문구.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const GALMURI := "res://assets/fonts/galmuri/Galmuri11.ttf"


func _doc(patch: Dictionary) -> Dictionary:
	var d := Doc.defaults()
	d["layout"]["auto_shrink"] = false
	for k in patch:
		Doc.set_value(d, k, patch[k])
	return Doc.normalize(d)


func _lines_text(res: Dictionary, role: String = "main") -> PackedStringArray:
	var out := PackedStringArray()
	for l in res["lines"]:
		if l["role"] != role:
			continue
		var s := ""
		for i in range(int(l["first"]), int(l["first"]) + int(l["count"])):
			s += res["glyphs"][i]["char"]
		out.append(s)
	return out


func run(t) -> void:
	# 단일 줄, 공백은 글자가 아님
	var r := Layout.compute(_doc({"text": "Hello world"}))
	t.eq(r["glyphs"].size(), 10, "spaces excluded")
	t.eq(r["lines"].size(), 1, "single line")
	t.eq(r["page_count"], 1, "one page")
	var block: Rect2 = r["pages"][0]["rect"]
	t.near(block.get_center(), Vector2(640, 360), 1.0, "centered block")
	t.ok(r["glyphs"][0]["pos"].x < r["glyphs"][9]["pos"].x, "left to right")
	t.eq(r["glyphs"][5]["word"], 1, "second word index")

	# 단어 단위 줄바꿈(한글 keep-all)
	r = Layout.compute(_doc({"text": "가나다라 마바사아 자차카타 파하가나", "layout.max_width": 0.4}))
	var lines := _lines_text(r)
	t.ok(lines.size() >= 2, "korean wraps: %s" % str(lines))
	for l in lines:
		t.eq(l.length() % 4, 0, "korean words not split: " + l)
	var maxw := 0.4 * 1280.0
	for l in r["lines"]:
		t.ok((l["rect"] as Rect2).size.x <= maxw + 0.5, "line within max width")

	# char 모드는 단어를 쪼갬
	r = Layout.compute(_doc({"text": "abcdefghijklmnopqrstuvwxyz", "layout.max_width": 0.3, "layout.wrap": "char"}))
	t.ok(_lines_text(r).size() >= 2, "char wrap splits long word")
	# none 모드는 줄바꿈 없음
	r = Layout.compute(_doc({"text": "abcdefghijklmnopqrstuvwxyz abcdefghijkl", "layout.max_width": 0.3, "layout.wrap": "none"}))
	t.eq(_lines_text(r).size(), 1, "wrap none keeps one line")
	# word 모드에서 너무 긴 단어는 글자 단위로 잘림
	r = Layout.compute(_doc({"text": "supercalifragilisticexpialidocious", "layout.max_width": 0.3, "layout.wrap": "word"}))
	t.ok(_lines_text(r).size() >= 2, "overlong word force-split")
	# 명시적 줄바꿈
	r = Layout.compute(_doc({"text": "A\nB\nC"}))
	t.eq(_lines_text(r), PackedStringArray(["A", "B", "C"]), "explicit newlines")

	# 금칙: 줄머리에 。、」 가 오지 않고 줄끝에 「 가 오지 않음
	var ja := "これは「テスト」です。とても長い文章、改行の確認。「括弧」の位置を見る。"
	for width in [0.18, 0.22, 0.26, 0.3, 0.34]:
		r = Layout.compute(_doc({"text": ja, "font.family": "Galmuri11", "font.path": GALMURI, "layout.max_width": width, "layout.font_size": 48}))
		lines = _lines_text(r)
		t.ok(lines.size() >= 2, "japanese wraps at %s" % str(width))
		for l in lines:
			t.ok(not "。、」）".contains(l.left(1)), "kinsoku line start (%s): %s" % [str(width), l])
			t.ok(not "「（".contains(l.right(1)), "kinsoku line end (%s): %s" % [str(width), l])
	# 금칙 끄면 줄머리 구두점 허용(적어도 결과가 달라질 수 있음) — 오류 없이 동작
	r = Layout.compute(_doc({"text": ja, "font.path": GALMURI, "font.family": "Galmuri11", "layout.max_width": 0.2, "layout.kinsoku": false}))
	t.ok(r["glyphs"].size() == ja.length(), "kinsoku off keeps all glyphs")

	# 세로쓰기: 열은 오른쪽→왼쪽, 장음·괄호·라틴은 회전
	r = Layout.compute(_doc({"text": "ラーメン「AB」\n二列目", "font.family": "Galmuri11", "font.path": GALMURI, "layout.direction": "vertical", "layout.font_size": 48}))
	var g: Array = r["glyphs"]
	t.eq(r["lines"].size(), 2, "two columns")
	var col0: Rect2 = r["lines"][0]["rect"]
	var col1: Rect2 = r["lines"][1]["rect"]
	t.ok(col0.position.x > col1.position.x, "first column on the right")
	t.ok(g[0]["pos"].y < g[1]["pos"].y, "top to bottom")
	t.ok(g[1]["vertical_rotate"], "long vowel rotated")
	t.near(g[1]["base_rotation"], PI * 0.5, 0.0001, "rotation 90deg")
	t.ok(not g[0]["vertical_rotate"], "kana upright")
	t.ok(g[4]["vertical_rotate"] and g[5]["vertical_rotate"], "bracket and latin rotated")
	# 세로 구두점 보정(오른쪽 위)
	r = Layout.compute(_doc({"text": "あ。", "font.path": GALMURI, "font.family": "Galmuri11", "layout.direction": "vertical", "layout.font_size": 48}))
	var a: Vector2 = r["glyphs"][0]["pos"]
	var dot: Vector2 = r["glyphs"][1]["pos"]
	t.ok(dot.x > a.x + 10.0, "vertical punct shifted right")
	# 세로 줄바꿈(높이 제한)
	r = Layout.compute(_doc({"text": "縦書きの長い文章を折り返して確認する", "font.path": GALMURI, "font.family": "Galmuri11",
		"layout.direction": "vertical", "layout.font_size": 64, "layout.max_height": 0.4}))
	t.ok(r["lines"].size() >= 2, "vertical wraps by height")
	for l in r["lines"]:
		t.ok((l["rect"] as Rect2).size.y <= 0.4 * 720.0 + 0.5, "column within max height")

	# 자동 축소
	var big := _doc({"text": "아주 긴 문장이 화면을 넘어가도록 계속 이어지는 테스트 문장입니다 정말 길어요 끝까지", "layout.font_size": 140, "layout.auto_shrink": true,
		"layout.min_font_size": 20, "layout.max_height": 0.3})
	r = Layout.compute(big)
	t.ok(int(r["font_size"]) < 140, "auto shrink reduced font: %d" % int(r["font_size"]))
	t.ok(int(r["font_size"]) >= 20, "not below min")
	t.ok((r["pages"][0]["rect"] as Rect2).size.y <= 0.3 * 720.0 + 1.0, "fits max height after shrink")
	t.ok(float(r["shrink"]) < 1.0, "shrink ratio reported")
	big["layout"]["auto_shrink"] = false
	r = Layout.compute(big)
	t.eq(int(r["font_size"]), 140, "no shrink when disabled")
	# 최소 크기에서 멈춤
	r = Layout.compute(_doc({"text": "가".repeat(400), "layout.auto_shrink": true, "layout.min_font_size": 40}))
	t.eq(int(r["font_size"]), 40, "stops at min font size")

	# 페이지(trailer) + 보조 문구
	r = Layout.compute(_doc({"mode": "trailer", "text": "첫 페이지\n\n둘째 페이지\n\n\n셋째", "sub_text": "sub1\n\nsub2"}))
	t.eq(r["page_count"], 3, "three pages")
	t.eq(r["glyphs"][0]["page"], 0, "page index")
	var roles := {}
	for gg in r["glyphs"]:
		roles["%d:%s" % [gg["page"], gg["role"]]] = true
	t.ok(roles.has("0:sub") and roles.has("1:sub") and not roles.has("2:sub"), "sub pages paired: %s" % str(roles.keys()))
	var p0: Dictionary = r["pages"][0]
	t.ok((p0["sub_rect"] as Rect2).position.y > (p0["main_rect"] as Rect2).position.y, "sub below main")
	r = Layout.compute(_doc({"text": "본문", "sub_text": "보조", "layout.sub.position": "above"}))
	p0 = r["pages"][0]
	t.ok((p0["sub_rect"] as Rect2).position.y < (p0["main_rect"] as Rect2).position.y, "sub above main")
	t.eq(r["sub_font_size"], 40, "sub font size")
	# message 모드에서는 빈 줄이 페이지가 아님
	r = Layout.compute(_doc({"text": "a\n\nb"}))
	t.eq(r["page_count"], 1, "message mode single page")
	# 정렬
	r = Layout.compute(_doc({"text": "x", "layout.align": "left", "layout.anchor": [0.1, 0.5]}))
	t.near((r["pages"][0]["rect"] as Rect2).position.x, 128.0, 0.5, "left align at anchor")
	# 빈 텍스트
	r = Layout.compute(_doc({"text": ""}))
	t.eq(r["glyphs"].size(), 0, "empty text no glyphs")
	t.eq(r["page_count"], 1, "empty text one page")
