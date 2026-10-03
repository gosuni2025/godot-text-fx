# 수집 계약

Godot 4.7.2에서 검증한 클라이언트다. `profile_source.gd`가 게임의 수집 가능 상태와
선택적인 게임 샘플·viewport 참조만 제공한다. 네트워크는 `send_report()`를 호출할 때만 사용한다.
모듈은 저장 파일이나 자동 업로드를 만들지 않는다.

## 모듈이 직접 수집하는 값

| 위치 / 필드 | 단위 · 수집 시점 | 해석 |
| --- | --- | --- |
| `window.frame_count`, `duration_ms`, `active_elapsed_ms`, `mean_fps`, `max_frame_ms`, 느린 프레임 수 | 매 process 사이 실제 wall time, 최대 30초 | 일시정지·로딩·백그라운드 시간을 제외한 플레이 관측 |
| `window.samples`, `bucket_mean_ms_percentiles` | 20ms 버킷의 평균 프레임 시간 | 개별 프레임 백분위가 아님. 최대 1,501개 버킷 |
| `window.start_tick_ms`, `end_tick_ms`, `end_age_ms` | reporter 세션 기준 ms / 마지막 관측 이후 ms | 로그와 같은 시간 원점. 버퍼에는 원래 monotonic tick 보존 |
| `counters.interval_*` | 연속 구역별 프레임 수, 누적 ms, 최대 ms, 시작 시각 | 평균 FPS = frame_count / elapsed_ms × 1000. 전환 경계 프레임 제외 |
| `process_interval_peak_ms`, `physics_interval_peak_ms` | Performance 모니터를 1초마다 조회 | 엔진 갱신 구간의 최대치. 개별 프레임 시간이나 GPU 시간이 아님 |
| `draw_calls`, `primitives`, `render_objects` | 1초마다 최신 엔진 모니터 | 렌더 부하 단서. 최장 프레임 시점과 동일하다고 볼 수 없음 |
| `resources`, `nodes` | 개수, 1초마다 | 로드된 리소스·SceneTree 노드 수 |
| `memory_static_bytes`, `video_memory_bytes`, `texture_memory_bytes` | bytes, 1초마다 | 엔진/드라이버가 노출한 모니터. 미지원 플랫폼의 0은 실제 사용량 0을 보증하지 않음 |
| `viewport_px`, `world_px`, 선택 `weapon_viewport_px`, `post_viewport_px` | 실제 픽셀 크기, 1초마다 | 루트는 자동. 별도 viewport는 Source가 참조만 제공, 크기는 모듈이 읽음 |
| `scale_3d`, `max_fps`, `physics_ticks_per_second` | 배율 / FPS 제한 / Hz, 1초마다 | 측정 조건. 기본 world는 루트 viewport |
| `phase_physics_to_process_*` | ms / count | 첫 physics 신호 → process 신호, 한 렌더 프레임의 모든 물리 tick 포함 |
| `phase_process_to_pre_draw_*` | ms / count | process 신호 → pre_draw |
| `phase_pre_to_post_draw_*` | ms / count | pre_draw → post_draw, CPU wall time |
| `phase_post_draw_to_next_frame_*` | ms / count | post_draw → 다음 프레임 첫 경계. 브라우저 스케줄링·대기 포함 |
| `phase_physics_ticks`, `phase_work_max_ms`, `phase_work_over_16ms` | count / ms | 동일한 완성 렌더 프레임 집합. 작업 예산은 엄격히 >16ms, 다음 프레임 대기 제외 |
| `phase_peak_render_frame`, 선택 `phase_peak_work_frame` | frame_id, 실제 tick 수, physics/process/render/gap ms | 같은 한 프레임의 분해. 독립 최댓값의 합이 아님 |
| `physics_*_nodes_ms`, `process_*_nodes_ms` | before/nodes/after ms, 피크 프레임 내부 | 웹의 기본 process group에서만 수집. 우선순위 충돌·별도 group이면 생략, 순수 solver 시간 아님 |
| 선택 콜백 roots와 `root_call_counts` | ms / count, 피크 프레임 내부 | 게임이 선언한 독립 동기 콜백만 계측. physics/process를 포함한 전체 frame work의 일부 |
| `build.version`, `build.label` | 보고서 생성 시 | `res://build_info.json`의 version, 없으면 DEV. label은 설정 가능 |
| `runtime.engine`, `os`, `renderer`, `driver`, `max_fps`, `render_path` | 보고서 생성 시 | 렌더 경로 이름은 게임 설정 |
| `runtime.profiling` | 고정 메타데이터와 유실 수 | 해석 규칙, measurement_schema_version, 로그 버퍼 유실 수 |
| `runtime.browser.user_agent`, `dpr`, `canvas_px`, `canvas_css_px`, `visibility` | 보고서 생성 시 | 브라우저 식별 문자열 최대 512자, 렌더/CSS 크기 |
| `runtime.browser.navigator_platform`, `max_touch_points`, `screen_css_px` | 보고서 생성 시 | 플랫폼 문자열 최대 64자, 동시 터치 수, 화면 CSS 크기. iPad의 데스크톱 UA와 Mac을 구분하는 단서이며 정확한 기기 모델을 뜻하지 않음 |
| `runtime.browser.webgl_renderer`, `texture_compression`, `compressed_texture_formats` | 보고서 생성 시 | GPU 렌더러 문자열 최대 256자, 압축 지원/포맷 최대 64개 |
| `runtime.browser.frame_timing` | 완료한 RAF 사이 최대 30초 활성 구간, 8,192행 상한 | callback 간격/CPU wall/before-first/marked-work/after-post/outside/RAF timestamp 분포, FPS, 히스토그램 |
| `frame_timing.native_calls` | 16ms 초과 RAF 중 최대 8개 | WebGL 리소스·컴파일·조회/오디오 버퍼/Wasm Memory.grow 동기 API 비용. draw hook 없음, 데이터 버퍼 미보관 |
| `native_calls.shader_frames` | 최대 8개 shader 그룹 | 컴파일·링크·조회 횟수/비용, 해시·고정 식별자 후보. 소스 원문 미전송, 특정 material의 원인 확정 아님 |
| `runtime.browser.gpu_timing` | 최대 초당 1번, 최근 wall 30초 | WebGL2 timer query 지원 시 pre→post GPU 타임라인 span. 비동기 조회, busy wait 없음. compositor/scanout 제외 |
| `logs` | 최대 128개 | 고정 이벤트 코드·허용된 scalar 필드만, 각 data 최대 16개 |
| `engine_error` | Logger 오류 콜백 → 다음 drain | 오류 종류·라인·안전한 res:// 경로/함수. 오류 원문·stdout·stack 미수집 |
| `slow_frame` | 1초 구간당 ≥100ms 최대 inter-process 프레임 | 종료 관측 시각/구역. 게임의 typed slow_sample을 선택적으로 추가 |
| `slow_work_frame` | ≥100ms physics+process+render 완성 프레임 | 같은 프레임의 분해와 가장 큰 선택 콜백. 로그 시각은 구간 종료 시각 |

