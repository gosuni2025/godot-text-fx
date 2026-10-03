# Godot Text FX 설계

문자 애니메이션 연출을 편집하는 에디터 앱과, 그 결과(JSON)를 게임에서 재생하는 런타임 애드온의 설계다.
외부 문자 애니메이션 도구의 공개 동작을 대조하면서 Godot 런타임과 편집기에 맞게 독립 구현한다.
모집단·초기 누락·개발 결과는 [연출 전수 대조표](EFFECT_PARITY.md)를 기준으로 추적한다. 효과의 수식·초기 수치·예문은 이 프로젝트의 데이터다.

## 1. 구성

```
addons/text_fx/              # 게임에 복사하는 런타임. app/ 에 의존하지 않는다.
  core/                      # 순수 로직: 노드·렌더링 없이 동작, 헤드리스 테스트 대상
    fx_doc.gd                # TextFxDoc: 기본값, normalize/validate, format_version
    fx_hash.gd               # 결정적 해시 난수
    fx_easing.gd             # 이징 함수 표
    fx_font.gd               # 폰트 참조 → Font 해석(번들/시스템/파일, 굵기·기울임)
    fx_layout.gd             # 줄바꿈·금칙·세로쓰기·자동 축소 → 글자 배치
    fx_timeline.gd           # 페이지·구간(등장/유지/퇴장)·글자별 지연·루프
    fx_effects_enter.gd      # 등장/퇴장 효과 표·자동 이징
    fx_effects_block.gd      # 문장 전체 변형·와이프·글리치
    fx_timing_helpers.gd     # 보조 타이밍·sweep·구두점·스크롤
    fx_typing_cursor.gd      # 순수 계산 커서 상태
    fx_background.gd         # 결과 배경 상태
    fx_decoration_shapes.gd  # 도형별 등장/퇴장 경로
    fx_effects_hold.gd       # 유지 중 효과 표
    fx_evaluator.gd          # evaluate(t) → 글자 상태 배열
    fx_baked_export.gd       # 프레임 샘플링 내보내기(엔진 비의존 JSON)
  render/
    fx_glyph_baker.gd        # 스타일 입힌 글자 스프라이트를 SubViewport 아틀라스에 굽기
    text_fx_player.gd        # TextFxPlayer(Control): 로드·재생·그리기
  plugin.cfg, plugin.gd      # TextFxPlayer 사용자 정의 타입 등록(선택)
app/
  shell/                     # game_base 연결: 부트·타이틀·옵션·오디오·프로파일링 어댑터
  logic/                     # 에디터 로직: 문서 모델·명령·실행 취소·직렬화·봇·리플레이·템플릿
  editor/                    # 에디터 UI 씬(표시 전용). logic 에 명령을 보내고 결과만 표시
  i18n/                      # UI 번역 CSV(ko/ja/en)
tests/                       # SceneTree 테스트, run_all.gd
```

first-party 코드 파일은 20KB를 넘기 전에 책임을 분리한다.

## 2. 데이터 포맷 (format_version 2)

문서는 JSON 객체 하나다. 누락 필드는 `TextFxDoc.normalize()`가 기본값으로 채운다.
알 수 없는 필드는 보존하되 무시한다. 색은 `"#RRGGBBAA"` 또는 `"#RRGGBB"` 문자열.

