# 최근 검색어 저장과 삭제

- 최초 기록일: 2026-10-22
- 영역: 기능
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-b7ba8549412c0475"></a>

### 실제 최근 검색어 저장·삭제 (2026-10-22)

<a id="b-c05012a42dcb648e"></a>

검색은 기존 API를 사용하며 최근어만 별도 기기 저장소에 보관한다. `SearchHistoryStorage`를 `AppDependencies`/`ClipbackApp`에 선택적으로 주입할 수 있고 기본은 shared_preferences다. API 환경·서버 사용자ID별로 최대5개를 최신순 저장하며 제출 실패/결과0도 기록한다. 개별 삭제·재진입·앱 재실행 복원을 지원하고 로그아웃 후 같은 계정으로 로그인하면 복원한다. 게스트 동일ID 승격은 유지하고 다른 계정의 기록은 합치지 않는다.

<a id="b-21bf24342a116154"></a>

ID 미확인은 현재 세대의 임시 기록만 사용한다. 지연 읽기는 제출/삭제 작업을 재적용하고 쓰기는 계정별로 직렬화한다. 저장 장애는 검색을 막지 않고 다음 명시적 작업/검색 재진입에서 재시도하며 새 오류 UI는 추가하지 않는다. 서버 동기화·자동완성·전체 삭제·새 확대 맞춤은 후속이다.

<a id="b-b20922fd4d89a85e"></a>

- 전체 `flutter test --no-pub` **1731건 통과**, `flutter analyze --no-pub` 문제0. 새 검사23건을 포함하며 기존 확대/인증/검색 회귀를 유지했다.
- `test/support/search_history_preview.dart`는 실제 ClipbackApp과 메모리 HTTP/세션/공유 대역을 사용한다. native preferences만 검증 전용 prefix로 실제 저장하며 앱 OS 프로세스 재시작 복원을 양 플랫폼에서 확인한다. 기존 `search_preview.dart`의 예제는 주입된 메모리 저장소로 격리한다.
- 실행: `flutter run --no-pub -t test/support/search_history_preview.dart --dart-define=HISTORY_PHASE=after`. 검증 HTTP는 기기의 loopback8777이며 Android에서만 소유 포워딩8778→8777을 사용한다. 제품 실행/출시는 계속 `-t lib/main.dart`를 명시한다.
- iPhone16/iOS18.6·Android13/API33 제스처 각21동작 통과, 프레임워크/비동기 오류0. [전후/Figma4쌍](/private/tmp/clipback-search-history-20261022/comparison-document.html)·[검증 요약](/private/tmp/clipback-search-history-20261022/verification-summary.json)·[iOS 영상](/private/tmp/clipback-search-history-20261022/after/ios/after.mp4)·[Android 영상](/private/tmp/clipback-search-history-20261022/after/android/after.mp4).

<a id="b-bd3cba669c6bba2e"></a>

Figma H01(`111:3991`)의 최신 확보 원본을 사용한다. 기존 취소/최근어14px 승인 기준과 OS 여백을 유지하고 예제/키보드 차이는 비교에 명시한다. 서버 API·실제 OAuth·운영 계정·실기기·원격 CI 검증과 로컬 대역/네이티브 저장소 검증은 별개다. 화면 증거·빌드·개인 preference 데이터는 Git에 포함하지 않는다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-31aaa2552a265dc1"></a>

### 2026-10-22 — 실제 최근 검색어 저장·삭제 연결

<a id="b-9fbc71f50cd426d5"></a>

- 기준0797901에서 `feature/search-history-persistence`로 분리했다. 제품의 예제5개를 제거하고 제출 시 실제 이력 저장·최신순/중복 제거/최대5개·개별 삭제·계정별 재진입/재실행 복원을 연결했다. 실패/0개도 기록하고 공백/입력만으로 기록하거나 조회하지 않는다.
- 로그아웃 후 계정별 보존, 동일ID 게스트 승격 유지와 다른 계정 전환 시 비병합을 확정했다. API 환경/서버ID 키, 세대/소유권 방어, 늦은 읽기 작업 재적용과 직렬 쓰기, 장애 시 메모리 유지·명시적 재시도를 적용했다. 토큰/이메일로 계정을 추정하거나 서버 API를 변경하지 않았다.
- 제품 변경 전 해시 gate·새 BEFORE4장과 예제 노출 재현1실패를 확보했다. 수정 후 새23건 포함 전체1731건 통과·분석0, 집중53/1배율38건 통과(기존34건 중복)를 확인했다. 기존 검색 프리뷰의 예제는 테스트 fixture/메모리 저장소로 주입하고 실제 개인 기록과 격리했다.
- iPhone16/iOS18.6·Android13/API33 제스처 각21동작 통과·프레임워크/비동기 오류0. 실제 플랫폼 저장 완료 후 OS 프로세스 종료/재실행 복원과 삭제·두 대역 계정 분리·키보드 왕복을 확인했다. 로그아웃/게스트/장애/늦은 응답은 자동 검사이며 실제 공급자 로그인으로 오인하지 않는다.
- [비교4쌍/영상2개](/private/tmp/clipback-search-history-20261022/comparison-document.html)·[실측/검증](/private/tmp/clipback-search-history-20261022/verification-summary.json). H01 컨텍스트/원본은2026-10-22 02:18:22.929~02:18:34.492 KST 호출/결과 구간에 재조회했다. 아이콘3개는 원본과 bytes 일치하며 예제4개/닫기/디자인 키보드와 실제 기록/취소/OS 여백 차이를 명시했다. 초기 도구/Android 최종 영상 프레임 진단은 별도 보존해 최종 성공 수에서 제외했다.
- UI-11의 실제 기기 기록만 완료 범위로 표시한다. 빈 기록/저장 오류의 새 디자인·서버 동기화·자동완성·전체 집계·운영 계정/서버·OAuth·실기기·원격 CI·새 확대는 후속이다. 제품 진입 `lib/main.dart`를 복원하고 소유 기기/프로세스/포워딩을 정리한다. 푸시/PR은 하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-671337429c24439a"></a>

