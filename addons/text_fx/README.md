# Text FX 런타임 애드온

Godot Text FX 에디터에서 만든 문자 연출 JSON(`format: "text_fx"`)을 게임에서 재생하는 런타임이다.
에디터 앱(`app/`)에 의존하지 않는다. Godot 4.7, Compatibility/Forward+ 렌더러에서 동작한다.

## 설치

1. `addons/text_fx/` 폴더를 게임 프로젝트의 같은 경로로 복사한다.
2. 문서가 번들 글꼴을 참조하면 `assets/fonts/pretendard`, `assets/fonts/galmuri`, `assets/fonts/cinzel`도 같은 경로로 복사한다
   (갈무리11은 가나·한자 대체 글꼴로 쓰인다). 다른 글꼴은 문서의 `font.path`를 게임 쪽 경로로 바꾼다.
3. 플러그인 활성화는 필요 없다. `TextFxPlayer`는 `class_name`으로 노드 추가 목록에 나타난다.

## 사용

```gdscript
@onready var fx: TextFxPlayer = $TextFxPlayer   # Control. 앵커로 화면을 덮게 두면 fit="contain"으로 맞춘다

func show_banner(title: String, sub := "") -> void:
	fx.autoplay = false
	fx.load_file("res://fx/battle_start.json")   # 또는 fx.set_document(dict)
	fx.set_text(title, sub)                       # 문서의 문장만 바꾼다
	fx.play()
	await fx.finished
```

- 인스펙터 속성: `document_path`(JSON), `autoplay`, `fit`(`contain`/`cover`/`none`), `speed`, `paused`.
- 메서드: `load_file(path)`, `set_document(dict)`, `get_document()`, `set_text(main, sub := "")`, `play(from := 0.0)`,
  `stop()`, `seek(t)`, `finish()`, `is_playing()`, `get_duration()`, `get_time()`, `is_baked()`.
- 신호: `started`, `entered`(등장 완료, 페이지마다), `page_changed(page)`, `exit_started`, `finished`, `looped`, `baked`.
- 텍스트·스타일·화면 크기가 바뀌면 글자 스프라이트를 몇 프레임에 걸쳐 다시 굽는다. 굽는 동안 `play()`의 시계는 기다린다.
- 시간은 `_process(delta) * speed`로 흐르므로 게임 일시정지는 노드의 `process_mode`를 따른다.

## 표시해 두다가 닫기(loop_hold)

문서의 `timeline.loop`가 `"loop_hold"`이면 등장 후 유지 구간을 계속 반복한다. 닫을 때 `finish()`를 부르면
현재 페이지의 등장이 끝난 뒤 퇴장하고 `finished`를 보낸다(`exit.enabled = false`면 즉시 끝난다).

```gdscript
fx.load_file("res://fx/location_caption.json")   # loop = "loop_hold"
fx.set_text("잿빛 항구", "새벽 4시 12분")
fx.play()
# ... 플레이어가 지역을 벗어나면
fx.finish()
await fx.finished
```

## 순수 계산만 쓰기

`core/`는 노드·렌더링 없이 동작한다(헤드리스 가능, 결정적).

```gdscript
const Evaluator := preload("res://addons/text_fx/core/fx_evaluator.gd")
var ev := Evaluator.new(doc)            # 문서는 자동 정규화
var states := ev.evaluate(1.2)          # Array[TextFxGlyphState]: pos, scale, rotation, alpha, ...
```

다른 엔진용 프레임 데이터는 `TextFxBakedExport.bake(doc, 30.0)`(형식은 `docs/DESIGN.md` §5).