```jsonc
{
  "format": "text_fx", "format_version": 2,
  "name": "교전 개시",
  "mode": "message",                // message | trailer | caption(장소·시간)
  "seed": 12345,
  "canvas": { "width": 1280, "height": 720 },
  "text": "교전 개시",              // 빈 줄(\n\n)은 페이지 구분(trailer)
  "sub_text": "",                   // 보조 문구(장소명 아래 시간 등). 없으면 ""
  "layout": {
    "direction": "horizontal",      // horizontal | vertical(세로쓰기, 열은 오른쪽→왼쪽)
    "align": "center", "valign": "center",   // left|center|right, top|center|bottom
    "anchor": [0.5, 0.5],           // 텍스트 블록 기준점(캔버스 비율)
    "offset": [0, 0],               // 픽셀
    "font_size": 96,
    "letter_spacing": 0.0,          // em 비율
    "line_height": 1.25,            // em 비율
    "max_width": 0.9, "max_height": 0.8,     // 캔버스 비율
    "wrap": "auto",                 // none | char | word | auto(CJK는 글자, 라틴·한글은 단어)
    "kinsoku": true,                // 줄머리·줄끝 금칙
    "auto_shrink": true, "min_font_size": 24,
    "sub": { "font_size": 40, "position": "below", "gap": 0.35, "letter_spacing": 0.0 }  // above|below, gap은 em 비율
  },
  "font":     { "source": "bundled", "family": "Pretendard", "path": "res://assets/fonts/pretendard/Pretendard-Regular.otf", "weight": 700, "italic": false },
  "sub_font": null,                 // null이면 font 사용
  "style": {                        // 본문 스타일
    "fill": { "type": "solid", "color": "#FFFFFFFF",
              "gradient": { "angle": 90, "stops": [[0.0, "#FFFFFF"], [1.0, "#9FD8FF"]], "space": "block" } }, // block|glyph|line
    "outline":  { "enabled": true,  "size": 6,  "color": "#101018FF" },
    "outline2": { "enabled": false, "size": 4,  "color": "#FFFFFFFF" },   // outline 바깥 2차 테두리
    "shadow":   { "enabled": true,  "offset": [4, 6], "blur": 4, "color": "#00000099" },
    "glow":     { "enabled": false, "size": 16, "color": "#66CCFFFF", "strength": 1.0 },
    "opacity": 1.0
  },
  "sub_style": null,                // null이면 style 사용
  "decorations": [
    { "type": "underline", "color": "#FFFFFFFF", "thickness": 4, "margin": 0.2, "length": 1.1,
      "use_outline": true, "animate": "grow_center", "delay": 0.1, "duration": 0.4 }
    // type: underline | overline | band | side_lines | frame | brackets | tape | box | bar | lines
    // animate: none | fade | grow_center | grow_start | shape
  ],
  "background": { "type": "none", "color": "#101018CC", "opacity": 1.0, "extent": 0.6, "sync_fade": true },
  "timeline": {
    "enter": { "effect": "fade", "order": "forward", "duration": 0.45, "stagger": 0.06,
               "easing": "cubic_out", "params": {} },
    "hold":  { "duration": 1.6, "scope": "hold", "effects": [ { "type": "shake", "amplitude": 2.0, "frequency": 18 } ] },
    "exit":  { "enabled": true, "effect": "fade", "order": "all", "duration": 0.35, "stagger": 0.0,
               "easing": "cubic_in", "params": {} },
    "sub_enter": null,             // null이면 기존 공통 등장, 객체면 보조 문구 독립 등장
    "lead_in": 0.0, "lead_out": 0.0, // 문서 전체 앞/뒤 공백(초)
    "split_pages": true, "exit_between_pages": true,
    "page_gap": 0.25,               // 페이지 사이 공백(초)
    "loop": "once",                 // once | loop_all | loop_hold
    "scroll": null                  // { "speed": 60, "edge_fade": 0.0 }; 쓰기 방향에 따라 아래→위/왼→오
  }
}
```

포맷 1 문서도 읽을 수 있으며 정규화 결과와 저장 결과는 2가 된다. 기존 명시 이징·효과 ID를 유지하고,
기존 문서에 영향을 주는 새 연출은 0/false/null 기본값으로 비활성화한다. 새 순서 sweep의 행 간격/훑기 시간은 즉시 구분되도록 0.65/0.5초를 기본으로 한다. 포맷 1에 보조 자간이 없으면 본문 자간을 복사해 기존 배치를 유지한다.
`text_fx_baked`와 조작 기록은 별도 포맷이므로 아래 §5·§6에 명시한 버전 1을 유지한다.

### 2.1 순서(order)

글자 i의 등장 지연 = `rank(i) * stagger`. rank는 페이지 안에서 계산한다.

| id | rank |
|---|---|
| all | 0 (동시) |
| forward / reverse | 글자 순번 / 역순 |
| line | 줄 번호 (stagger는 줄 간격) |
| word | 단어 번호 |
| center_out / edges_in | 줄 중심과의 거리 순 / 역순 |
| random | 시드 해시로 섞은 순번 |
| center_index / edges_index | 페이지 가시 글자 인덱스 중앙/양끝 기준 순서 |
| sweep | 행 시작 간격 + 행 안 글자 중심의 위치 비율 × sweep 시간 |

공백·줄바꿈은 rank를 차지하지 않는다. 공통 params는 `punct_pause`(짧은 구두점 뒤), `punct_long_pause`(긴 구두점 뒤),
`line_pause`(행 경계), `line_stagger`(sweep 행 간격, 기본 0.65), `sweep_duration`(행을 훑는 시간, 기본 0.5)이며 단위는 초다.
긴 구두점 쉼은 기존 `punct_pause`보다 짧아지지 않는다. `sweep`은 글자 수가 다른 행도 공간 길이 비율로 순서를 배분한다.
`cursor`(기본 false), `cursor_blink`(초), `cursor_color`(null이면 글자색)는 순차 등장에 입력 커서를 덧붙인다.
커서는 마지막 표시 글자 뒤를 따라가고 등장 완료 후 점멸하며 퇴장에서는 숨긴다.

### 2.2 등장·퇴장 효과

각 효과는 "숨김 정도" k(0 = 정상 위치, 1 = 완전히 숨김)를 받아 글자 상태 변화량을 만든다.
등장은 `k = 1 - ease(p)`, 퇴장은 `k = ease(p)`로 같은 효과를 대칭으로 재사용한다.

