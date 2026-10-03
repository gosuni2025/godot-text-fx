# 오디오 출처

## BGM

### `bgm/above_the_clouds_loop.ogg`

- 곡: "Above The Clouds" (Intensity 1 버전), Ambient Music Pack Vol. 5
- 제작자: Ovani Sound (https://ovanisound.com)
- 원본 경로: `~/assets/ovanisound/ogg/Ambient Vol5 Music Pack/Above The Clouds (RT 4.0)/Ambient Vol5 Above The Clouds Intensity 1.ogg`
  (같은 팩의 WAV를 라이브러리의 `convert.bat`로 변환한 OGG; 원본 MP3 폴더 `~/assets/ovanisound/Ambient Vol5 Music Pack/`)
  - 원본 SHA-256: `bb9e571ba680464da2153281a2af86ec25b71a7b839b8e824adbc7b99c7351f4`, 48 kHz 스테레오, 84.000초
- 라이선스: Ovani Sound Royalty-Free License. 팩 폴더의 `Royalty-Free License (Link).pdf`가
  https://ovanisound.com/policies/terms-of-service 를 가리킨다(2026-10-03 확인).
  - 게임·제품 등 상업/개인 프로젝트에 포함해 사용 가능, 크레딧 선택 사항.
  - 음원 파일 자체를 단독으로(작품과 분리해) 재배포·판매·재라이선스하는 것은 금지.
    저장소를 공개하거나 음원을 따로 배포할 때는 이 조건을 다시 검토한다. AI 학습 사용 금지.
- 가공 내역(2026-10-03, ffmpeg 8.0.1 + oggenc):
  1. 파일명의 RT 4.0(잔향 꼬리 4초)에 맞춰 루프 지점을 3,840,000 샘플(80.000초)로 잡았다.
  2. 마지막 4초(잔향 꼬리)를 처음 4초에 그대로 더해(overlap-add, 음량 정규화 없음) 이음매 없는 80초 루프를 만들었다.
  3. `oggenc -q 6`으로 다시 인코딩. 피치·속도·음량은 바꾸지 않았다.
     결과: 80.000초, mean −19.9 dB / peak −6.0 dB(클리핑 없음), 0.5초 이상 무음 구간 없음.
- 가져오기: `loop=true`(`.import`), 재생 버스 `BGM`.
