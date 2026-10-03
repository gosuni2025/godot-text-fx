# 아이콘 스타일 기준

모든 아이콘(템플릿·UI)은 아래 기준을 공유한다. 여러 에이전트가 병렬로 생성하므로 프롬프트의 스타일 문단은 그대로 복사해 쓴다.

## 공통 스타일 문단 (프롬프트에 그대로 포함)

> Minimal flat line icon, single pure white (#FFFFFF) glyph on a fully transparent background, uniform rounded stroke about 8% of the icon width, no fill except small solid accents, no text, no letters, no numbers, no gradients, no shadows, no frame or background shape, centered with generous padding, simple geometric silhouette readable at 32 pixels, consistent with a set of editor toolbar icons.

- 흰색 단색이라 Godot에서 `modulate`/`self_modulate`로 색을 입힌다.
- 글자·숫자를 그리지 않는다(언어 무관). 의미는 사물·기호로 표현한다.
- 생성은 여러 아이콘을 한 장에 격자로 배치(예: 3×3)해 같은 장 안에서 스타일을 맞추고, 잘라서 패키징한다.

## 패키징

- 런타임: `assets/icons/templates/<icon_id>.png`, `assets/icons/ui/<name>.png`
- 128×128, RGBA, 투명 배경, 내용 영역은 가운데 정렬·여백 약 12%. 알파가 실제로 투명인지 확인한다.
- 축소·잘라내기·흰색 정규화(알파 유지)만 허용하고 코드로 그림을 덧그리지 않는다.
- 원본 시트·전체 프롬프트·생성 도구·가공 내역은 `art/source/icons/`에 보존하고 `art/source/icons/SOURCES.md`에 기록한다.
