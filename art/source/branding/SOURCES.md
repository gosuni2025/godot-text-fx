# 타이틀·아이콘·로딩 스플래시

- 생성일: 2026-10-03
- 도구: Codex 내장 `image_gen` (기본 도구 모드). 세 자산을 서브에이전트로 병렬 생성했다. CLI/API 폴백 및 외부 참조 이미지는 사용하지 않았다.
- 생성 위치: 저장소 밖 `~/.codex/generated_images/`. 시각 검수한 완성본만 `assets/branding/`에 복사했다.
- 방향: `Lore.txt`의 자막 인쇄소와 회등 제도. 짙은 남청색, 황동 활자, 아이보리, 호박색 빛의 궤적을 공유한다. 타이틀·진행 문구는 이미지에 굽지 않고 기존 UI로 표시한다.

| 완성 파일 | 크기·형식 | 적용 위치 | 최종 프롬프트 |
| --- | --- | --- | --- |
| `assets/branding/title_background.png` | 1672×941, 불투명 RGB PNG | `base_project.tres`의 `title_background` | [prompt_title.txt](prompt_title.txt) |
| `assets/branding/loading_splash.png` | 1672×941, 불투명 RGB PNG | `base_project.tres`의 `loading_background`, `project.godot`의 `application/boot_splash/image` | [prompt_splash.txt](prompt_splash.txt) |
| `assets/branding/app_icon.png` | 1024×1024, 불투명 RGB PNG | `project.godot`의 `application/config/icon` | [prompt_icon.txt](prompt_icon.txt) |

## 생성 원본과 가공

- 타이틀: `01a10110-f3c3-7213-87f6-5b5c6954153a/exec-22e550ee-6d09-41e0-ab1e-c7507a291bb2.png`. 요청은 2048×1152였으나 실제 반환된 1672×941 원본을 그대로 사용했다.
- 로딩: `01a10111-29dd-7e02-b628-dcf5ad276417/exec-f026133b-c987-41b8-838c-4ca7cbd4f827.png`. 요청은 2048×1152였으나 실제 반환된 1672×941 원본을 그대로 사용했다.
- 아이콘: `01a10111-6aab-75c0-ab73-b6565f6558a6/exec-460c76cc-fb9a-4d85-bac8-c499ee11841f.png`. 실제 반환된 1254×1254 이미지를 macOS `sips -z 1024 1024`로 정규화했다. 크기 변경 외 덧그리기·색상 변경은 없다.
- Godot 텍스처는 기본 무손실 압축으로 가져왔다. 부팅 스플래시의 `stretch_mode=4`(Cover)는 기존 타이틀·로딩 배경의 비율 유지 채움 방식과 맞췄다. 웹 내보내기의 기존 `$GODOT_SPLASH`와 `html/export_icon=true`도 이 프로젝트 이미지를 사용한다.
- 원본 이미지는 모두 이번 작업에서 AI로 생성했다. 외부 사진·상표·폰트 파일을 이미지 제작에 사용하지 않았다.

## 확인

- Godot 4.7.2 실제 데스크톱 창, `--audio-driver Dummy`: 타이틀과 로딩을 1600×900 및 960×540에서 캡처해 문구·버튼·진행 표시가 보이고 주요 활자를 가리지 않는지 확인했다.
- 캡처: Git 제외 경로 `captures/branding/{title,loading}_{1600,960}.png`.
- 기존 `shell_flow` 검사 12개 통과: 부트 → 타이틀 → 옵션 → 편집기 → 타이틀 전환.
- 검수용 게임과 임시 캡처 스크립트는 종료·제거했다. 공용 애드온과 JSON 포맷 변경은 없다.
