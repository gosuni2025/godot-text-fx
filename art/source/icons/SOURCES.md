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
