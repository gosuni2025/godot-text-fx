# Godot Text FX 설계

문자 애니메이션 연출을 편집하는 에디터 앱과, 그 결과(JSON)를 게임에서 재생하는 런타임 애드온의 설계다.
기능 아이디어만 외부 도구에서 얻었고 구현·수치·문구는 모두 새로 설계한다(`AGENTS.md` 클린룸 규칙).

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
    fx_effects_enter.gd      # 등장/퇴장 효과 표
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

모든 first-party 파일은 20KB 미만으로 유지한다.

## 2. 데이터 포맷 (format_version 1)

문서는 JSON 객체 하나다. 누락 필드는 `TextFxDoc.normalize()`가 기본값으로 채운다.
알 수 없는 필드는 보존하되 무시한다. 색은 `"#RRGGBBAA"` 또는 `"#RRGGBB"` 문자열.

```jsonc
{
  "format": "text_fx", "format_version": 1,
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
    "sub": { "font_size": 40, "position": "below", "gap": 0.35 }  // above|below, gap은 em 비율
  },
  "font":     { "source": "bundled", "family": "Pretendard", "path": "res://assets/fonts/pretendard/Pretendard-Regular.otf", "weight": 700, "italic": false },
  "sub_font": null,                 // null이면 font 사용
  "style": {                        // 본문 스타일
    "fill": { "type": "solid", "color": "#FFFFFFFF",
              "gradient": { "angle": 90, "stops": [[0.0, "#FFFFFF"], [1.0, "#9FD8FF"]], "space": "block" } }, // block|glyph
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
    // type: underline | overline | band(텍스트 뒤 띠) | side_lines(좌우 수평선) | frame(사각 틀) | brackets(모서리 꺾쇠)
    // animate: none | fade | grow_center | grow_start
  ],
  "timeline": {
    "enter": { "effect": "fade", "order": "forward", "duration": 0.45, "stagger": 0.06,
               "easing": "cubic_out", "params": {} },
    "hold":  { "duration": 1.6, "effects": [ { "type": "shake", "amplitude": 2.0, "frequency": 18 } ] },
    "exit":  { "enabled": true, "effect": "fade", "order": "all", "duration": 0.35, "stagger": 0.0,
               "easing": "cubic_in", "params": {} },
    "page_gap": 0.25,               // 페이지 사이 공백(초)
    "loop": "once",                 // once | loop_all | loop_hold
    "scroll": null                  // trailer 스크롤: { "speed": 60 } 이면 블록 전체가 아래→위로 이동
  }
}
```

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

공백·줄바꿈은 rank를 차지하지 않는다(타자기 리듬 유지). 구두점 뒤 쉼(`params.punct_pause`, 초)을 줄 수 있다.

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
| rise | 아래에서 떠오르며 잔상 흐림 | distance, blur |
| blur | 잔상 흐림 + 투명도 | radius |
| spin | 회전 + 투명도 | angle |
| converge | 홀짝 글자가 위·아래에서 모임(본문 위/보조 아래 모드 포함) | distance, mode(alternate/role) |
| tracking | 자간이 넓게 퍼진 상태에서 좁혀짐 | spread |
| center_split | 줄 중앙에 약간 흩어져 겹친 상태에서 좌우 제자리로 | jitter |
| scatter | 시드 방향으로 흩어진 상태에서 모임 + 회전 | distance, angle |
| wipe | 글자 내부를 왼→오른쪽으로 드러냄(clip) | dir |
| typewriter | 즉시 표시 + 짧은 튐 | pop |
| glitch | 무작위 위치 튐·깜빡임이 잦아들며 정착 | intensity |
| center_stamp | 한 글자씩 화면 중앙에 크게 표시 → 쉼 → 전체 문장이 커다랗게 내려찍힘 | big_scale, hold_each, pause, slam_scale |

`center_stamp`는 글자별 효과가 아니라 시퀀스이므로 evaluator가 별도 경로로 처리하며,
중앙에 크게 그려지는 글자는 "오버레이 글자"로 출력한다(큰 글자 전용 스프라이트를 굽는다).

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
| color_cycle | 색조 순환 틴트 | period, saturation |

### 2.4 타임라인

- 페이지 p의 구간: `enter(p)` → `hold(p)` → `exit(p)`. 마지막 페이지가 아니면 퇴장은 항상 수행하고 `page_gap` 뒤 다음 페이지.
- `enter(p)` 길이 = 마지막 글자 지연 + duration. 장식은 자체 delay/duration을 등장 시작 기준으로 쓴다.
- `exit.enabled = false`면 마지막 페이지는 유지 상태로 끝난다(유지 효과는 계속 계산).
- loop: `once` 끝에서 정지, `loop_all` 전체 반복, `loop_hold` 등장 후 유지 구간을 무한 반복하고
  플레이어의 `finish()` 호출 시 퇴장으로 넘어간다(게임에서 "표시해 두다가 닫기" 용도).
