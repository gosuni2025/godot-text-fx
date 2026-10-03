extends VBoxContainer
## 왼쪽 미리보기: 캔버스 비율을 유지한 TextFxPlayer + 배경 전환 + 재생 바.
## 재생 시계는 EditorModel(time/playing)이다. 이 패널은 명령을 보내고(seek/play/pause/set) 모델 상태를 그리기만 한다.
## "끝내기"(loop_hold의 finish)와 배경은 미리보기 전용 상태라 문서를 바꾸지 않는다.

const LOOPS := ["once", "loop_all", "loop_hold"]

var ctx
var bg_mode := "checker"
var _image_tex: Texture2D = null
var _finish_at := -1.0
var _updating := false
var _icons: Dictionary = {}

@onready var player: Control = %Player
@onready var scrubber: HSlider = %Scrubber


func setup(p_ctx) -> void:
	ctx = p_ctx
	for n in ["play", "pause", "exit_on", "exit_off"]:
		_icons[n] = ctx.ui_icon(n)
	player.autoplay = false
	(%Time as Control).custom_minimum_size.x = ctx.scaled(Vector2(150, 0)).x
	%BgChecker.pressed.connect(set_bg_mode.bind("checker"))
	%BgColor.pressed.connect(set_bg_mode.bind("color"))
	%BgImage.pressed.connect(_on_bg_image)
	%BgPicker.color_changed.connect(func(c: Color): (%Solid as ColorRect).color = c)
	%ToStart.pressed.connect(to_start)
	%PlayPause.pressed.connect(toggle_play)
	%Finish.pressed.connect(finish)
	%Exit.pressed.connect(_on_exit)
	for id in LOOPS:
		get_node("%Loop_" + id).pressed.connect(_on_loop.bind(id))
	scrubber.value_changed.connect(_on_scrub)
	scrubber.drag_started.connect(_on_scrub_start)
	set_bg_mode("checker")


## 문서가 바뀌면 플레이어를 다시 구성하고 현재 시각으로 맞춘다.
func set_document(doc: Dictionary) -> void:
	player.set_document(doc)
	_finish_at = -1.0
	var w := float(doc.canvas.width)
	var h := float(doc.canvas.height)
	(%Aspect as AspectRatioContainer).ratio = w / maxf(1.0, h)
	(%CanvasSize as Label).text = "%d × %d" % [int(w), int(h)]
	player.seek(ctx.model.time)
	refresh_transport()


func show_time() -> void:
	player.seek(ctx.model.time)
	refresh_transport()


## 한 번 재생(once)이 끝까지 갔는지. 반복 모드는 끝나지 않는다.
func is_ended() -> bool:
	var end := end_time()
	return is_finite(end) and ctx.model.time >= end


func end_time() -> float:
	var ev = player.get_evaluator()
	return ev.get_end_time(_finish_at) if ev else 0.0


func scrub_length() -> float:
	var end := end_time()
	if is_finite(end):
		return maxf(end, 0.01)
	return maxf(player.get_duration(), 0.01)


func refresh_transport() -> void:
	if ctx == null:
		return
	var m = ctx.model
	_updating = true
	var length := scrub_length()
	scrubber.max_value = length
	var t: float = m.time
	var loop := str(m.get_value("timeline.loop"))
	var ev = player.get_evaluator()
	# 스크롤 문서는 loop_hold도 실제로는 전체 반복으로 평가한다.
	var repeats_all: bool = ev != null and ev.timeline.loop_mode == "loop_all" and _finish_at < 0.0
	var shown := fmod(t, length) if repeats_all else minf(t, length)
	scrubber.set_value_no_signal(shown)
	_updating = false
	if not is_finite(end_time()) and not repeats_all:
		(%Time as Label).text = "%.2f / ∞ s" % t
	else:
		(%Time as Label).text = "%.2f / %.2f s" % [shown, length]
	var pp := %PlayPause as Button
	pp.icon = _icons.pause if m.playing else _icons.play
	pp.tooltip_text = "Pause (Space)" if m.playing else "Play (Space)"
	for id in LOOPS:
		(get_node("%Loop_" + id) as Button).set_pressed_no_signal(loop == id)
	var exit_on: bool = m.get_value("timeline.exit.enabled") == true
	var ex := %Exit as Button
	ex.set_pressed_no_signal(exit_on)
	ex.icon = _icons.exit_on if exit_on else _icons.exit_off
	ex.tooltip_text = "Exit: on" if exit_on else "Exit: off"
	(%Finish as Button).visible = loop == "loop_hold"


# --- 재생 조작(명령) -----------------------------------------------------

func to_start() -> void:
	_clear_finish()
	ctx.send({"op": "seek", "t": 0.0})


func toggle_play() -> void:
	if ctx.model.playing:
		ctx.send({"op": "pause"})
	elif is_ended():
		_clear_finish()
		ctx.send({"op": "play", "from": 0.0})
	else:
		ctx.send({"op": "play"})


## loop_hold 미리보기를 퇴장으로 넘긴다(플레이어 finish와 같음, 문서 불변).
func finish() -> void:
	if _finish_at >= 0.0:
		return
	_finish_at = ctx.model.time
	player.finish()
	if not ctx.model.playing:
		ctx.send({"op": "play"})
	refresh_transport()


func _clear_finish() -> void:
	if _finish_at >= 0.0:
		_finish_at = -1.0
		player.stop()


func _on_scrub_start() -> void:
	if ctx.model.playing:
		ctx.send({"op": "pause"})


func _on_scrub(v: float) -> void:
	if _updating:
		return
	if v < _finish_at:
		_clear_finish()
	ctx.send({"op": "seek", "t": snappedf(v, 0.001)})


func _on_loop(id: String) -> void:
	ctx.send({"op": "set", "path": "timeline.loop", "value": id})
	refresh_transport()


func _on_exit() -> void:
	ctx.send({"op": "set", "path": "timeline.exit.enabled", "value": not (ctx.model.get_value("timeline.exit.enabled") == true)})
	refresh_transport()


# --- 배경(미리보기 전용) --------------------------------------------------

func set_bg_mode(mode: String) -> void:
	if mode == "image" and _image_tex == null:
		mode = bg_mode
	bg_mode = mode
	(%Checker as Control).visible = mode == "checker"
	(%Solid as Control).visible = mode == "color"
	(%Image as Control).visible = mode == "image"
	(%BgPicker as Control).visible = mode == "color"
	for pair in [["checker", %BgChecker], ["color", %BgColor], ["image", %BgImage]]:
		(pair[1] as Button).set_pressed_no_signal(pair[0] == mode)


func set_bg_image(tex: Texture2D) -> void:
	_image_tex = tex
	(%Image as TextureRect).texture = tex
	set_bg_mode("image" if tex else bg_mode)


## 이미지가 있으면 이미지 배경으로 바꾸고, 이미 이미지 배경이거나 이미지가 없으면 파일을 고른다.
func _on_bg_image() -> void:
	if _image_tex != null and bg_mode != "image":
		set_bg_mode("image")
		return
	set_bg_mode(bg_mode)  # 파일을 고르기 전까지 기존 배경 유지
	ctx.request_bg_image()
