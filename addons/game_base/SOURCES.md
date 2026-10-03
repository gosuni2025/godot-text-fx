# 출처

- `ui/title_run_sweep.gdshader`: 사용자 소유 Dungeon Reign의
  `shaders/ui/title_run_sweep.gdshader`를 그대로 가져왔다.
  원본 Git revision: `d9e140c1d0107ee301a69005a9f9a4e727eda272`.
  SHA-256: `b3ae2187e96489e483238f1209c76349ffe51942841c24141b585da26db84a88`.
  CanvasGroup의 글자 알파에 금속색·빛줄기·파편·찢김을 합성한다.
  실행/크기 조절 코드는 `ui/wordmark.gd`로 독립시켰으며 원본 게임 코드·에셋은 포함하지 않는다.
- `fonts/Galmuri11.ttf`: Galmuri, SIL Open Font License 1.1.
  동봉된 `fonts/LICENSE.txt`를 함께 배포한다. 기존 Sideways의 같은 원본에서 복사했다.
- 로딩 단계/상세 진행과 부트 흐름은 Sideways 구현에서 추출했다.
  게임별 음원·파편·전투 준비 함수는 포함하지 않는다.

이 모듈은 게임 배경·캐릭터·아이콘·음원·세이브를 포함하지 않는다.
