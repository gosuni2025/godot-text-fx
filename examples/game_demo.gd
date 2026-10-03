extends Control
## 게임 쪽 사용 예시. addons/text_fx 런타임과 examples/fx/*.json 만 사용한다(app/ 비의존).
##   godot --path . res://examples/game_demo.tscn
## 키보드(물리 키): 1~5 연출 재생, F 닫기(finish). 방향키 좌우 선택, Enter 재생, Esc 닫기.
## 게임패드: 십자키·왼쪽 스틱 좌우 선택(기본 ui_left/ui_right 액션), A 재생, B 닫기.
## Godot 4.7 기본 ui_accept/ui_cancel에는 패드 버튼이 없어 A/B는 직접 받는다. 실제 게임은 입력 맵에 액션을 두면 된다.

const FX_DIR := "res://examples/fx/"
const LOG_LINES := 5
const SLOT_ON := Color(1.0, 0.86, 0.45)
const SLOT_OFF := Color(0.62, 0.66, 0.74)

## 장소 자막 예시: set_text(장소, 시간)로 같은 연출에 다른 문장을 넣는다.
const PLACES := [
	["서리목 등대", "첫 종, 밀물"],
	["소금시장 거리", "아홉째 종, 밤시장"],
	["가라앉은 기록관", "다섯째 종, 썰물"],
]

@onready var banner: TextFxPlayer = $Banner
@onready var damage: TextFxPlayer = $Damage
@onready var hero: Control = $Hero
@onready var ground: Control = $Ground
@onready var slots: Array[Label] = [$Hud/Slots/Slot1, $Hud/Slots/Slot2, $Hud/Slots/Slot3, $Hud/Slots/Slot4, $Hud/Slots/Slot5]
@onready var status_label: Label = $Hud/Status
@onready var log_label: Label = $Hud/Log

var _selected := 0
var _clock := 0.0
var _count := 0          # 재생 횟수: 주사위·피해 숫자·장소를 결정적으로 바꾸는 데 쓴다
var _current := ""
var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	banner.autoplay = false
	damage.autoplay = false
	damage.load_file(FX_DIR + "damage_number.json")
	_connect_log(banner, "배너")
	_connect_log(damage, "피해")
	_select(0)
	_log("준비: 1~5 또는 패드 좌우 + A")


func _connect_log(p: TextFxPlayer, who: String) -> void:
	p.started.connect(func() -> void: _log("%s started" % who))
	p.entered.connect(func() -> void: _log("%s entered (등장 완료)" % who))
	p.page_changed.connect(func(page: int) -> void:
		if page > 0:
			_log("%s page_changed %d" % [who, page]))
	p.exit_started.connect(func() -> void: _log("%s exit_started" % who))
	p.finished.connect(func() -> void: _log("%s finished" % who))
	p.looped.connect(func() -> void: _log("%s looped" % who))


func _process(delta: float) -> void:
	_clock += delta
	# 자리표시 캐릭터: 바닥 위를 좌우로 오가며 살짝 튄다.
	var floor_y := ground.position.y
	var x := size.x * 0.5 + sin(_clock * 0.7) * size.x * 0.3 - hero.size.x * 0.5
	var bob := absf(sin(_clock * 6.0)) * 10.0
	hero.position = Vector2(x, floor_y - hero.size.y - bob)
	# 피해 숫자는 캐릭터 머리 위를 따라간다.
	damage.position = Vector2(x + hero.size.x * 0.5 - damage.size.x * 0.5, floor_y - hero.size.y - damage.size.y)
	var state := "대기"
	if banner.is_playing():
		state = "%s  %.2f / %.2f초" % [_current, banner.get_time(), banner.get_duration()]
		if banner.get_document()["timeline"]["loop"] == "loop_hold":
			state += "  (유지 반복 중 — F / B 버튼으로 닫기)"
	status_label.text = state


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_select(k.physical_keycode - KEY_1)
				_play_selected()
				accept_event()
				return
			KEY_F:
				_finish()
				accept_event()
				return
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed and pad.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
		if pad.button_index == JOY_BUTTON_A:
			_play_selected()
		else:
			_finish()
	elif event.is_action_pressed("ui_left"):
		_select(_selected - 1)
	elif event.is_action_pressed("ui_right"):
		_select(_selected + 1)
	elif event.is_action_pressed("ui_accept"):
		_play_selected()
	elif event.is_action_pressed("ui_cancel"):
		_finish()
	else:
		return
	accept_event()


func _select(i: int) -> void:
	_selected = posmod(i, slots.size())
	for n in slots.size():
		slots[n].modulate = SLOT_ON if n == _selected else SLOT_OFF


func _play_selected() -> void:
	_count += 1
	match _selected:
		0:
			_play_banner("battle_cutin.json", "전투 컷인")
		1:
			# loop_hold: 결과를 띄워 둔 채 반복하다가 finish()로 닫는다.
			var roll := 12 + (_count * 5) % 9
			_play_banner("check_result.json", "판정 결과", "등화 신호 일치", "주사위 %d / 목표 12" % roll)
		2:
			_play_banner("trailer_intro.json", "트레일러")
		3:
			var place: Array = PLACES[_count % PLACES.size()]
			_play_banner("location_caption.json", "장소 자막", place[0], place[1])
		4:
			var amount := 40 + (_count * 37) % 160
			damage.set_text(str(amount))
			damage.play()
			_log("피해 숫자 set_text(\"%d\")" % amount)


func _play_banner(file: String, title: String, text := "", sub := "") -> void:
	banner.load_file(FX_DIR + file)
	if text != "":
		banner.set_text(text, sub)
		_log("%s set_text(\"%s\", \"%s\")" % [title, text, sub])
	_current = title
	banner.play()


func _finish() -> void:
	if banner.is_playing():
		banner.finish()
		_log("배너 finish() 요청")


func _log(line: String) -> void:
	_lines.append("[%6.2f] %s" % [_clock, line])
	if _lines.size() > LOG_LINES:
		_lines = _lines.slice(_lines.size() - LOG_LINES)
	log_label.text = "\n".join(_lines)