### 2026-10-22 — UI-11 실제 최근 검색어 저장·삭제 연결

<a id="b-347f6ca829066cf7"></a>

- **기준/범위:** `0797901` → `feature/search-history-persistence`. 예제5개를 제품에서 제거하고 실제 제출 검색어를 기기에 저장한다. 기존 H01~H03 1배율 스타일·검색 API/페이지·상세 복귀·키보드/취소는 유지한다. 검색 전체 기능 완료나 운영 검증으로 표시하지 않는다.
- **사용자 확정:** 제출 시 기록하며 실패·결과0도 포함한다. 앞뒤 공백만 제거하고 내부 공백/대소문자는 보존한다. 최신순·정확히 같은 문자열 중복 제거·최대5개·개별 삭제를 적용한다. 로그아웃 후에도 API 환경/서버 사용자ID별로 보존하며 다른 계정에는 노출/병합하지 않는다. 같은 ID의 게스트 승격은 유지한다.
- **구조/실패:** 주입 가능한 `SearchHistoryStorage`·독립 Repository와 `SearchViewModel`을 연결한다. 기존 shared_preferences를 사용하되 인증 저장소와 키를 분리한다. 계정별 직렬 쓰기·늦은 읽기 이후 작업 재적용·계정 소유권/세대 방어를 적용한다. ID 미확인은 해당 세대 메모리만 사용하고 ID 확인 후 작업을 합친다. 쓰기 실패는 메모리를 유지해 다음 명시적 작업에서 재시도하며 읽기 실패는 디스크를 덮어쓰지 않고 다음 검색 진입에서 다시 읽는다. 앱 시작/검색을 저장 완료까지 지연하지 않는다.
- **원본/예외:** 현재 파일 H01 `111:3991`의 컨텍스트와 375×812 원본을 **2026-10-22 02:18:22.929~02:18:34.492 KST**의 도구 호출/결과 수신 구간에서 재확보했다(후속 브랜치/기기 조회도 포함한 구간, 파일 확보02:18:51). 검색16px·시계/삭제18px SVG3개는 새 원본과 로컬 bytes가 일치한다. Figma는 예제4개·닫기·디자인 키보드이고 제품은 승인된 취소/14px 통일·실제 최대5개와 실제 OS 표시를 유지한다. 빈 기록 전용 원본은 없으며 대체 화면을 만들지 않는다.
- **수정 전/자동 검사:** 제품 변경 전 lib 전체 해시 동일과 새 BEFORE4장을 확인했다. 새 화면의 예제5개 노출은 재현 검사1건 실패로 확인했고, 실제 검색 후 재진입에서도 예제가 복원됐다. 수정 후 집중53건과 빈/긴 기록의 실제 Pretendard iOS/Android×320/375px 1배율38건이 통과했다(두 실행의 기존34건은 겹친다). 새 검사23건 포함 **전체 Flutter1731건 통과**, `flutter analyze --no-pub` 문제0이다. 기존 확대·세션·검색·상세·안전 영역 회귀를 제거/skip하지 않았다.
- **네이티브:** iPhone16/iOS18.6·Android13/API33 제스처에서 각21동작의 스타일/레이아웃/동작/전체 판정 true, 프레임워크·비동기 오류0. 실제 플랫폼 저장 완료 뒤 OS 앱 프로세스를 종료·재실행해 복원하고 마지막 삭제·재진입도 확인했다. 실제 행 선택/삭제 탭, 실패/0개·최대5개·중복·계정A/B 분리·키보드 왕복을 포함한다. API/세션/공유는 대역이며 계정 전환은 대역 UID로 실제 루트를 재생성한 검사다. 로그아웃 보존·게스트 동일ID·늦은 응답·저장 장애는 자동 검사로 구분한다.
- **증거:** [3열 비교4쌍](/private/tmp/clipback-search-history-20261022/comparison-document.html)·[실측/동작/미디어 요약](/private/tmp/clipback-search-history-20261022/verification-summary.json)·[BEFORE gate](/private/tmp/clipback-search-history-20261022/before-gate.json)·[조회 시각](/private/tmp/clipback-search-history-20261022/figma/reference-manifest.json). 같은 기종/창/데이터/1배율·키보드 숨김·스크롤0으로 앱 원본을 보존하며 Figma의 키보드/안전 영역 차이는 설명한다. [iOS 영상](/private/tmp/clipback-search-history-20261022/after/ios/after.mp4)·[Android 영상](/private/tmp/clipback-search-history-20261022/after/android/after.mp4)은 전체 디코딩/PTS/시작·끝을 검사했다.
- **도구/미검증:** 초기 촬영 도구의 재생성 키·공유 대역 경고 준비를 교정한 뒤 최종 BEFORE를 다시 촬영했다. 범위 밖 메모리 공유 경고는 기존 나중에 버튼으로 닫은 준비를 전후 동일하게 사용했다. Android 최초 영상은 최종 화면 합성 전 종료되어 진단으로 보존하고 최종 프레임 대기 후 재녹화했다. 이전 시도는 최종 증거/성공 수에 포함하지 않는다. 검증 전용 preference prefix만 사용하며 개인 저장 데이터와 실제 네이티브 공유 큐는 조회/삭제하지 않는다. 서버 동기화·운영 계정/OAuth·운영 서버·실기기·원격 CI·새 확대/3버튼 검증은 이번 완료 범위가 아니다.
