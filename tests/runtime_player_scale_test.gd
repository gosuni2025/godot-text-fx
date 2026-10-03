extends RefCounted
## TextFxPlayer 굽기 배율·필터 회귀 검사(헤드리스).
## - 확대해서 그리면 흐려지므로 한 단계라도 커지면 다시 굽고, 축소는 REBAKE_RATIO를 넘을 때만 다시 굽는다.
## - 게임의 기본 텍스처 필터가 nearest여도 구운 글자는 선형 필터로 그린다.

const Player := preload("res://addons/text_fx/render/text_fx_player.gd")


func run(t) -> void:
	t.ok(Player.needs_rebake(0.0, 0.7), "아직 굽지 않음 → 굽기")
	t.ok(not Player.needs_rebake(0.7, 0.7), "같은 배율 → 유지")
	t.ok(Player.needs_rebake(0.55, 0.6), "0.55로 구운 것을 0.6으로 확대 → 다시 굽기")
	t.ok(Player.needs_rebake(0.75, 0.85), "확대 13% → 다시 굽기")
	t.ok(not Player.needs_rebake(0.7, 0.65), "축소 7% → 유지")
	t.ok(Player.needs_rebake(1.0, 0.7), "축소 30% → 다시 굽기")
	var p: Player = Player.new()
	t.eq(p.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "플레이어 텍스처 필터는 선형 고정")
	p.free()
