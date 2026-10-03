extends RefCounted
## 실제 렌더 회귀·캡처에서 공유하는 포맷 3 연출 견본.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Enter := preload("res://addons/text_fx/core/fx_effects_enter.gd")
const IDS := ["fragment_assemble", "ink_bleed", "ember_dissolve", "dimensional_rift", "afterimage_overtake",
	"liquid_merge", "frost_crystal", "thread_stitch", "surface_pressure", "text_morph"]
const TITLES := ["파편 재조립", "잉크 침투", "재·불씨 소멸", "차원 균열", "잔상 추월",
	"액체 응집", "서리 결정", "실로 꿰매기", "표면 아래 압력", "문장 변이"]
const TEXTS := ["봉인 해제", "감춰진 기록", "등불이 꺼졌다", "경계의 너머", "시간의 틈",
	"깊은 바다", "서리목 등대", "등지기의 맹세", "문 너머의 존재", "등대는 깨어 있다"]


static func sample(id: String, vertical := false) -> Dictionary:
	var index := IDS.find(id)
	var d := Doc.defaults()
	d.name = TITLES[index]
	d.text = TEXTS[index]
	d.seed = 2718
	d.layout.font_size = 100
	d.layout.letter_spacing = 0.07
	d.style.fill.color = "#E8F3FFFF"
	d.style.outline.color = "#17283FFF"
	d.style.outline.size = 3.0
	d.style.shadow.enabled = false
	d.style.glow.enabled = true
	d.style.glow.color = "#599AFFFF"
	d.style.glow.size = 12.0
	d.style.glow.strength = 0.5
	d.timeline.enter.merge({"effect": id, "order": "all", "duration": 1.6, "stagger": 0.0,
		"easing": "linear", "params": Enter.default_params(id)}, true)
	d.timeline.hold.duration = 0.7
	d.timeline.exit.merge({"effect": id if id != "text_morph" else "ink_bleed", "order": "all",
		"duration": 1.3, "stagger": 0.0, "easing": "linear",
		"params": Enter.default_params(id if id != "text_morph" else "ink_bleed")}, true)
	if id == "text_morph":
		d.timeline.enter.params.from_text = "등대는 잠들었다"
		d.timeline.enter.duration = 2.4
	if id == "ember_dissolve":
		d.style.fill.color = "#FFE1B8FF"
		d.style.glow.color = "#FF7038FF"
	if vertical:
		d.text = "서리목\n등대"
		d.layout.direction = "vertical"
		d.layout.font_size = 78
		if id == "text_morph":
			d.timeline.enter.params.from_text = "잠든\n항구"
	return Doc.normalize(d)
