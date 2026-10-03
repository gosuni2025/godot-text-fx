extends Control
## 렌더 확인용 미리보기. 체커보드 위에서 견본 문서를 TextFxPlayer로 재생한다.
## 캡처 모드(창 모드로 실행, 헤드리스 불가):
##   godot --path . res://tests/visual/player_preview.tscn -- --capture=/tmp/out [--sample=fade_outline,gradient|all]
## 견본마다 지정한 시각으로 seek해 PNG(<sample>_<t>.png)를 저장하고 자동 종료한다.
## 인자 없이 실행하면 견본을 차례로 반복 재생한다(←/→ 물리 키로 견본 전환).

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const Player := preload("res://addons/text_fx/render/text_fx_player.gd")
const GALMURI := "res://assets/fonts/galmuri/Galmuri11.ttf"

@onready var player: Player = $Player

var _names: PackedStringArray = ["fade_outline", "gradient", "glow_shadow", "vertical_ja", "glitch", "center_stamp", "decorations"]
var _index := 0


func _ready() -> void:
	var capture := ""
	var only := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			capture = a.substr(10)
		elif a.begins_with("--sample="):
			only = a.substr(9)
	if capture != "":
		_capture(capture, only)
	else:
		player.autoplay = true
		player.finished.connect(_next.bind(1))
		_show(0)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.physical_keycode == KEY_RIGHT:
			_next(1)
		elif k.physical_keycode == KEY_LEFT:
			_next(-1)


func _next(step: int) -> void:
	_show(posmod(_index + step, _names.size()))


func _show(i: int) -> void:
	_index = i
	var d := sample(_names[i])
	if d["timeline"]["loop"] == "loop_hold":
		d["timeline"]["loop"] = "once"
	player.set_document(d)
	player.play()


func _capture(dir: String, only: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var names := _names if only == "all" else PackedStringArray(only.split(","))
	for n in names:
		player.autoplay = false
		player.set_document(sample(n))
		player.play()
		player.paused = true
		for _i in 600:
			if player.is_baked():
				break
			await get_tree().process_frame
		for t: float in capture_times(n):
			player.seek(t)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var path := "%s/%s_%.2f.png" % [dir, n, t]
			img.save_png(path)
			print("captured ", path)
	get_tree().quit()


func capture_times(n: String) -> Array:
	match n:
		"fade_outline":
			return [0.12, 0.25, 1.2, 2.15]
		"glitch":
			return [1.05, 1.15, 1.25]
		"center_stamp":
			return [0.15, 0.45, 1.32, 1.5, 2.2]
		"vertical_ja":
			return [0.3, 2.0]
		"decorations":
			return [0.25, 1.5]
	return [0.3, 1.5]


static func sample(n: String) -> Dictionary:
	var d := Doc.defaults()
	d["text"] = "교전 개시"
	d["seed"] = 7
	var st: Dictionary = d["style"]
	match n:
		"fade_outline":
			d["text"] = "결전의 시각"
			d["sub_text"] = "FINAL HOUR"
			st["outline"] = {"enabled": true, "size": 14.0, "color": "#7A0E14FF"}
			st["shadow"]["enabled"] = false
			d["timeline"]["enter"].merge({"effect": "fade", "order": "all", "duration": 0.5, "easing": "linear"}, true)
			d["timeline"]["hold"]["duration"] = 1.0
			d["timeline"]["exit"].merge({"effect": "fade", "duration": 0.6, "easing": "linear"}, true)
		"gradient":
			d["text"] = "黄昏의 성채 Gradient"
			d["font"] = {"source": "bundled", "family": "Pretendard", "path": "", "weight": 800, "italic": false}
			st["fill"] = {"type": "gradient", "color": "#FFFFFFFF",
				"gradient": {"angle": 90.0, "space": "block", "stops": [[0.0, "#FFF6C8FF"], [0.5, "#FFB13BFF"], [1.0, "#D2301EFF"]]}}
			st["outline"] = {"enabled": true, "size": 5.0, "color": "#2A0E06FF"}
			st["outline2"] = {"enabled": true, "size": 4.0, "color": "#FFF2D0FF"}
			d["timeline"]["enter"]["effect"] = "slide"
		"glow_shadow":
			d["text"] = "Arcane Gate"
			d["sub_text"] = "봉인 해제"
			d["font"] = {"source": "bundled", "family": "Cinzel", "path": "", "weight": 700, "italic": false}
			st["glow"] = {"enabled": true, "size": 18.0, "color": "#5CD6FFFF", "strength": 1.4}
			st["shadow"] = {"enabled": true, "offset": [8.0, 10.0], "blur": 6.0, "color": "#000000B0"}
			st["outline"] = {"enabled": true, "size": 3.0, "color": "#06202CFF"}
			d["timeline"]["enter"]["effect"] = "zoom"
		"vertical_ja":
			d["text"] = "ラーメン「深夜」、\n終電のあとで。"
			d["font"] = {"source": "bundled", "family": "Galmuri11", "path": GALMURI, "weight": 400, "italic": false}
			d["layout"]["direction"] = "vertical"
			d["layout"]["font_size"] = 72
			d["timeline"]["enter"]["effect"] = "drop"
			d["timeline"]["enter"]["easing"] = "bounce_out"
		"glitch":
			d["text"] = "SIGNAL LOST"
			d["sub_text"] = "통신 두절"
			st["fill"]["color"] = "#E8FFF4FF"
			d["timeline"]["enter"]["effect"] = "glitch"
			d["timeline"]["enter"]["easing"] = "linear"
			d["timeline"]["loop"] = "loop_hold"
			d["timeline"]["hold"]["effects"] = [{"type": "glitch", "interval": 0.4, "duration": 0.4, "intensity": 1.4, "slices": 5,
				"color_a": "#FF2A6DFF", "color_b": "#2AE0FFFF"}]
		"center_stamp":
			d["text"] = "승부다"
			d["sub_text"] = "ROUND 1"
			st["outline"] = {"enabled": true, "size": 8.0, "color": "#14080AFF"}
			st["fill"]["color"] = "#FFE14DFF"
			d["timeline"]["enter"].merge({"effect": "center_stamp", "duration": 0.25, "easing": "cubic_in",
				"params": {"big_scale": 3.0, "hold_each": 0.3, "pause": 0.3, "slam_scale": 2.4}}, true)
		"decorations":
			d["text"] = "제3장 잿빛 항구"
			d["sub_text"] = "새벽 4시 12분"
			d["mode"] = "caption"
			d["decorations"] = [
				{"type": "band", "color": "#101828B0", "thickness": 4.0, "margin": 0.35, "length": 1.4, "use_outline": false, "animate": "grow_center", "delay": 0.0, "duration": 0.4},
				{"type": "underline", "color": "#E8C66AFF", "thickness": 4.0, "margin": 0.15, "length": 1.1, "use_outline": true, "animate": "grow_start", "delay": 0.1, "duration": 0.5},
				{"type": "brackets", "color": "#E8C66AFF", "thickness": 3.0, "margin": 0.6, "length": 1.2, "use_outline": false, "animate": "fade", "delay": 0.2, "duration": 0.4},
			]
	return Doc.normalize(d)
