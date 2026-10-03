# Godot Text FX 프로파일 보고서

공용 비공개 저장소 [godot-web-profiler](https://github.com/gosuni2025/godot-web-profiler)의
[연결 지침](https://github.com/gosuni2025/godot-web-profiler/blob/main/docs/GAME_BASE_INTEGRATION.md)과
[보고서 조회 지침](https://github.com/gosuni2025/godot-web-profiler/blob/main/docs/PROFILE_REPORTS.md)을 따른다.

- 프로젝트 ID: `godot-text-fx`
- 운영 서버: `https://dungeon-reign-profiler.gosuni2025.workers.dev`
- 업로드 endpoint: `/v1/reports`, 등록 상태: `/health`
- 현재 허용된 웹 Origin: itch.io 게임 iframe의 `https://html-classic.itch.zone`,
  `https://html.itch.zone`와 제작자 페이지 `https://gosuni2025.itch.io`, 로컬 `http://127.0.0.1:8877`.
  이 프로젝트의 별도 웹 배포 주소는 아직 지정되지 않았다.
- 클라이언트 설정: `base_project.tres`의 `project_id`, `profiler_enabled`, `profiler_endpoint`
- 앱 Source: `app/shell/shell_profile_source.gd`. 화면을 `boot`, `title`, `editor`, `other`로 구분한다.
- 옵션의 **프로파일 보내기** 버튼을 눌렀을 때만 전송한다. 테스트는 로컬 payload만 생성한다.

## 조회

공용 저장소를 기본 `../godot-web-profiler`에 두거나 `PROFILER_REPO`로 경로를 지정한다.
공용 저장소의 `server/`에서 `npm ci` 및 Wrangler 로그인을 완료해야 한다.
Node 22.13 이상이 필요하며, 자동 탐색이 실패하면 `PROFILER_NODE`에 실제 Node 경로를 지정한다.

```sh
python3 tools/profile_reports.py summary latest
python3 tools/profile_reports.py list -n 10
python3 tools/profile_reports.py fetch latest
python3 tools/profile_reports.py summary captures/profile-YYYYMMDD-ID앞8자.json
```

게임 래퍼는 공용 `tools/profile_reports.py`에 프로젝트 ID와 `captures/` 저장 경로를 전달한다.
공용 조회 코드를 복사하거나 임시 조회 스크립트를 만들지 않는다. `captures/`는 Git에서 제외한다.
추가 열이 필요하면 공용 도구의 `--column KEY=LABEL`을 사용한다. 기본 구간 표에 화면(`map_id`),
프레임 수·최장 프레임·단계별 시간·draw call·primitive가 포함된다.

다른 웹 Origin을 사용할 때는 실제 게임 iframe의 Origin을 공용 `server/src/projects.js`에
등록하고 배포한 다음 클라이언트를 배포한다. 주소창 URL과 iframe Origin은 다를 수 있다.