- `scroll`이 있으면 페이지 구분 없이 블록 전체가 캔버스 아래에서 위로 speed px/s로 이동한다.

## 3. 런타임 계산 (core)

- `TextFxLayout.compute(doc, fonts) -> LayoutResult`
  - 글자마다 `{ index, char, role("main"/"sub"), page, line, word, pos(글자 박스 중심, 캔버스 좌표), advance, font_size, vertical_rotate(bool) }`.
  - 줄 정보 `{ page, role, rect, center }`, 페이지별 블록 rect, 최종 font_size(자동 축소 후).
  - 금칙: 줄머리 금지(、。，．・：；？！ー）」』】〉》〕…‥ 등과 닫는 괄호류), 줄끝 금지(（「『【〈《〔 등 여는 괄호류). 한국어·영어는 공백 단위 단어 유지(keep-all), 단어가 한 줄보다 길면 글자 단위로 자른다.
  - 세로쓰기: 열은 오른쪽→왼쪽. 장음·괄호·대시류는 회전(vertical_rotate) 또는 세로형 문자로 대체하고, 작은 가나·구두점은 오른쪽 위로 보정한다. 라틴 문자는 회전 처리.
  - 자동 축소: max_width/max_height를 넘으면 font_size를 줄여 다시 배치(min_font_size까지).
- `TextFxTimeline.new(doc, layout)`: total_duration, 페이지·구간 경계, 글자별 지연을 미리 계산.
- `TextFxEvaluator.evaluate(t) -> Array[GlyphState]`
  - GlyphState: `{ index, visible, pos, scale(Vector2), rotation, alpha, tint(Color), clip(0~1 드러난 비율), clip_dir, ghost(잔상 흐림 반경), slices(글리치 조각 오프셋 배열), split(색수차 px), overlay(bool), overlay_scale }`.
  - 순수 함수: 같은 doc·t → 같은 결과. 노드·Engine 시간·전역 난수를 쓰지 않는다.
- `TextFxHash.f(seed, a, b) -> float [0,1)`: 정수 해시(예: PCG/xxhash 계열 비트 연산).

## 4. 렌더링 (render)

- 글자 하나 = 스타일이 모두 합성된 스프라이트 하나. 페이드 중에 테두리·그림자가 본문 아래로 비치지 않도록,
  글로우·그림자·2차 테두리·테두리·채우기를 글자 단위로 먼저 합성해 굽고, 재생 중에는 스프라이트 하나에 투명도를 준다.
- `FxGlyphBaker`: 글자 인스턴스마다 셀(패딩 = 테두리 + 글로우 + 그림자 오프셋 + 블러 여유)을 배정해
  SubViewport 아틀라스에 그린다(UPDATE_ONCE).
  1) 실루엣 뷰포트: 글로우·그림자용 실루엣 → 블러 셰이더로 흐린 텍스처
  2) 합성 뷰포트: 흐린 글로우/그림자 + 2차 테두리 + 테두리 + 채우기(그라데이션 셰이더는 블록 좌표 기준 uniform)
  - 그라데이션 `space: block`이면 글자의 블록 내 위치를 반영해 셀마다 같은 그라데이션이 이어지게 한다.
  - 아틀라스가 최대 크기(4096)를 넘으면 여러 장으로 나눈다. 텍스트·스타일·크기가 바뀔 때만 다시 굽는다.
- `TextFxPlayer`(Control):
  - `load_file(path)`, `set_document(dict)`, `set_text(main, sub := "")`, `play(from := 0.0)`, `stop()`, `seek(t)`, `finish()`, `is_playing()`, `get_duration()`
  - 속성: `document_path`, `autoplay`, `fit`("contain"/"cover"/"none"), `speed`, `paused`.
  - 신호: `started`, `entered`(등장 완료), `page_changed(page)`, `exit_started`, `finished`, `looped`.
  - `_draw()`에서 evaluator 결과대로 스프라이트를 그린다(`draw_set_transform` + `draw_texture_rect_region`, clip은 소스·대상 사각형 축소, 글리치 조각은 수평 띠 단위 분할 그리기, 색수차는 color_a/b 틴트 두 번 + 본체).
  - 장식은 플레이어가 직접 그린다(`draw_rect`/`draw_line`, use_outline이면 테두리 색으로 두껍게 먼저 그림).
  - 시간 진행은 `_process(delta) * speed`. 게임이 일시정지하면 `process_mode`를 따른다.
