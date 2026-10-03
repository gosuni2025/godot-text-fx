# 아이콘 출처

아이콘 생성 원본·프롬프트·도구·가공 내역. 기준은 `STYLE.md`.

## 템플릿 아이콘 A — 전투·탐색·진행자·판정 (`templates_a/`)

- 대상(19개): `assets/icons/templates/` 의 `tpl_battle_{ambush,boss,defeat,engage,turn,victory}`, `tpl_explore_{clue,door,item,tide,trap}`, `tpl_narrator_{choice,close,pause,secret}`, `tpl_check_{critical,success,failure,fumble}` (.png)
- 생성 도구: pixeltamer v0.6.0 스킬, codex 백엔드(codex CLI 0.160.0, ChatGPT 로그인)의 내장 `image_gen` 도구. 이미지 모델은 서비스 측에서 선택(GPT Image 계열). 옵션 `--background transparent --quality high`. 2026-10-03 생성.
- 프롬프트: 각 시트의 전체 프롬프트는 `templates_a/prompt_*.txt`에 그대로 보존. 모두 `STYLE.md`의 공통 스타일 문단을 그대로 포함한다. pixeltamer codex 백엔드가 투명 배경 지시문을 프롬프트 끝에 자동으로 덧붙인다.
- 원본 시트(실제 알파 채널이 있는 RGBA PNG):
  - `raw_sheet1_battle.png` (1536×1024, 3×2) — **미채택.** 선이 다른 시트보다 가늘고 세부(손, 털, 잔잎)가 많아 32px에서 뭉개지고 세트와 획 굵기가 맞지 않았다.
  - `raw_sheet2_explore_narrator.png` (1024×1024, 3×3) — door, item, tide, trap, choice, close, pause, secret 채택. 첫 칸 clue는 32px에서 발자국이 느낌표처럼 읽혀 미채택.
  - `raw_sheet3_check.png` (1024×1024, 2×2) — 판정 4종 채택.
  - `raw_sheet4_battle_v2.png` (1024×1024, 3×3) — 전투 재생성. sheet2·sheet3을 참조 이미지(`-i`)로 넣어 굵은 획과 단순도를 맞췄다. 채택: defeat, engage, turn, victory, clue(7번 칸, 발가락 점이 있는 발자국으로 재작성), ambush(8번 칸 두건+단검), boss(9번 칸 작은 사람 뒤에 드리운 뿔 달린 거대 실루엣). 1번 칸(초승달+단검)과 2번 칸(뿔 달린 얼굴, 귀여워 보임)은 미채택.
- 가공(`templates_a/slice_icons.py`): 알파 ≤12 잡음 제거 → 알파 투영의 빈 띠로 행·열 분리 → 아이콘별 알파 경계 상자 잘라내기 → 긴 변을 128×(1−2×0.12)≈97px로 LANCZOS 축소 → 128×128 투명 캔버스 가운데 배치 → RGB를 순백(255)으로 정규화하고 알파 유지, 축소 후 알파 ≤4는 0. 덧그리기 없음.
- 검증: 19개 모두 128×128 RGBA, 가장자리 알파 0, RGB 최솟값 255, 내용 여백 약 12%. 어두운 배경 대조표에서 128/32/24px와 색조(modulate) 적용 상태로 가독성·세트 일관성을 확인했다.

## 에디터 UI 아이콘 (`ui/`)