`phase_*`는 `_mean_ms`, `_max_ms`, `_count`로 직렬화한다. 미완성 프레임, map 교체,
pause/loading/visibility 전환, 누락된 draw 경계는 제외한다. 측정이 없으면 평균/최대는
null, count는 0이다. 물리 tick 0은 연속된 렌더 프레임에서만 실제 0으로 기록한다.
headless 검증은 GPU/렌더 성능을 증명하지 않는다. GPU 미지원은 `reason`과 null 통계로 구분한다.

일반 pause는 이전 플레이 기록을 보존한다. focus/visibility 전환은 기록을 비운다.
맵 전환 시 이전 맵의 부분 구간에는 프레임 합계만 남기며 새 맵의 엔진 카운터를 붙이지 않는다.
GDScript 창과 RAF 창은 집계 경계가 다르므로 두 평균을 단순히 빼지 않는다.

## 선택 상세 계측

`Config.detailed_diagnostics = true`일 때 다음 값을 모듈이 수집한다. 게임이 전달하는 것은
고정 작업 레이블과 뷰포트 참조뿐이다. 반드시 상세 웹 번들을 함께 포함한다.

| 필드 | 단위 · 시점 | 의미 |
| --- | --- | --- |
| `sample_span_ms` | ms, 1초 구간 종료 | 실제 수집 구간 길이 |
| `phases.{physics_to_process_ms,process_to_pre_draw_ms,pre_to_post_draw_ms,post_draw_to_next_frame_ms}` | mean/p95/max ms와 count | 기존 구간별 신호 쌍 분포, phase당 최신 2,048개까지. `phase_*`의 동일 완성 프레임 집합과 다르며 GPU 시간이 아님 |
| `renderer.{setup_cpu_ms,root_cpu_delayed_ms,<label>_cpu_delayed_ms}` | mean/max ms와 count | 완료 렌더 프레임의 CPU 시간, GLES3 측정은 지연될 수 있음 |
| `render_passes.{visible,shadow,canvas}` | [draw calls, objects, primitives] | 마지막 완료 루트 viewport의 패스별 통계, 구간 평균 아님 |
| `objects`, `viewport_count`, `playing_audio` | 개수, 구간 종료 | 엔진 객체·살아 있는 뷰포트·재생 중 오디오 노드 수 |
| `scene`, `paused`, `audio_latency_ms` | res:// 경로 / bool / ms | 현재 씬·pause 상태·출력 지연. 소리 끊김 측정 아님 |
| `render_target_px`, `viewport_raster_px`, `msaa_3d` | [px,px] / Godot enum | 전자는 호환용 texture 크기, 후자는 실제 루트 래스터 크기. MSAA 0/1/2/3=off/2x/4x/8x |
| `<label>_active`, `_render_target_px`, `_scale_3d`, `_msaa_3d`, `_draw_calls` | bool / px / 배율 / enum / 개수 | Source가 등록한 뷰포트를 모듈이 읽음. 부재 시 false/[0,0]/null/null/0 |
| `work.<fixed_label>` | calls/units 개수, total_ms/max_ms | 게임의 enum span을 모듈이 누적. inclusive 시간이므로 중첩 span 합산 금지. 호출 없는 항목은 생략 |
| `webgl.calls.<group>` | [count,total_ms,max_ms] | WebGL 함수의 메인 스레드 호출 시간. draw/state/shader/buffer/texture/framebuffer/readback/sync 그룹, GPU 실행 시간 아님 |
| `webgl`의 shader/program/query 요약 | 고정 enum·해시·제한된 최댓값 | 셰이더 소스/인자 버퍼/자유 문자열을 보내지 않음. wrapping 오버헤드를 빼지 않음 |
| `runtime.browser.render_profiler` | 보고서 생성 시 | hook 설치 상태와 지원 함수. 상세 모드 전용 |
| `runtime.browser.hardware_concurrency`, `device_memory_gb`, `webgl_context`, `long_tasks_*` | 보고서 생성 시 | 공개 브라우저 기능/설정. 미지원 값은 null. longtask 관측기는 설치하지 않음 |

