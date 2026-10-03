# Godot Game Base

게임 로직과 독립된 공용 모듈이다. 기존 Godot 프로젝트에 설치해 연결한다.
빈 게임 프로젝트를 만들거나 전투·맵·캐릭터를 복사하지 않는다.
공식 원본은 `gosuni2025/godot-web-profiler` 저장소의 `addons/game_base/`다.
게임의 복사본은 `addons/game_base.lock.json`의 revision과 파일 해시로 고정한다.

## 설치와 게임 연결

저장소의 `docs/GAME_BASE_INTEGRATION.md`를 먼저 읽는다. 설치 도구는 addon만 복사한다.
`project.godot`, 게임 씬, 입력 맵, 저장 경로, 배포 채널은 자동 변경하지 않는다.
게임마다 필요한 연결은 LLM/개발자가 기존 구조를 살펴 명시적으로 작성한다.

1. `default_config.tres`를 **게임 루트**의 `base_project.tres`로 복사한다.
2. Inspector에서 프로젝트 ID, 제목/부제, 배경/테마, 옵션 목록과 실제 게임 씬 경로를 지정한다.
3. 기존 타이틀에는 `ui/wordmark.tscn`만 사용하거나 `ui/title.tscn`의 신호를 연결한다.
4. 기존 로딩은 `boot.gd`를 상속하는 게임 어댑터와 연결한다.
5. 옵션은 `settings_store.gd` + `ui/options.tscn`을 쓰거나 기존 메뉴와 저장 모델을 유지한다.
6. 프로파일링은 같은 저장소의 `web_profiler`를 별도로 설치하고 게임별 Source를 연결한다.

## 타이틀 커스터마이징

`base_project.tres`의 `title_material`을 게임 소유 `.tres`로 복제해서 편집한다.
공용 addon 파일을 직접 바꾸면 업데이트 시 로컬 변경으로 감지되어 덮어쓰기를 거부한다.

| 설정 | 의미 |
| --- | --- |
| `title`, `subtitle`, `tagline` | 제목과 설명 |
| `title_size_multiplier`, `title_centered` | 기본 글자 크기의 1.8배, 중앙 정렬 |
| `menu_size_multiplier` | 기본 버튼의 0.5배; 최소 44 실제 픽셀 터치 영역 유지 |
| `deep/mid/light_metal_color` | 글자 금속색의 어두운/중간/밝은 색 |
| `rift/flare/glow_color` | 균열·빛줄기·번짐 색 |
| `fragment_strength/length_px/row_height_px` | 글자 파편의 강도·길이·행 높이 |
| `tear_strength/length_px/trail_width_px` | 움직이는 찢김의 강도·길이·잔상 |
| `sweep_width_px/core_width_px` | 빛줄기의 폭과 중심 폭 |
| `motion_enabled` | 0이면 움직이는 빛줄기를 정지 |
| `reduced_transparency_amount/high_contrast_amount` | 효과 투명도·고대비 |
| `sweep_delay/duration/rest` | 시작 대기·이동 시간·반복 대기 |

숨겨진 타이틀은 tween을 정지한다. 각 인스턴스는 머티리얼을 복제하므로 다른 타이틀의
크기/진행률을 바꾸지 않는다. 글자는 실제 창 해상도에서 FontFile로 렌더링한다.

## 옵션

`option_definition.gd` 리소스마다 고유 ID, 표시명, 카테고리, 표시 여부, 기본값,
토글/범위/선택 종류를 지정한다. 범위는 최솟값·최댓값·간격, 선택은 저장 값과 표시명 배열을 쓴다.
`settings_store.changed(id, value)`를 게임에 연결해야 실제 엔진/게임 설정에 적용된다.
모듈은 게임의 조작·오디오 버스·언어·일시정지 정책을 추측하지 않는다.
`load_settings()`는 파일을 덮어쓰지 않고, 저장 오류는 호출자에게 반환한다.
저장 실패 시 현재 세션에는 적용된 상태임을 메뉴에 표시한다.
`config_path` 기본값은 `user://base_settings.cfg`; 게임의 별도 user-data 디렉터리를 지정한다.

`controller_style.gd`는 자동 감지와 타입 A/B/C 표시명을 제공한다.
기존 `xbox/playstation/switch` 저장 ID와 물리 버튼 위치는 유지한다.
버튼 이미지와 리바인딩 정책은 게임 소유이며 모듈이 바꾸지 않는다.

## 로딩·빌드·프로파일링

`boot.gd`는 스레드 로딩, 실패/재시도, 첫 화면 표시를 처리한다.
`configure_world`, `prepare_world`, `finish_world`는 게임 어댑터가 재정의할 수 있다.
`prepare_world`는 `Error`를 반환한다. 설정의 `warmup_script`는
`static func prepare(world: Node, report: Callable) -> Error` 계약을 따른다.
음원 디코딩/정적 메시 생성은 빌드 단계에서 하고 기기별 GPU·오디오 준비만 런타임에 둔다.