- 대상(47개): `assets/icons/ui/` 의 transport(`play, pause, stop, to_start, loop_once, loop_all, loop_hold, exit_on, exit_off`), edit(`undo, redo, add, remove, duplicate, move_up, move_down, close, back, search, randomize, settings, fullscreen`), file(`save, open, export, import, copy, paste`), tabs(`tab_mode, tab_text, tab_motion, tab_style, tab_font, tab_decor, tab_layout, tab_export`), modes(`mode_message, mode_trailer, mode_caption`), groups(`group_battle, group_explore, group_narrator, group_scene_time, group_check`), 미리보기 배경(`bg_checker, bg_color, bg_image`) (.png, 각 `.png.import` 포함)
- 생성 도구: pixeltamer v0.6.0 스킬, codex 백엔드(codex CLI 0.160.0, ChatGPT 로그인)의 내장 `image_gen` 도구. 이미지 모델은 서비스 측에서 선택(GPT Image 계열). 옵션 `--background transparent --quality high`, 크기 `1024x1024`(3×3 시트) 또는 `1536x1024`(3×2·3×1 시트). 2026-10-03 생성.
- 프롬프트: 시트별 전체 프롬프트를 `ui/prompts/sheet_{a..g}.txt`에 그대로 보존. 모두 `STYLE.md`의 공통 스타일 문단을 그대로 포함한다. pixeltamer codex 백엔드가 프롬프트 끝에 다음 투명 배경 지시문을 자동으로 덧붙인다: "Output the subject as an isolated element on a fully transparent background with a real PNG alpha channel. No backdrop, no background colour, no rectangle, no plinth, no surface, no cast shadow, no vignette, no watermark. Crisp alpha edges, no halo, no matte fringe."
- 원본 시트(`ui/sheets/`, 실제 알파 채널이 있는 RGBA PNG, 배경 알파 0):
  - `sheet_a.png` (3×3) — transport 9종 모두 채택.
  - `sheet_b.png` (3×3) — undo, redo, add, remove, duplicate, move_up, move_down, close, back 채택.
  - `sheet_c.png` (3×3) — search, randomize, settings, fullscreen, save, open, export, import, copy 채택.
  - `sheet_d.png` (3×3) — paste, tab_mode, tab_style, tab_decor, tab_export 채택. tab_text(캐럿이 작아 글자 I처럼 보이고 32px에서 사라짐), tab_motion·tab_font(획이 세트보다 가늘고 깃털 세부가 많음), tab_layout(점선이 가늘어 24px에서 뭉개짐)은 미채택.
  - `sheet_e.png` (3×3) — mode_message, mode_trailer, mode_caption, group_explore, group_narrator, group_scene_time, group_check, bg_checker 채택. group_battle(검 획이 가늘어 세트와 불일치)은 미채택.
  - `sheet_f.png` (3×2) — bg_color, bg_image 신규 생성과 tab_text, tab_font(깃털 없는 정면 펜촉), group_battle, tab_motion 재생성(굵은 획 지시 추가). 6종 모두 채택.
  - `sheet_g.png` (3×1) — tab_layout 재생성 3안. 1번 안(사각형을 지나는 굵은 가로·세로 가이드) 채택. 2번 안(왼쪽 정렬 막대)은 tab_text와 비슷하고 글자처럼 읽혀 미채택, 3번 안은 미채택.
- 가공(`ui/slice_icons.py`): 알파 8 미만 잔여 픽셀을 0으로 → 시트를 균등 격자로 잘라 칸별 알파 경계 상자 잘라내기(칸 경계 접촉 없음 확인) → 긴 변을 128×(1−2×0.12)≈97px로 LANCZOS 축소 → 128×128 투명 캔버스 가운데 배치 → RGB를 순백(255)으로 정규화하고 알파 유지. 덧그리기 없음.
- 검증: 47개 모두 128×128 RGBA, 네 모서리 알파 0, 불투명 픽셀 RGB 전부 (255,255,255), 내용 여백 약 12%. 어두운 배경 대조표에서 128/64/32/24px로 가독성·글자 미포함·세트 일관성을 확인했다.

## 템플릿 아이콘 B — 장면·시간·트레일러·장소/시간 테롭 (`templates_b/`)