상세 모드에서도 `runtime.browser.frame_timing`과 지원되는 `gpu_timing`을 수집한다.
기본 모드 전용 `frame_timing.native_calls`의 RAF별 함수/셰이더 원인 분석 대신
`counters.webgl`의 구간별 요약을 사용한다. 두 wrapper를 중복 설치하지 않는다.
부분 구간이 맵·로딩·일시정지·수동 보고서 생성으로 끝나면 live 상세 카운터는 제외하고
프레임 합계만 보존한다. 따라서 구간 종료 직전 1초 미만의 work/webgl은 보고서에 없을 수 있다.

## 게임이 반드시 정의할 것

1. `Config.project_id`, `endpoint`, `measurement_schema_version`: 서버 등록 ID, HTTPS 주소, 게임 측정 명세 버전.
2. `Source.host()`, `scope_node()`, `can_collect()`, `map_id()`: 플레이 수명, 맵 교체, 타이틀·로딩 제외 조건. pause/focus/visibility는 모듈이 처리한다.
3. 비용을 설명할 게임 값: 적/유닛 수, 지형·구역, 웨이브, 장착 장비, 카메라/효과 상태 등 게임별 선택. 게임 데이터 전체를 넘기지 않는다.
4. 각 값의 타입, 단위, 수집 시점, 허용 코드/범위, 선택/미지원 의미. 값 0과 측정 없음은 구별한다.
5. 필요한 경우 viewport 참조와 독립 콜백 enum. 엔진 통계/화면 크기를 게임에서 재계산하지 않는다.

