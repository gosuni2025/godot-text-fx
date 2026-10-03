extends RefCounted
## 작은 카드도 실제 Player를 쓰되 숨겨진 상태에서 베이크하지 않는다.

const Card := preload("res://app/editor/popups/picker_card.tscn")
const Player := preload("res://addons/text_fx/render/text_fx_player.gd")


func run(t) -> void:
	var host := Control.new()
	host.size = Vector2(300, 180)
	host.hide()
	t.tree.root.add_child(host)
	var card := Card.instantiate()
	card.size = host.size
	host.add_child(card)
	card.set_preview("hold", "glow_pulse", "Aa")
	await t.tree.process_frame
	var preview: Control = card.get_node("%Preview")
	t.ok(preview.get("_player") == null, "hidden card does not create a renderer")
	host.show()
	await t.tree.process_frame
	await t.tree.process_frame
	var player: Player = preview.get("_player")
	t.ok(player != null, "visible card creates real TextFxPlayer")
	if player != null:
		t.ok(player.get_document()["style"]["glow"]["enabled"], "glow pulse preview enables the glow layer")
		t.ok(not player.is_playing(), "card is driven by seek")
		var paused := player.get_time()
		preview.call("_process", 0.12)
		t.near(player.get_time(), paused, 0.0001, "inactive card freezes its representative frame")
		preview.set("active", true)
		preview.call("_process", 0.12)
		t.ok(player.get_time() > 0.0, "active card advances")
	host.hide()
	await t.tree.process_frame
	t.ok(not preview.is_processing(), "hidden card stops processing")
	host.queue_free()
	await t.tree.process_frame
