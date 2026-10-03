# Godot Text FX

문자 애니메이션 연출(전투 컷인·판정 결과·트레일러·장소/시간 자막)을 편집하고, 게임에서 그대로 재생할 수 있는 JSON으로 내보내는 Godot 4.7 도구다.

- `app/`: 미리보기·설정·템플릿·내보내기를 제공하는 에디터 앱.
- `addons/text_fx/`: 게임에 복사해 쓰는 런타임 애드온(`TextFxPlayer`). 에디터 코드에 의존하지 않는다.
- `examples/`: 런타임만 쓰는 게임 쪽 사용 예시.

설계와 데이터 포맷은 [`docs/DESIGN.md`](docs/DESIGN.md)에 있다.

## 웹 에디터

[브라우저에서 바로 실행](https://gosuni2025.github.io/godot-text-fx/) → 템플릿·문장·연출 편집 → **내보내기 → 문서 JSON 저장**. JSON 파일이 다운로드된다. 베이크 JSON도 같은 탭에서 받는다.

## 에디터 실행

```sh
godot --path .                 # 로딩 후 바로 에디터
godot --editor --path .        # Godot 에디터로 열기
```

## 에디터 기능

- 모드 3종: 메시지(컷인)·트레일러(빈 줄로 페이지 구분, 스크롤)·장소/시간 자막. 모드별 템플릿(전투·탐색·진행자·장면/시간·판정 등)과 ko/ja/en 견본 문장.
- 탭: 모드·템플릿 / 문장 / 연출(등장·유지·퇴장 효과, 글자 순서, 이징, 반복 방식) / 스타일(단색·그라데이션, 테두리 2겹, 그림자, 글로우) / 글꼴 / 장식(밑줄·띠·괄호 등) / 배치(가로·세로쓰기, 정렬, 금칙, 자동 축소) / 내보내기.
- 글꼴: 번들 글꼴, 시스템 글꼴 목록, 글꼴 파일 불러오기(`user://fonts`에 복사해 경로로 참조).
- 미리보기와 재생 바(재생/정지, 처음으로, 시간 탐색, 반복 방식, 퇴장 켜기), 실행 취소/다시 실행, 자동 저장(`user://autosave.json`).
- 단축키(물리 키): Space 재생/정지, Home 처음으로, Ctrl/Cmd+Z 실행 취소, Ctrl/Cmd+Shift+Z 다시 실행, Ctrl/Cmd+S 저장, Ctrl/Cmd+E 베이크 내보내기, Ctrl/Cmd+Shift+C 문서 문자열 복사.
- UI 언어: 한국어·일본어·영어.
- 특수 문자 연출: 파편 재조립, 잉크 침투, 재·불씨 소멸, 차원 균열, 잔상 추월, 액체 응집, 서리 결정, 실로 꿰매기, 표면 아래 압력, 문장 변이. 메시지의 특수 연출 템플릿에서 시작할 수 있다.

## 내보내기 형식

| 형식 | 내용 | 용도 |
|---|---|---|
| 문서 JSON (`format: "text_fx"`) | 문장·배치·스타일·타임라인 전체 | 게임에서 `TextFxPlayer`로 재생. 실행 중 문장 교체 가능 |
| 베이크 JSON (`format: "text_fx_baked"`) | 글자 기준 위치 + 프레임별 `[dx, dy, sx, sy, rot, alpha]` | 다른 엔진에서 글자 배치·변환만 재생 |
| 문자열 `TFX1:...` | base64(deflate(JSON)) 한 줄 | 클립보드로 문서·조작 기록 주고받기 |

예시 파일은 [`examples/fx/`](examples/fx)에 있다(베이크 예시: `battle_cutin.baked.json`).

## 생성한 JSON을 Godot 게임에서 쓰기

1. 이 저장소의 `addons/text_fx/`를 게임의 같은 경로에 복사한다(플러그인 활성화 불필요).
2. 내려받은 **문서 JSON**을 `res://fx/`에 넣고, JSON이 참조하는 글꼴도 같은 경로로 복사한다. 커스텀 글꼴의 `user://` 경로는 게임의 `res://` 경로로 바꾼다.
3. 씬에 `TextFxPlayer` 노드를 추가하고 재생한다. 게임 내보내기 설정의 비리소스 포함 필터에 `*.json`을 넣는다.

```gdscript
@onready var fx: TextFxPlayer = $TextFxPlayer

func show_caption() -> void:
    fx.load_file("res://fx/caption.json")
    fx.set_text("폐허가 된 역", "03:17 AM") # 선택: 본문·보조 문구 교체
    fx.play()
    await fx.finished
```

`loop_hold` 연출은 `fx.finish()`로 퇴장시킨다. API·베이크 재생은 [`addons/text_fx/README.md`](addons/text_fx/README.md) 참고.

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

특수 문자 연출 10종의 실제 창 검증·캡처(완료 후 자동 종료):

```sh
godot --audio-driver Dummy --path . --script res://tests/visual/cinematic_preview.gd -- --capture=/tmp/text-fx-cinematic
```

`--sample=text_morph`처럼 효과를 좁힐 수 있고, `--film`을 추가하면 영상용 20fps PNG도 저장한다.
문장 변이의 원문·최종문 일치 검사는 `tests/visual/text_morph_preview.gd`로 실행한다.

## 구조

```
addons/text_fx/   런타임 애드온: core/(순수 계산, 헤드리스) · render/(TextFxPlayer, 글자 굽기)
app/              에디터 앱: shell/(부트·타이틀·옵션) · logic/(문서 모델·명령·봇·리플레이·템플릿) · editor/(UI) · i18n/
examples/         게임 예시 씬, 예시 JSON(fx/), 생성기(tools/)
assets/           번들 글꼴, 아이콘
art/source/       아이콘 생성 원본·프롬프트
docs/DESIGN.md    설계·데이터 포맷
tests/            헤드리스 테스트
```

## 크레딧·라이선스

- 글꼴(모두 SIL Open Font License 1.1, 원문 동봉): Pretendard(길형진), Galmuri11(Lee Minseo), Cinzel. 출처·버전은 `assets/fonts/*/SOURCES.md`.
- 오디오: 공개 소스와 웹 빌드에는 BGM을 포함하지 않는다.
- 아이콘: 이미지 생성 도구로 만든 뒤 잘라내기·축소만 했다. 도구·프롬프트·가공 내역은 `art/source/icons/SOURCES.md`.
- 공용 모듈 `addons/game_base`, `addons/web_profiler`: [gosuni2025/godot-web-profiler](https://github.com/gosuni2025/godot-web-profiler)에서 가져왔고, revision과 파일 해시를 `addons/*.lock.json`에 기록한다. 출처는 `addons/game_base/SOURCES.md`.
- `addons/godot_ai`(4.2.3): MIT License(`addons/godot_ai/LICENSE`). 개발용 에디터 연동 애드온이다.

### 참고 도구

「文字画像APNGメーカー」의 연출 기능을 참고한다. 연출 대조와 구현 현황은 `docs/EFFECT_PARITY.md`에 기록한다.

## 웹 배포

`main`에 push하면 GitHub Actions가 Godot 4.7.2로 Web 프리셋을 빌드해 GitHub Pages에 배포한다. 단일 스레드 WebGL 2 빌드이므로 별도 교차 출처 격리 헤더는 필요 없다.

```sh
python3 addons/game_base/tools/stamp_build.py web --project .
godot --headless --audio-driver Dummy --path . --import
mkdir -p build/web
godot --headless --audio-driver Dummy --path . --export-release Web build/web/index.html
```