| id | 동작 | 주요 params |
|---|---|---|
| fade | 투명도 | – |
| slide | 방향 이동 + 투명도 | dir(up/down/left/right), distance(em) |
| zoom | 배율 + 투명도 | from_scale |
| pop | 작게 시작해 살짝 넘쳤다 돌아옴(back 이징 권장) | from_scale |
| drop | 위에서 떨어져 튕김(bounce 이징 권장) | distance |
| rise | 아래에서 떠오르며 방향성 흐림 | distance, blur |
| blur | 실제 연속 블러 + 투명도 | radius(em) |
| spin | 회전 + 투명도 | angle |
| converge | 홀짝 글자가 위·아래에서 모임(본문 위/보조 아래 모드 포함) | distance, mode(alternate/role) |
| tracking | 자간이 넓게 퍼진 상태에서 좁혀짐 | spread |
| center_split | 중앙 겹침 등장·유지 후 제자리로 펼침 | jitter, overlap_hold(초; 0은 기존 동작) |
| scatter | 시드 방향으로 흩어진 상태에서 모임 + 회전 | distance, angle |
| wipe | 글자 내부를 왼→오른쪽으로 드러냄(clip) | dir |
| typewriter | 즉시 표시 + 짧은 튐 | pop |
| glitch | 글자별 위치 튐·깜빡임·색수차·조각 | intensity, color_a, color_b |
| center_stamp | 중앙에 큰 글자씩 표시 → 공백 → 전체 문장 착지 | big_scale, viewport_scale, solo_animated, hold_each, pause, slam_scale, space_pause, impact_duration, impact_brightness, impact_shake(px) |
| flip | 한 축만 펼치는 글자 넘김 | axis(auto/horizontal/vertical) |
| flicker | 등장·퇴장 중 불규칙 명멸 | rate, min_alpha |
| bounce | 위에서 떨어지는 바운드 | distance(em) |
| erase | 지정 순서로 순간 삭제 | duration은 사용하지 않음 |
| slam | 전체 문장이 축소 착지하고 흔들림·밝기가 가라앉음 | from_scale, impact(시간 비율), shake(em), brightness, blur(em) |
| block_zoom | 큰 문장 전체가 가까워짐/통과하며 흐림 변화 | from_scale, blur(em) |
| emerge | 작은 문장 전체가 등장/멀어져 퇴장 | from_scale |
| shutter | 문장 전체를 한 축으로 펼침/접음 | axis(horizontal/vertical) |
| flash | 백색 섬광·글로우 증폭 | brightness, glow |
| block_wipe | 전체 영역을 연속 마스크로 드러내거나 지움 | dir(up/down/left/right/center), feather(em) |
| block_glitch | 모든 글자가 공유하는 수평 띠·색수차·명멸 | intensity, slices, color_a, color_b |

`center_stamp`는 글자별 효과가 아니라 시퀀스이므로 evaluator가 별도 경로로 처리하며,
중앙에 크게 그려지는 글자는 "오버레이 글자"로 출력한다(큰 글자 전용 스프라이트를 굽는다).
`space_pause`는 공백/개행 묶음마다 한 번 쉰다. 충격 밝기·흔들림은 전체 문장 등장 순간부터 감쇠한다.
`viewport_scale>0`이면 큰 글자 크기를 캔버스 짧은 변의 비율로 정하고 위치도 anchor/offset과 무관하게 화면 중앙에 둔다.
0이면 기존 big_scale과 문서 기준점을 사용한다. `solo_animated=false`이면 중앙의 글자가 투명도·축척 전환 없이 즉시 교체되고,
true(기본)는 기존 짧은 확대·페이드 동작을 유지한다.

`slam/block_zoom/emerge/shutter/flash/block_wipe/block_glitch`는 `BLOCK_EFFECTS`에 속한다.
글자마다 확대만 하는 `zoom`과 달리 페이지 중심 기준으로 글자 간 거리까지 같이 바꾸며, order/stagger를 무시하고 한 시계를 공유한다.
중앙 와이프 퇴장은 가운데를 지워 양끝이 남는 역마스크다. 기존 글자별 wipe/glitch와 별도 ID로 두어 문서 1의 동작을 보존한다.

`glow_pulse` 및 flash의 halo 증폭은 style.glow.enabled=true일 때 나타난다. 글로우가 꺼져 있으면 flash의 백색 혼합만 적용되며, 효과가 임의로 스타일 글로우를 켜지는 않는다.

`easing: "auto"`는 `Enter.resolve_easing(effect, selected, is_exit)`로 해석한다. 팝/flip은 back, bounce/drop은 bounce,
shutter는 expo, 순간 표시·명멸·전체 글리치는 linear를 사용한다. 명시한 곡선은 바꾸지 않는다.

### 2.3 유지 중 효과 (중첩 가능)