- 폰트 해석(`FxFont`): `bundled`/`path` → `load(path)`(res:// 또는 user:// 파일은 `FontFile.load_dynamic_font`), `system` → `SystemFont`(font_names=[family], font_weight, font_italic).
  해석 실패 시 `ThemeDB.fallback_font`. 굵기는 SystemFont는 weight, 파일 폰트는 `FontVariation.variation_embolden`으로 근사한다.

## 5. 내보내기

1. **문서 JSON**(기본): 위 포맷 그대로. 게임은 `TextFxPlayer`로 재생하며 텍스트를 실행 중에 바꿀 수 있다.
2. **베이크 JSON**(엔진 비의존): `{ "format": "text_fx_baked", "format_version": 1, "fps", "canvas", "duration", "loop",
   "glyphs": [{ "index", "char", "role", "font_size", "base": [x, y] }], "frames": [[[dx, dy, sx, sy, rot, alpha], ...], ...] }`
   — 값은 소수 셋째 자리 반올림. 다른 엔진에서 글자 배치·변환만 재생할 때 쓴다.
3. 클립보드 문자열: `TFX1:` + base64(deflate(JSON)) 한 줄. 문서·조작 기록 모두 같은 방식.

## 6. 에디터 로직 (app/logic)

- `EditorModel`: 현재 문서(dict), 재생 상태(time, playing), 선택 상태. `apply(command) -> bool`만으로 바뀐다. 신호 `changed(paths)`.
- 명령은 `{ "op": ..., ... }` dict. 예: `set {path:"style.outline.size", value:8}`, `set_text {text, sub_text}`,
  `apply_template {id}`, `set_mode {mode}`, `load_doc {doc}`, `seek {t}`, `play`, `pause`, `set_locale {locale}`,
  `undo`, `redo`, `export {kind}`(결과는 model.last_export에 저장).
- 실행 취소/다시 실행은 문서 변경 명령만 대상. 연속된 같은 path의 set은 하나로 합친다(슬라이더 드래그).
- `OpLog`: 적용된 명령 목록 + 시작 문서 + 시드. `serialize() -> String`(`TFX1:` 형식), `parse(String)`.
- `Replay`: OpLog를 새 모델에 다시 적용. 결과 문서·내보내기 해시가 같아야 한다.
- `EditorBot`: 시드로 결정되는 봇. 템플릿 선택·값 변경·재생/탐색·내보내기를 명령으로 수행하고 OpLog를 남긴다. 테스트와 AI 조작용.
- 템플릿: `app/logic/templates/*.json` 또는 GDScript 표. 모드·분류(전투/탐색/진행자/장면·시간/판정)·아이콘 id·견본 문장(ko/ja/en, `Lore.txt` 세계관)·문서 패치(기본값과의 차이)·loop 기본값.

## 7. 에디터 UI (app/editor)

- 왼쪽: 미리보기(체커보드/단색/사용자 이미지 배경, 캔버스 비율 유지) + 재생 바(재생/일시정지, 처음으로, 시간 스크럽, 반복 방식, 퇴장 켜기).
- 오른쪽: 탭(모드·템플릿 / 문장 / 연출 / 스타일 / 글꼴 / 장식 / 배치 / 내보내기).
  - 필드는 스키마에서 생성하되 필드 종류마다 별도 `.tscn`(슬라이더·색·토글·선택 버튼 그룹·문장)을 인스턴싱한다.
  - 콤보 리스트 대신 버튼 그룹을 쓰고, 선택지가 많은 항목(효과·이징·글꼴)은 미리보기 카드가 있는 팝업으로 연다.
- 글꼴: 번들 글꼴, 시스템 글꼴 목록(검색), 사용자 글꼴 파일 불러오기(user://fonts 에 복사, 경로 참조).
- 단축키(물리 키): Space 재생/정지, Home 처음으로, Ctrl+Z / Ctrl+Shift+Z 실행 취소/다시, Ctrl+S 저장, Ctrl+E 내보내기, Ctrl+Shift+C 문서 문자열 복사.
- UI 문자열은 `tr()` + `app/i18n/ui.csv`(ko, ja, en).
- 상태 자동 저장: `user://autosave.json`.

## 8. 앱 셸 (app/shell, game_base)

- 부트(로딩) → 타이틀 → 에디터. 타이틀 시작 버튼이 에디터 씬을 연다.
- 옵션: 프레임 제한(기본 60), 마스터/BGM/효과음 음량, BGM 켜기, 언어(ko/ja/en). 실제 적용 코드가 있는 옵션만 노출한다.
- 프로파일러: endpoint가 설정되지 않으면 연결하지 않는다(다른 게임의 운영 주소를 복사하지 않음).
- 빌드 정보: `addons/game_base/tools/stamp_build.py`로 `build_info.json` 생성, 타이틀·옵션에 표시.