웹에는 `web/loading.html`과 Game Base export plugin을 설정한다.
기존 exporter가 있으면 `web_bundle.gd.source()`를 로딩 marker에 삽입하고 plugin을 중복 활성화하지 않는다.
`GodotBaseBoot.reportStage/reportDetail/complete/fail`로 실제 준비 완료를 전달한다.
엔진 시작 Promise만 완료돼서는 로딩 화면이 사라지지 않는다. 상세 기록은 메모리에서만 유지된다.

```sh
python3 addons/game_base/tools/stamp_build.py v1.0 --project . --build-number 42
```

프로젝트 루트의 `build_info.json`에 `version`, `build_number`, `revision`, `built_at`을 기록한다.
version은 `YYYYMMDD-HHMMSS-라벨`(한국 시간); 이미 이 형식이면 보존한다.
표준 출력의 version을 Butler userversion에도 그대로 사용한다. build_number를 생략하면
빌드 시각의 숫자를 사용한다. CI의 순번을 원하면 `--build-number`로 전달한다.
웹 HTML·게임 라벨·프로파일 보고서는 같은 JSON의 version을 사용한다.
export preset의 include_filter에 `build_info.json`과 `addons/game_base/fonts/LICENSE.txt`를 추가한다.

프로파일링 endpoint·인증·프로젝트 ID를 공유 모듈에 내장하지 않는다.
`profile_source.gd`는 최소 Node 어댑터 예시이며, 게임 전용 값은 강타입 Source를 확장한다.
보고서는 사용자 전송 동작에 연결하고 자동 업로드하지 않는다.

## 공용 메뉴 입력

`ui/menu_focus_navigation.gd`는 방향키·물리 WASD·D-pad·왼쪽 스틱에 대해
첫 입력 즉시 이동, 0.35초 뒤 0.10초 간격 반복, 양 끝 순환을 제공한다.
스틱 중립 신호가 들어와도 누른 D-pad의 반복은 유지한다. 활성 메뉴만
`handle_input(event, buttons, viewport)`와 `process(delta, buttons, viewport)`를
호출하고, 비활성화하거나 모달을 열 때 `reset()`한다.

공용 `ui/title.tscn`은 이 처리를 사용한다. 공용 `ui/options.tscn`은 활성 옵션의
category별 탭을 만들고 LB/RB 및 물리 Q/E·PageUp/PageDown으로 전환한다.
드롭다운을 연 상태에서도 전환할 수 있다. 기존 게임 옵션 어댑터는
`category_step(event, previous_action, next_action)`의 -1/0/1 반환값으로
기존 탭·포커스·소리를 연결한다. 게임의 InputMap은 변경하지 않는다.

`ui/menu_stick_scroll.gd`는 우측 스틱으로 기존 ScrollContainer를 스크롤한다.
`handle_input(event)`, `process(delta, scroll, enabled)`를 연결한다.
포커스를 이동하지 않으며 숨김·모달 상태에서는 enabled를 false로 전달한다.
크레딧·인벤토리의 콘텐츠와 버튼 아이콘은 게임이 소유한다.

기존 게임의 로컬 수정이 같은 원본 revision에 이미 반영되어 바이트 단위로 일치하면
설치 도구는 내용을 덮어쓰지 않고 lock을 갱신한다. 다른 로컬 수정은 계속 거부한다.

## 시스템 탭과 종료 확인

공용 옵션은 설정 카테고리 뒤에 `System` 탭을 추가하며 타이틀 복귀와 바탕화면 종료를 제공합니다.
타이틀 복귀는 플레이 중에만 활성화하고, 바탕화면 종료는 PC에서만 표시합니다.
두 동작 모두 `ui/exit_confirmation.tscn`의 공용 모달을 거칩니다. 취소에 기본 포커스를 두고
키보드·패드의 반복 탐색, 포커스 순환과 터치를 지원하며 뒤쪽 카테고리 입력을 막습니다.

`open_menu(store, in_game, profiling, prepare_exit)`의 선택적 Callable은
`prepare_exit(save: bool) -> String` 형태입니다. 저장·정리 완료까지 await하며 성공은 빈 문자열,
실패는 사용자에게 보여 줄 오류 문자열을 반환합니다. 준비 중에는 중복 실행·취소를 막고,
실패하면 팝업을 유지해 재시도·저장하지 않고 나가기·취소를 선택할 수 있습니다.
게임이 콜백을 연결하고 플레이 중일 때만 저장/저장하지 않기 선택을 제공합니다.
콜백 없는 메뉴나 타이틀에서는 Yes/Cancel 확인만 표시합니다.

준비 성공 후 `title_requested` / `quit_requested`를 기존 게임 수명 주기에 연결합니다.
`quit_requested` 연결이 없으면 Godot의 정상 종료를 사용합니다. 게임의 저장소·오토세이브는
모듈이 소유하지 않습니다. 저장하지 않기는 아직 실행되지 않은 자동 저장을 취소하도록
게임 콜백에서 처리해야 하며, 이미 저장한 진행을 롤백하거나 삭제하지 않습니다.
기존 옵션 화면은 같은 팝업을 인스턴싱해 `open_for(target, can_save, prepare_exit)`와
`exit_confirmed(target)`를 연결할 수 있습니다. `target`은 `title` 또는 `desktop`입니다.
480×270 논리 UI에서는 팝업의 `ui_scale`을 0.5로 설정할 수 있습니다.