- 대상(18개): `assets/icons/templates/` 의 `tpl_scene_{dawn,later,memory,night}`, `tpl_trailer_{all,flow,line,scroll,split,stamp,typewriter}`, `tpl_caption_{converge,corner,log,rise,split,tracking,vertical}` (.png, 각 `.png.import` 포함). 문자 모션 템플릿이므로 글자 대신 가로·세로 막대와 화살표로 동작을 표현했다.
- 생성 도구: pixeltamer v0.6.0 스킬, codex 백엔드(codex CLI 0.160.0, ChatGPT 로그인)의 내장 `image_gen` 도구. 이미지 모델은 서비스 측에서 선택(GPT Image 계열). 옵션 `--background transparent --quality high --size 1024x1024`(sheet5는 서비스가 1254×1254로 반환). sheet3·sheet4는 `-i raw/sheet2_v1.png`, sheet5는 `-i raw/sheet1_v1.png`를 스타일 참조로 넣었다. 2026-10-03 생성. sheet5는 저장소 밖(스크래치 폴더)에서 생성한 뒤 복사했다.
- 프롬프트: 시트별 전체 프롬프트를 `templates_b/prompt_sheet{1..5}.txt`에 그대로 보존. 모두 `STYLE.md`의 공통 스타일 문단을 그대로 포함한다. pixeltamer codex 백엔드가 투명 배경 지시문을 프롬프트 끝에 자동으로 덧붙인다. 실행 로그는 `raw/sheet*_v1.log`.
- 원본 시트(`templates_b/raw/`, 실제 알파 채널이 있는 RGBA PNG, 배경 알파 0):
  - `sheet1_v1.png` (3×3) — scene_dawn, scene_later, scene_memory, scene_night, trailer_all, trailer_flow, trailer_line, trailer_scroll 채택. 9번 칸(trailer_split)은 막대 없이 양방향 화살표만 그려져 '가로 크기 조절'로 읽혀 미채택.
  - `sheet2_v1.png` (3×3) — trailer_stamp, trailer_typewriter, caption_converge, caption_corner, caption_log, caption_split, caption_tracking 채택. caption_rise(위아래 화살표가 converge와 거의 같음)와 caption_vertical(짧은 가로 대시 격자라 세로쓰기로 읽히지 않음)은 미채택.
  - `sheet3_v1.png` (3×3, 행별 3안) — trailer_split·caption_rise·caption_vertical 재생성. 모두 미채택: split은 가로로 긴 띠라 32px에서 너무 작고, rise는 깔때기처럼 보이며, vertical은 아래쪽이 맞춰져 막대그래프·신호 세기 아이콘으로 읽혔다.
  - `sheet4_v1.png` (3×3) — 위쪽을 맞춘 세로 기둥 6안과 rise 3안. caption_vertical(1행 1열, 기둥 4개+위쪽 왼쪽 화살표), caption_rise(3행 1열, 막대 아래 위쪽 화살표+점선 궤적) 채택.
  - `sheet5_v1.png` (3×3) — 정사각형 구도의 split 6안과 물결 3안. trailer_split(1행 2열, 가운데가 갈라진 막대 4줄+바깥쪽 화살표) 채택. 물결 3줄 안은 템플릿 A의 `tpl_explore_tide`(물결)와 혼동되어 미채택하고 sheet1의 trailer_flow를 유지했다.
- 가공(`templates_b/package.py`): 알파 8 미만을 0으로 → 알파 투영의 가장 넓은 빈 띠로 행·열 분리 → 칸별 알파 경계 상자 잘라내기 → 긴 변을 128×(1−2×0.12)≈97px로 맞추되, 추정 획 굵기(2×면적/둘레)가 7px을 넘는 아이콘(typewriter, corner, vertical, rise)은 더 작게 축소해 세트의 획 굵기를 맞춤 → LANCZOS 축소 → 128×128 투명 캔버스 가운데 배치 → RGB를 순백(255)으로 정규화하고 알파 유지, 축소 후 알파 8 미만은 0. 덧그리기 없음.
- 검증: 18개 모두 128×128 RGBA, 네 가장자리 알파 0, 보이는 픽셀 RGB 전부 255, 글자·숫자 없음. 어두운 배경 대조표(128px·32px)에서 가독성과 템플릿 A·UI 아이콘과의 획 굵기 일관성을 확인했다.