`MeasurementSample`의 subclass에 `int`, `float`, `bool`, `Vector2`, `Vector3i`, enum,
중첩 sample 속성을 선언하고 `metrics() -> Array[Metric]`에 명시한다. Dictionary는
직렬화 경계에서만 만든다. 등록하지 않은 속성은 수집하지 않는다. 잘못된 enum, 음수 개수,
NaN/Infinity, 중첩 오류가 있으면 그 게임 샘플 전체를 제외하고 `invalid_measurement`와
오류 개수만 기록한다. core 엔진 값은 게임 샘플로 덮어쓸 수 없다.
타입은 GDScript의 정적 검사이고, enum 범위·유한수·허용 코드·개인정보 필드 제한은 런타임 검증이다.
서버의 공용 schema 검사는 크기·구조 검사이며 게임의 의미·개인정보를 자동 판별하지 않는다.

측정 명세는 `schema/measurement_docs.gd`의 `table(sample)`로 생성할 수 있다.
반드시 게임별 설명과 함께 버전 관리한다. 새 항목이 어떤 비용 가설을 검증할지 적고,
키보드 입력·세이브·사용자 경로·URL/query·토큰·자유 입력·오류 원문은 넣지 않는다.

## 전송과 한도

schema_version=1, profile/log. 기본 전송은 gzip 압축 JSON
(`Content-Type: application/vnd.godot-web-profiler.report+gzip`)이며 압축 본문 최대 65,536 bytes,
압축을 푼 UTF-8 JSON 최대 524,288 bytes다. 최대 30 counter, 128 log, 20ms window 버킷 최대
1,501개(수집 버퍼 크기와 같다). 한도를 넘으면 오래된 로그 → 오래된 counters 순서로 줄이고
`runtime.upload_trimming`에 개수를 남긴다. 최신 slow_work_frame(또는 log 보고서의 마지막
진단)은 보호한다. 여전히 크면 전송을 거절한다. `upload_trimming.encoding`은 `gzip`/`json`,
gzip이면 `json_bytes`(압축 전 JSON)와 `gzip_bytes`(전송 본문)를 함께 기록한다.

gzip을 모르는 구 서버가 415(또는 압축 해제 실패 400)로 거절하면 같은 UUID 보고서를
64KiB 일반 JSON으로 다시 줄여 **한 번** 자동 재전송한다(시도 횟수 증가 없음,
`upload_trimming.gzip_rejected: true`). 1인자 transport(`func(body: String)`)는 기존처럼
일반 JSON 문자열만 받는다. 2인자 transport는 `(body: PackedByteArray, content_type: String)`이다.

전송 timeout 15초, 응답 본문 최대 16KiB, 리다이렉트 0회. 동시 요청은 하나다.
사용자가 직접 누르는 최대 3회 시도 동안 본문과 UUID는 동일하다. 응답의 project/UUID/type을
검증해야 성공이다. 재시도 가능한 보고서가 남았을 때 다른 project로 바인딩을 바꾸지 않는다.

## 선택 콜백과 느린 프레임 필드 연결

`Source.create_root_probe() -> Roots`에서 `Roots.new(PackedStringArray(["ai_update_ms", ...]))`를
반환하고, `root_nodes()`를 같은 enum 순서로 지정한다. 대상 Node에는
`var performance_roots: RefCounted`가 필요하다. 콜백 앞뒤의 usec와 active_token을 받아
`record(MySlot.AI_UPDATE, token, start, end)`로 기록한다. 중첩·비동기 호출은 허용하지 않는다.
별도 probe subclass의 typed enum wrapper로 호출부를 강타입화할 수 있다.
`begin_slot(slot)` / `end_slot()`은 조기 return/await 없는 단일 콜백용이다.

게임별 `slow_sample()`에 추가하는 scalar 이름은 `diagnostic_keys()`에도 명시한다.
interaction enum 코드가 있으면 `interaction_codes()`로 허용 목록을 반환한다.
이 목록은 typed sample의 `metrics()`와 enum에서 생성하여 중복 정의하지 않는 편이 좋다.