| type | 동작 | params |
|---|---|---|
| blink | 투명도 점멸 | period, min_alpha, hard(bool) |
| flicker | 시드 기반 불규칙 깜빡임 | rate, min_alpha |
| shake | 시드 기반 흔들림 | amplitude(px), frequency |
| wave | 글자별 위상차 사인 이동 | amplitude, wavelength(글자 수), speed |
| float | 블록 전체 느린 상하 이동 | amplitude, period |
| pulse | 배율 맥동 | scale, period |
| glitch | 간헐적 노이즈: 수평 조각 밀림 + 2색 색수차 | interval, duration, intensity, slices, color_a, color_b |
| color_cycle | 색조 순환 틴트 | period, saturation, spread |
| heartbeat | 전체 문장이 한 주기에 두 번 박동 | scale, period |
| glow_pulse | 글로우 레이어만 주기적으로 명멸 | min_strength, period |
| block_shake | 모든 글자에 같은 위치 변화를 적용 | amplitude(px), frequency |
| block_glitch | 페이지 공통 좌표 띠의 간헐 노이즈 | interval, duration, intensity, slices, color_a, color_b |

### 2.4 타임라인

- 전체 순서: `lead_in` → 페이지별 `enter(p)` → `hold(p)` → `exit(p)` → `lead_out`. 페이지 사이는 `page_gap`.
- 기본 `exit_between_pages=true`는 기존처럼 중간 페이지 퇴장을 수행한다. false면 `exit.enabled`가 꺼졌을 때 중간 페이지도 즉시 전환한다.
- `enter(p)` 길이 = 마지막 글자 지연 + duration. center_split의 overlap_hold와 장식 선행 시간도 반영한다.
- `sub_enter` 객체는 enter와 같은 effect/order/duration/stagger/easing/params 및 signed `delay`를 가진다.
  보조 시작 = max(페이지 문자 시작, 본문 등장 완료 + delay). effect=same은 본문 효과를 상속하며 same+block 효과는 동시 변형한다.
- `exit.enabled = false`면 마지막 페이지는 유지 상태로 끝난다(유지 효과는 계속 계산).
- loop: `once` 끝에서 정지, `loop_all` 전체 반복, `loop_hold` 등장 후 유지 구간을 무한 반복하고
  플레이어의 `finish()` 호출 시 퇴장으로 넘어간다(게임에서 "표시해 두다가 닫기" 용도).
- `scroll`이 있으면 페이지 구분 없이 가로쓰기는 캔버스 아래→위, 세로쓰기는 왼→오른쪽으로 speed px/s 이동한다.
  `edge_fade`는 양끝 페이드 폭의 캔버스 비율(0이면 끔)이다.

### 2.5 런타임 구현 세부(addons/text_fx)

- 기본값의 원본은 `core/fx_doc.gd`의 `defaults()`다(위 예시와 같되 `hold.effects`, `decorations` 기본은 빈 배열).
  `normalize`는 기본값 타입으로 숫자를 맞추고 허용되지 않는 enum 값을 기본값으로 교정하며 알 수 없는 필드는 보존한다.
- 페이지: trailer 모드(스크롤 없음)이고 timeline.split_pages=true이면 빈 줄로 나눈다. `sub_text`도 같은 방식으로 나눠 같은 번호의 페이지에 붙인다.
- 그라데이션 `angle`은 화면 좌표(y 아래) 기준 도: 0 = 왼→오, 90 = 위→아래. `block`은 페이지의 역할(본문/보조) 영역, `line`은 행 영역, `glyph`는 개별 글자 기준. 채우기 색의 alpha만 낮추면 외곽선을 남긴 투명 내부를 만들 수 있다.
- 테두리 `size`·그림자 `offset/blur`·글로우 `size`는 캔버스 px. 테두리는 글자 바깥으로 size px만큼 두른다.
- 방향이 있는 등장 효과(slide/drop/rise/wipe)는 퇴장에서 들어온 길로 되돌아가지 않고 운동 방향을 잇는다(`dir` = 움직이는 방향).
  `center_stamp`를 퇴장에 쓰면 `slam_scale`배로 부풀며 사라진다.
- 유지 적용 범위는 timeline.hold.scope로 선택한다. `hold`는 기존처럼 hold에서만 적용하며, `visible`은 등장부터 퇴장까지 연속 page_time을 쓴다.
  blink는 visible에서도 등장 완료 후 시작한다. 스크롤 전체는 hold이며 loop_hold의 시간은 끊기지 않고 증가한다.
- `finish()`: 현재 페이지의 등장이 끝난 뒤(이미 유지 중이면 즉시) 그 페이지의 퇴장을 하고 끝난다. 남은 페이지는 건너뛴다.
  `exit.enabled = false`면 finish 시 즉시 끝난다. 스크롤 모드의 loop_hold는 loop_all처럼 반복한다.
- 장식 기준 영역은 페이지 본문 영역. `margin`은 em, `thickness`는 px, `length`는 영역 크기 비율(side_lines는 한쪽 선 = 폭 × length × 0.5).
  세로쓰기에서는 underline = 왼쪽 세로선, overline = 오른쪽, side_lines = 위·아래. center_stamp에서는 내려찍기 시작 기준으로 시간을 잰다.

### 2.6 장식과 결과 배경

