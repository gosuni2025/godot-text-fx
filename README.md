# Godot Text FX

문자 애니메이션 연출(전투 컷인·판정 결과·트레일러·장소/시간 자막)을 편집하고, 게임에서 그대로 재생할 수 있는 JSON으로 내보내는 Godot 4.7 도구다.

- `app/`: 미리보기·설정·템플릿·내보내기를 제공하는 에디터 앱.
- `addons/text_fx/`: 게임에 복사해 쓰는 런타임 애드온(`TextFxPlayer`). 에디터 코드에 의존하지 않는다.
- `examples/`: 런타임만 쓰는 게임 쪽 사용 예시.

설계와 데이터 포맷은 [`docs/DESIGN.md`](docs/DESIGN.md)에 있다.

## 에디터 실행

```sh
godot --path .                 # 부트 → 타이틀 → 에디터
godot --editor --path .        # Godot 에디터로 열기
```

## 에디터 기능

- 모드 3종: 메시지(컷인)·트레일러(빈 줄로 페이지 구분, 스크롤)·장소/시간 자막. 모드별 템플릿(전투·탐색·진행자·장면/시간·판정 등)과 ko/ja/en 견본 문장.
- 탭: 모드·템플릿 / 문장 / 연출(등장·유지·퇴장 효과, 글자 순서, 이징, 반복 방식) / 스타일(단색·그라데이션, 테두리 2겹, 그림자, 글로우) / 글꼴 / 장식(밑줄·띠·괄호 등) / 배치(가로·세로쓰기, 정렬, 금칙, 자동 축소) / 내보내기.
- 글꼴: 번들 글꼴, 시스템 글꼴 목록, 글꼴 파일 불러오기(`user://fonts`에 복사해 경로로 참조).
- 미리보기와 재생 바(재생/정지, 처음으로, 시간 탐색, 반복 방식, 퇴장 켜기), 실행 취소/다시 실행, 자동 저장(`user://autosave.json`).
- 단축키(물리 키): Space 재생/정지, Home 처음으로, Ctrl/Cmd+Z 실행 취소, Ctrl/Cmd+Shift+Z 다시 실행, Ctrl/Cmd+S 저장, Ctrl/Cmd+E 베이크 내보내기, Ctrl/Cmd+Shift+C 문서 문자열 복사.
- UI 언어: 한국어·일본어·영어.

## 내보내기 형식

| 형식 | 내용 | 용도 |
|---|---|---|
| 문서 JSON (`format: "text_fx"`) | 문장·배치·스타일·타임라인 전체 | 게임에서 `TextFxPlayer`로 재생. 실행 중 문장 교체 가능 |
| 베이크 JSON (`format: "text_fx_baked"`) | 글자 기준 위치 + 프레임별 `[dx, dy, sx, sy, rot, alpha]` | 다른 엔진에서 글자 배치·변환만 재생 |
| 문자열 `TFX1:...` | base64(deflate(JSON)) 한 줄 | 클립보드로 문서·조작 기록 주고받기 |

예시 파일은 [`examples/fx/`](examples/fx)에 있다(베이크 예시: `battle_cutin.baked.json`).

## 게임에서 쓰기

1. `addons/text_fx/`를 게임 프로젝트의 같은 경로로 복사한다(플러그인 활성화 불필요, `class_name TextFxPlayer`).
2. 문서가 참조하는 글꼴을 게임에 함께 넣는다. 번들 글꼴을 쓰면 `assets/fonts/pretendard`, `assets/fonts/galmuri`, `assets/fonts/cinzel`을 같은 경로로 복사한다(라이선스 파일 포함).
   에디터에서 불러온 `user://fonts/...` 글꼴이나 시스템 글꼴은 게임 실행 환경에 없을 수 있으니, 글꼴 파일을 게임에 포함하고 문서의 `font.path`를 그 경로로 바꾼다. 찾지 못하면 기본 대체 글꼴로 그린다.
3. 재생한다.

```gdscript
@onready var fx: TextFxPlayer = $TextFxPlayer

func show_place(name: String, time: String) -> void:
	fx.load_file("res://fx/location_caption.json")
	fx.set_text(name, time)      # 본문, 보조 문구만 교체
	fx.play()
	await fx.finished
```

- 속성: `document_path`, `autoplay`, `fit`(`contain`/`cover`/`none`), `speed`, `paused`
- 메서드: `load_file(path)`, `set_document(dict)`, `get_document()`, `set_text(main, sub := "")`, `play(from := 0.0)`, `stop()`, `seek(t)`, `finish()`, `is_playing()`, `get_duration()`, `get_time()`, `is_baked()`, `advance(delta)`
- 신호: `started`, `entered`(등장 완료), `page_changed(page)`, `exit_started`, `finished`, `looped`, `baked`
- `timeline.loop = "loop_hold"`이면 유지 구간을 반복하다가 `finish()`를 부르면 퇴장하고 `finished`를 보낸다.

