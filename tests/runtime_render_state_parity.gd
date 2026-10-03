extends RefCounted
## 렌더 상태 복사·아틀라스 격리·베이크 캐시의 회귀. 실제 shader 결과는 visual/render_shader_parity.gd에서 검증한다.

const State := preload("res://addons/text_fx/core/fx_glyph_state.gd")
const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
const Layout := preload("res://addons/text_fx/core/fx_layout.gd")
const Plan := preload("res://addons/text_fx/render/fx_bake_plan.gd")
const SpriteBlur := preload("res://addons/text_fx/render/fx_sprite_blur.gd")


func run(t) -> void:
	var state := State.new()
	state.brightness = 0.7
	state.glow_multiplier = 0.4
	state.ghost = 12.0
	state.ghost_dir = Vector2.DOWN
	state.clip_enabled = true
	state.clip_rect = Rect2(20, 30, 200, 80)
	state.clip_invert = true
	state.clip_feather = 5.0
	state.slices_global = true
	state.slice_origin_y = 30.0
	state.slice_height = 40.0
	state.slices = PackedFloat32Array([7.0, -3.0])
	var copied: State = state.copy()
	t.eq(copied.to_dict(), state.to_dict(), "복사·리플레이가 블러/플래시/글로우/마스크/전역 조각 상태를 보존")
	copied.slices[0] = 99.0
	t.ne(copied.slices[0], state.slices[0], "전역 조각 상태를 독립적으로 복사")

	var atlas := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.RED)
	atlas.fill_rect(Rect2i(0, 0, 16, 16), Color.CYAN)
	var cell := SpriteBlur.padded_cell(atlas, Rect2i(0, 0, 16, 16), 12)
	t.eq(cell.get_size(), Vector2i(40, 40), "블러 양쪽에 투명 여백")
	t.eq(cell.get_pixel(20, 20), Color.CYAN, "선택 셀만 격리")
	t.eq(cell.get_pixel(30, 20), Color(0, 0, 0, 0), "인접 빨간 셀이 블러 여백으로 들어오지 않음")
	t.ok(cell.has_mipmaps(), "넓은 블러 표본용 mipmap 생성")

	var doc := Doc.defaults()
	doc["text"] = "한 줄\n두 줄"
	doc["style"]["fill"]["type"] = "gradient"
	doc["style"]["fill"]["gradient"]["space"] = "line"
	var ev := Evaluator.new(doc)
	var fonts := Layout.resolve_fonts(doc)
	var plan := Plan.build(ev, fonts, 1.0)
	t.ok(not plan["jobs"].is_empty(), "줄 단위 그라데이션 베이크 계획 생성")
	var before: String = plan["signature"]
	doc["timeline"]["exit"]["effect"] = "blur"
	doc["timeline"]["exit"]["params"] = {"radius": 0.4}
	var changed := Evaluator.new(doc)
	var next := Plan.build(changed, fonts, 1.0)
	t.ne(before, next["signature"], "퇴장만 블러로 바꿔도 격리 sprite를 새로 굽기")
	t.near(next["jobs"][0]["blur_em"], 0.4, 0.0001, "퇴장 블러 최대 반경을 셀 여백에 반영")
	doc["background"] = Doc.default_background()
	doc["background"]["type"] = "solid"
	var background := Evaluator.new(doc)
	t.eq(next["signature"], Plan.build(background, fonts, 1.0)["signature"], "배경만 바꾸면 글자 아틀라스를 다시 굽지 않음")

	var sub_doc := Doc.defaults()
	sub_doc["text"] = "본문"
	sub_doc["sub_text"] = "보조"
	sub_doc["timeline"]["enter"]["effect"] = "fade"
	sub_doc["timeline"]["exit"]["effect"] = "fade"
	sub_doc["timeline"]["sub_enter"] = Doc.default_sub_enter()
	sub_doc["timeline"]["sub_enter"]["effect"] = "blur"
	sub_doc["timeline"]["sub_enter"]["params"] = {"radius": 0.3}
	var sub_plan := Plan.build(Evaluator.new(sub_doc), Layout.resolve_fonts(sub_doc), 1.0)
	t.near(sub_plan["jobs"][1]["blur_em"], 0.3, 0.0001, "본문 fade와 독립 보조 blur도 격리 texture 준비")
	sub_doc["timeline"]["sub_enter"]["params"]["radius"] = 0.5
	var sub_changed := Plan.build(Evaluator.new(sub_doc), Layout.resolve_fonts(sub_doc), 1.0)
	t.ne(sub_plan["signature"], sub_changed["signature"], "보조 blur 반경 변경은 아틀라스 cache 갱신")
	t.ok(sub_changed["jobs"][1]["blur_px"] > sub_plan["jobs"][1]["blur_px"], "보조 blur 반경 확대에 필요한 여백 확대")