장식은 기존 6종에 `tape`(서로 반대로 흐르는 두 줄무늬 테이프), `box`(둥근 채운 상자), `bar`(앞쪽 막대), `lines`(상하 평행선)를 추가한다.
모양을 직접 늘리는 `animate: shape`는 도형마다 경로가 다르다. 띠 두께 확장, 테이프 진입·퇴장, 상자 한 축 확장, 밑줄 wipe,
모서리 이동, 타이틀 틀의 한붓그리기를 처리한다. 기존 grow_center/grow_start는 기존 사각형 성장 방식이다.

공통 확장 필드는 `fill_color/fill_opacity`, `radius`(px), `softness/end_fade`(0..1), `full_span`,
`stripe_width`(px), `stripe_speed`(px/s), `blink_period`(초; 0 끔), `blink_strength`(0..1), `arm_length`(영역 비율),
`lead_text`, `exit_delay/exit_duration`(초)다. `lead_text=true`이면 장식의 등장 완료 후 글자가 시작한다.
`exit_duration=0`은 페이지 퇴장 길이를 따른다. `use_outline`은 본문의 1차·2차 외곽선을 장식 선에 적용한다.
`box`는 본문+보조 영역, `frame`은 본문 영역을 감싼다. `protect_sub`는 보조 문구와 겹치지 않게 여백을 제한하고,
`clamp_canvas`는 틀 확장을 화면 안으로 제한한다. `follow_block`은 문자 전체 변형에 장식을 연동하는 선택 옵션이다.
연동 시 float/block_shake/block_glitch의 공통 이동과 slam/center_stamp 충격을 따른다. box는 문장 전체의 균등/한 축 축척도 따르고,
다른 장식은 이동만 따른다. 본문 글자 하나의 개별 움직임을 역산하지 않고 독립적인 블록 상태를 공유한다.

결과 배경은 미리보기 배경과 별개인 `background` 객체다. type은 `none/solid/vignette/bottom/top`,
색 `color`, 불투명도 `opacity`, 그라데이션 범위 `extent`, 문서 등장·퇴장에 맞추는 `sync_fade`를 저장한다.
페이지 사이 공백에서도 배경을 유지하는 동기화는 문자 전체 타임라인 기준으로 평가한다.

## 3. 런타임 계산 (core)

- `TextFxLayout.compute(doc, fonts) -> LayoutResult`
  - 글자마다 `{ index, char, role("main"/"sub"), page, line, line_in_page, col, word, pos(글자 박스 중심, 캔버스 좌표), box, advance, font_size, vertical_rotate(bool), base_rotation, punct }`.
  - 줄 정보 `{ page, role, rect, center }`, 페이지별 블록 rect, 최종 font_size(자동 축소 후).
  - 금칙: 줄머리 금지(、。，．・：；？！ー）」』】〉》〕…‥ 등과 닫는 괄호류), 줄끝 금지(（「『【〈《〔 등 여는 괄호류). 한국어·영어는 공백 단위 단어 유지(keep-all), 단어가 한 줄보다 길면 글자 단위로 자른다.
  - 세로쓰기: 열은 오른쪽→왼쪽. 장음·괄호·대시류는 회전(vertical_rotate) 또는 세로형 문자로 대체하고, 작은 가나·구두점은 오른쪽 위로 보정한다. 라틴 문자는 회전 처리.
  - 자동 축소: max_width/max_height를 넘으면 font_size를 줄여 다시 배치(min_font_size까지).
- `TextFxTimeline.new(doc, layout)`: total_duration, 페이지·구간 경계, 글자별 지연을 미리 계산.
- `TextFxEvaluator.evaluate(t) -> Array[GlyphState]`
  - GlyphState: `{ index, visible, pos, scale(Vector2), rotation, alpha, tint(Color), clip(0~1 드러난 비율), clip_dir, ghost(실제 흐림 반경 px), slices(글리치 조각 오프셋 배열), split(색수차 px), overlay(bool), overlay_scale }`
    (+ `char`, `role`, `page`, `ghost_dir`, `split_color_a/b`, `brightness`, `glow_multiplier`,
    `clip_enabled/clip_rect/clip_invert/clip_feather`, `slices_global/slice_origin_y/slice_height`). 앞 N개는 글자 순서와 같고 오버레이 글자는 뒤에 덧붙는다.
  - `evaluate_frame(t, finish_at)`은 장식·커서 사각형, 결과 배경, 현재 페이지·구간·스크롤 오프셋도 함께 돌려준다.
  - 순수 함수: 같은 doc·t → 같은 결과. 노드·Engine 시간·전역 난수를 쓰지 않는다.
- `TextFxHash.f(seed, a, b) -> float [0,1)`: 정수 해시(예: PCG/xxhash 계열 비트 연산).

## 4. 렌더링 (render)

- 글자는 채우기(앞), 그림자·외곽선(뒤), 독립 글로우 레이어로 굽는다. 뒤쪽 레이어에서 채우기 실루엣을 제거해
  투명 내부와 페이드 중 테두리가 본문 안으로 비치지 않게 한다. 모든 글자의 뒤를 그린 다음 앞을 그려 두꺼운 외곽선이
  이웃 글자의 채우기를 덮지 않게 한다. 독립 글로우는 glow_multiplier로 본문 alpha와 별개로 명멸한다.