자세한 내용은 [`addons/text_fx/README.md`](addons/text_fx/README.md).

### 게임 예시

```sh
godot --path . res://examples/game_demo.tscn
```

| 입력 | 동작 |
|---|---|
| 1 / 2 / 3 / 4 / 5 (물리 키) | 전투 컷인 / 판정 결과(loop_hold) / 여러 페이지 트레일러 / 장소 자막(`set_text`로 장소 교체) / 캐릭터 머리 위 피해 숫자(`set_text`) |
| F, Esc, 패드 B | `finish()` (판정 결과 닫기) |
| 방향키·패드 십자키 좌우, Enter·패드 A | 연출 고르기, 재생 |

신호(`started`·`entered`·`finished` 등)는 화면 아래 기록에 표시된다. 예시는 `addons/text_fx`와 `examples/fx/*.json`만 사용한다.
예시 JSON은 실제 편집기 로직(템플릿 + 명령 + `export`)으로 다시 만들 수 있다.

```sh
godot --headless --path . --script res://examples/tools/gen_examples.gd
```

## 결정론·조작 기록·봇·리플레이

- 같은 문서·시드·시간이면 미리보기·런타임·테스트에서 같은 결과가 나온다. 무작위 값은 시드·글자 번호·시간의 해시로 만든다.
- 에디터의 문서 변경은 모두 직렬화 가능한 명령(`{ "op": "set", "path": ..., "value": ... }` 등)이다. 조작 기록(OpLog)은 시작 문서 + 명령 목록이며 `TFX1:` 문자열로 복사·붙여넣기할 수 있다.
- `EditorBot`은 UI가 아닌 로직 계층에 명령을 보내는 시드 기반 봇이고, `Replay`는 조작 기록을 새 모델에 다시 적용해 같은 문서·내보내기 해시를 재현한다. 테스트가 이 기능을 사용한다.

## 프로파일 보고서

옵션의 **프로파일 보내기**로 공용 운영 서버에 수동 전송한다. 프로젝트 ID는 `godot-text-fx`다.
받은 보고서는 `python3 tools/profile_reports.py summary latest`로 확인한다.
공용 저장소 준비와 조회 명령은 [`docs/PROFILE_REPORTS.md`](docs/PROFILE_REPORTS.md)를 따른다.

## 테스트

```sh
godot --headless --path . --script res://tests/run_all.gd                 # 전체
godot --headless --path . --script res://tests/run_all.gd -- --filter=example_demo
```

`tests/` 바로 아래의 `*.gd`(`func run(t) -> void`)를 이름순으로 실행한다. 렌더 확인용 창 미리보기는 `tests/visual/player_preview.tscn`.

## 구조

```
addons/text_fx/   런타임 애드온: core/(순수 계산, 헤드리스) · render/(TextFxPlayer, 글자 굽기)
app/              에디터 앱: shell/(부트·타이틀·옵션) · logic/(문서 모델·명령·봇·리플레이·템플릿) · editor/(UI) · i18n/
examples/         게임 예시 씬, 예시 JSON(fx/), 생성기(tools/)
assets/           번들 글꼴, BGM, 아이콘
art/source/       아이콘 생성 원본·프롬프트
docs/DESIGN.md    설계·데이터 포맷
tests/            헤드리스 테스트
```

## 크레딧·라이선스

- 글꼴(모두 SIL Open Font License 1.1, 원문 동봉): Pretendard(길형진), Galmuri11(Lee Minseo), Cinzel. 출처·버전은 `assets/fonts/*/SOURCES.md`.
- BGM: Ovani Sound "Above The Clouds"(Ambient Music Pack Vol. 5), Ovani Sound Royalty-Free License. 작품에 포함해 쓸 수 있지만 음원 파일만 따로 재배포·판매할 수 없다. 가공 내역과 조건은 `assets/audio/SOURCES.md`.
- 아이콘: 이미지 생성 도구로 만든 뒤 잘라내기·축소만 했다. 도구·프롬프트·가공 내역은 `art/source/icons/SOURCES.md`.
- 공용 모듈 `addons/game_base`, `addons/web_profiler`: [gosuni2025/godot-web-profiler](https://github.com/gosuni2025/godot-web-profiler)에서 가져왔고, revision과 파일 해시를 `addons/*.lock.json`에 기록한다. 출처는 `addons/game_base/SOURCES.md`.
- `addons/godot_ai`(4.2.3): MIT License(`addons/godot_ai/LICENSE`). 개발용 에디터 연동 애드온이다.

### 참고 도구

「文字画像APNGメーカー」의 연출 기능을 참고한다. 연출 대조와 구현 현황은 `docs/EFFECT_PARITY.md`에 기록한다.
