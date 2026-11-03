# frontend 바로 아래의 쓰지 않는 디자인 SVG 7개 삭제

최초 기록일: 2026-11-03 KST. 이슈 [#213](https://github.com/clip-back/clipback/issues/213), 시작 커밋 `c7488da`,
작업 브랜치 `chore/remove-unused-design-svgs`.

## 문제와 결정

- `frontend/` 바로 아래에 앱이 쓰지 않는 디자인 SVG 7개(합계 3,743,250바이트)가 있었다. 모두 초기 세팅 커밋 `4033b4a`에서 들어온 뒤 바뀐 적이 없다.
- 2026-11-03 사용자 결정: 지운다. 필요하면 Git 이력(`4033b4a`)에서 되살린다.

## 변경 내용

`git rm`으로 아래 7개만 지웠다. `frontend/design_cache/`, `frontend/assets/`, 플랫폼 아이콘·시작 화면 이미지는 그대로다.

| 파일 | 크기(바이트) |
| --- | --- |
| `frontend/App Icon.svg` | 6,796 |
| `frontend/온보딩1.svg` | 646,436 |
| `frontend/온보딩2.svg` | 440,548 |
| `frontend/온보딩3.svg` | 389,308 |
| `frontend/허투루_흰배경_검은글씨.svg` | 6,742 |
| `frontend/허투루아이콘1.svg` | 1,132,269 |
| `frontend/허투루아이콘2.svg` | 1,121,151 |

되살릴 때는 저장소 루트에서 `git checkout 4033b4a -- "frontend/App Icon.svg"`처럼 경로를 지정한다.

## 지우기 직전 참조 재검색

- `c7488da`에서 추적 파일 전체(지울 7개를 뺀 1,025개)의 내용을 바이트로 읽어 찾았다. `pubspec.yaml`, `frontend/lib`·`test`, iOS·Android·web 설정, 문서, 스크립트, CI가 모두 포함된다.
- 검색어: 확장자를 뺀 이름(`App Icon`, `App%20Icon`, `App_Icon`, `온보딩1`, `온보딩2`, `온보딩3`, `허투루_흰배경_검은글씨`, `흰배경_검은글씨`, `흰배경`, `검은글씨`, `허투루아이콘`). 한글은 NFC·NFD 양쪽과 URL 인코딩 형태도 찾았다.
- 결과: 참조 0건. `frontend/pubspec.yaml` 자산 목록은 `assets/figma/`, `assets/icons/`, 폰트 라이선스 파일만 등록해 `frontend/` 바로 아래 파일은 앱 번들에 들어가지 않는다.
- `assets/`·`design_cache/` 밖에서 `.svg`가 나오는 줄은 `assets/` 아래 자산의 파일 이름(`splash-a01-logo.svg`, `detail-back.svg`, `instagram.svg` 등)이나 저장소 밖 로컬 경로였다. 7개 파일과는 무관하다.
- macOS의 `git grep`에 NFD 검색어를 넘기면 NFC와 같은 결과가 나와, NFD 검색은 파이썬으로 파일 바이트를 직접 비교했다.

## 자동 검사

- `python3 ~/.heoturu-agents/verify.py --only app`을 삭제 커밋 `6cd5942`의 내용에서 돌렸다.
  `VERIFY result=PASS scope=app checks=3 failed=0`. `flutter pub get` 성공, `flutter analyze --no-pub` 문제 없음, `flutter test --no-pub` 2031개 통과.
- 백엔드는 바뀌지 않아 돌리지 않았다.

## 시뮬레이터·에뮬레이터 실행

- 하지 않았다. 지운 파일은 `pubspec.yaml` 자산 목록에 없어 앱 번들에 들어가지 않고 코드에서도 참조하지 않으므로 화면이 바뀌지 않는다.