- 아틀라스는 투명 렌더 타깃이라 프리멀티플라이드 알파다. 플레이어 재질은 `BLEND_MODE_PREMULT_ALPHA`이고 모든 색을 프리멀티플라이해 넘긴다.
- 굽는 배율 = 화면 맞춤 배율(0.25~4, 0.05 단위)이라 실제 표시 해상도로 선명하게 그린다. 표시 배율이 구운 배율보다 커지면(한 단계라도) 바로, 작아지면 12% 넘게 줄었을 때 다시 굽는다. 굽는 동안 크기가 바뀌면 굽기가 끝난 뒤 다시 확인한다. 플레이어는 텍스처 필터를 선형으로 고정한다(게임 기본값이 nearest여도 계단 없음).
- Godot `draw_char_outline`의 size는 실측상 바깥 두께의 약 4배라 문서 size(px) × 4를 넘긴다.
- `FxGlyphBaker`: 글자 인스턴스마다 셀(패딩 = 테두리 + 글로우 + 그림자 오프셋 + 블러 여유)을 배정해
  SubViewport 아틀라스에 그린다(UPDATE_ONCE).
  1) 실루엣 뷰포트: 글로우·그림자용 실루엣 → 블러 셰이더로 흐린 텍스처
  2) 가로 블러 뷰포트(R = 그림자 반경, G = 글로우 반경) → 합성 단계에서 세로 블러
  3) 합성 뷰포트: 뒤 = 흐린 그림자 + 2차 테두리 + 테두리 − 채우기 모양, 글로우 = 별도 흐린 실루엣 − 채우기 모양, 앞 = 채우기(그라데이션 셰이더는 셀마다 `t = VERTEX·a + b` uniform)
  - 그라데이션 `space: block/line`이면 글자의 블록/행 내 위치를 반영해 같은 영역에서 그라데이션이 이어진다.
  - 동적 블러 대상은 셀을 투명 여백과 함께 분리하고 mipmap을 만들어 아틀라스의 이웃 글자가 섞이지 않게 한다.
  - 아틀라스가 최대 크기(4096)를 넘으면 여러 장으로 나눈다. 텍스트·스타일·크기가 바뀔 때만 다시 굽는다.
- `TextFxPlayer`(Control):
  - `load_file(path)`, `set_document(dict)`, `set_text(main, sub := "")`, `play(from := 0.0)`, `stop()`, `seek(t)`, `finish()`, `is_playing()`, `get_duration()`
    (+ `get_document()`, `get_time()`, `is_baked()`, `get_evaluator()`, 수동 진행 `advance(delta)`, 신호 `baked`). 굽는 동안 play()의 시계는 굽기가 끝날 때까지 기다린다.
  - 속성: `document_path`, `autoplay`, `fit`("contain"/"cover"/"none"), `speed`, `paused`.
  - 신호: `started`, `entered`(등장 완료), `page_changed(page)`, `exit_started`, `finished`, `looped`.
  - `_draw()`에서 evaluator 결과대로 풀링된 CanvasItem/RID와 글자 효과 셰이더로 그린다. 셰이더는 실제 블러, 백색 혼합,
    글로우 배율, 캔버스 좌표 마스크(부드러운 경계·역마스크), 전체 공통 수평 글리치 띠를 처리한다. 기존 글자별 clip/조각도 유지한다.
  - 배경과 장식은 전용 drawer가 그린다. 둥근 상자는 StyleBoxFlat, 테이프는 잘린 줄무늬 폴리곤, 띠는 경계 alpha를 쓴다.
  - 시간 진행은 `_process(delta) * speed`. 게임이 일시정지하면 `process_mode`를 따른다.
- 폰트 해석(`FxFont`): `bundled`/`path` → `load(path)`(res:// 또는 user:// 파일은 `FontFile.load_dynamic_font`), `system` → `SystemFont`(font_names=[family], font_weight, font_italic).
  해석 실패 시 `ThemeDB.fallback_font`. 굵기는 SystemFont는 weight, 파일 폰트는 `FontVariation.variation_embolden`으로 근사한다.

## 5. 내보내기

1. **문서 JSON**(기본): 위 포맷 그대로. 게임은 `TextFxPlayer`로 재생하며 텍스트를 실행 중에 바꿀 수 있다.
2. **베이크 JSON**(엔진 비의존): `{ "format": "text_fx_baked", "format_version": 1, "fps", "canvas", "duration", "loop",
   "glyphs": [{ "index", "char", "role", "font_size", "base": [x, y] }], "frames": [[[dx, dy, sx, sy, rot, alpha], ...], ...] }`
   — 값은 소수 셋째 자리 반올림. 다른 엔진에서 글자 배치·변환만 재생할 때 쓴다.
   구현 추가 필드: glyph `rot`(세로쓰기 기본 회전, frame rot은 그에 대한 차이), `seed`, `markers.hold_start/hold_end`(loop_hold 반복 구간),
   center_stamp 오버레이는 role `"overlay"` 글자(`source` = 원래 글자 번호, base = 중앙)로 추가. 진입점 `TextFxBakedExport.bake(doc, fps := 30)`.
   **베이크 포맷 1은 위치·축척·회전·alpha만 기록한다.** 블러·색수차·조각·와이프 마스크·밝기·글로우·배경·장식·커서·틴트는
   이 숫자 프레임에 포함되지 않는다. 원본 연출 전체를 재생하려면 문서 포맷 2와 TextFxPlayer를 사용한다.
   문서 버전 상승을 베이크 버전 상승으로 오해하지 않도록 두 format_version을 독립 관리한다.
3. 클립보드 문자열: `TFX1:` + base64(deflate(JSON)) 한 줄. 문서·조작 기록 모두 같은 방식.

## 6. 에디터 로직 (app/logic)

- `EditorModel`: 현재 문서(dict), 재생 상태(time, playing), 선택 상태. `apply(command) -> bool`만으로 바뀐다. 신호 `changed(paths)`.
- 명령은 `{ "op": ..., ... }` dict. 예: `set {path:"style.outline.size", value:8}`, `set_text {text, sub_text}`,
  `select_effect {segment, effect}`, `apply_template {id}`, `set_mode {mode}`, `load_doc {doc}`, `seek {t}`, `play`, `pause`, `set_locale {locale}`,
  `undo`, `redo`, `export {kind}`(결과는 model.last_export에 저장).
- 실행 취소/다시 실행은 문서 변경 명령만 대상. 연속된 같은 path의 set은 하나로 합친다(슬라이더 드래그).
- `OpLog`: 적용된 명령 목록 + 시작 문서 + 시드. `serialize() -> String`(`TFX1:` 형식), `parse(String)`.
- `Replay`: OpLog를 새 모델에 다시 적용. 결과 문서·내보내기 해시가 같아야 한다.
- `EditorBot`: 시드로 결정되는 봇. 템플릿 선택·값 변경·재생/탐색·내보내기를 명령으로 수행하고 OpLog를 남긴다. 테스트와 AI 조작용.
- 템플릿: `app/logic/templates/*.json` 또는 GDScript 표. 모드·분류(전투/탐색/진행자/장면·시간/판정)·아이콘 id·견본 문장(ko/ja/en, `Lore.txt` 세계관)·문서 패치(기본값과의 차이)·loop 기본값.

### 6.1 구현 메모

파일: `editor_model.gd`(상태·실행 취소·재생·내보내기), `doc_commands.gd`(문서 명령 순수 계산), `doc_schema.gd`(필드 규칙·경로),
`doc_api.gd`(기본값·정규화 창구: 런타임 `TextFxDoc`를 쓰고 JSON 모양으로 맞춤), `serialization.gd`, `op_log.gd`, `replay.gd`, `editor_bot.gd`, `templates.gd` + `templates/*.json`.
스크립트끼리는 `preload` 상수로 참조한다(class_name 비의존).

명령 전체(잘못된 입력은 `false`, 문서·상태 불변, 이유는 `model.last_error`):

| op | 인자 | 실행 취소 |
|---|---|---|
| set | path, value, merge?(기본 true) | O, 같은 path 연속은 합침 |
| unset | path (열린 사전: 효과 params·유지 효과·장식의 추가 키만) | O |
| set_text | text?, sub_text?, merge? | O, 연속 입력은 합침 |
| set_mode | mode | O |
| select_effect | segment(enter/exit/sub_enter), effect | O, effect/params/auto easing을 한 번에 변경 |
| list_add | path, value(타입 id 문자열 또는 dict / 그라데이션은 [pos, color]), index? | O |
| list_remove | path, index | O |
| list_move | path, from, to | O |
| apply_template | id, keep_text?(기본 false) — canvas·seed는 유지 | O |
| load_doc | doc(dict) 또는 string(`TFX1:`) | O |
| set_locale | locale(ko/ja/en) | 견본 교체가 있으면 그 문서 변경만 O |
| seek | t(0~3600) / play from? / pause / select path | X |
| undo / redo | – | – |
| export | kind: doc_json · doc_string · baked_json(fps? 1~120, 기본 30, `TextFxBakedExport.bake` 호출) | X |

- 경로: `.` 구분, 배열은 번호(`decorations.0.color`, `timeline.hold.effects.1.amplitude`). 없는 키는 거부(오타 방지).
  목록 명령 경로: `decorations`(최대 12), `timeline.hold.effects`(최대 8), `style.fill.gradient.stops`·`sub_style.fill.gradient.stops`(2~8).
- `select_effect`는 효과 기본 params와 auto easing을 함께 바꾼다. 전체 효과는 order=all, typewriter/erase는 duration=0·순차 표시/삭제를 적용한다.
  effect 선택은 원자적 명령이므로 undo·redo·OpLog·봇·리플레이에서 한 단계다.
- 모든 문서 명령은 결과를 정규화한 뒤 `doc_schema` 규칙(형식·범위·선택지)으로 문서 전체를 검사하고, 통과할 때만 반영한다.
- 문서 안의 수는 JSON 파서와 같은 모양(float)으로 유지해 "문서 → JSON → 문서" 왕복 해시가 같다. 해시는 키 정렬 JSON의 SHA-256.
- `changed(paths)`: 문서 경로, 문서 전체 `"*"`, 상태 `"$time" "$playing" "$locale" "$selection" "$export" "$history"`. 값이 같은 set은 신호·기록 없음.
- `last_export = { ok, kind, text, hash(text SHA-256), data?(baked) }`. `advance(dt)`는 UI 재생 시계용 메서드로 명령·기록에 남지 않는다.
- 언어 전환: 마지막으로 적용한 템플릿이 있으면 `name/text/sub_text/font/sub_font` 중 이전 언어 견본과 같은(사용자가 고치지 않은) 필드만 새 언어 견본으로 바꾼다.
- 템플릿 JSON: 파일 `{ mode, groups[], locale_patch{loc: patch}, templates[] }`(한 모드를 여러 파일로 나눌 수 있음),
  템플릿 `{ id, group, icon, loop, name{ko,ja,en}, text{..}, sub_text{..}?, patch, locale_patch{loc: patch}? }`.
  적용 순서: 기본값 ⊕ 파일 locale_patch[loc] ⊕ patch ⊕ 템플릿 locale_patch[loc] ⊕ {mode, name, text, sub_text, loop}.
  언어별 글꼴은 locale_patch로 준다: 기본 Pretendard(ko/en), ja는 파일 단위로 Galmuri11, 라틴 제목 템플릿은 en에서 Cinzel.
- OpLog 내용 JSON: `{ format: "text_fx_oplog", format_version: 1, seed, locale, start_doc, commands[] }`. 거부된 명령도 기록해 리플레이 결과(명령별 성공 여부)까지 같게 한다.
- `EditorBot.new(seed, start_doc?, locale?)`: `send(cmd)`, `run_plan(cmds)`, `run_random(steps)`(첫 명령은 템플릿 적용), `final_hash()`, `log`. 난수는 자체 xorshift32.

## 7. 에디터 UI (app/editor)

- 왼쪽: 미리보기(체커보드/단색/사용자 이미지 배경, 캔버스 비율 유지) + 재생 바(재생/일시정지, 처음으로, 시간 스크럽, 반복 방식, 퇴장 켜기).
- 오른쪽: 탭(모드·템플릿 / 문장 / 연출 / 스타일 / 글꼴 / 장식 / 배치 / 내보내기).
  - 필드는 스키마에서 생성하되 필드 종류마다 별도 `.tscn`(슬라이더·색·토글·선택 버튼 그룹·문장)을 인스턴싱한다.
  - 콤보 리스트 대신 버튼 그룹을 쓰고, 선택지가 많은 항목(효과·이징·글꼴)은 미리보기 카드가 있는 팝업으로 연다.
  - 효과 카드는 TextFxPlayer를 지연 인스턴싱해 실제 블러·전체 마스크·글로우를 보여준다. 보이는 카드만 굽고, hover/포커스 때 seek 시간이 진행한다.
    비활성 카드는 대표 시점에 멈추며 팝업이 숨겨지면 처리도 멈춘다. 이징 카드는 곡선 그래프를 유지한다.
- 글꼴: 번들 글꼴, 시스템 글꼴 목록(검색), 사용자 글꼴 파일 불러오기(user://fonts 에 복사, 경로 참조).
- 단축키(물리 키): Space 재생/정지, Home 처음으로, Ctrl+Z / Ctrl+Shift+Z 실행 취소/다시, Ctrl+S 저장, Ctrl+E 내보내기, Ctrl+Shift+C 문서 문자열 복사.
- UI 문자열은 `tr()` + `app/i18n/ui.csv`(ko, ja, en).
- 상태 자동 저장: `user://autosave.json`.

## 8. 앱 셸 (app/shell, game_base)

- 부트(로딩) → 타이틀 → 에디터. 타이틀 시작 버튼이 에디터 씬을 연다.
- 옵션: 프레임 제한(기본 60), 마스터/BGM/효과음 음량, BGM 켜기, 언어(ko/ja/en). 실제 적용 코드가 있는 옵션만 노출한다.
- 프로파일러: 공용 운영 서버의 `/v1/reports`에 프로젝트 `godot-text-fx`로 수동 전송한다. `base_project.tres`에서 활성화·endpoint를 설정하며, 비활성 또는 유효하지 않은 설정이면 연결하지 않는다. 보고서 조회는 `tools/profile_reports.py` 래퍼를 사용한다(`docs/PROFILE_REPORTS.md`).
- 빌드 정보: `addons/game_base/tools/stamp_build.py`로 `build_info.json` 생성, 타이틀·옵션에 표시.
