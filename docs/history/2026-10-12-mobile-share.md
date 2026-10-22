# 모바일 공유 수신과 로컬 서버 검증

- 최초 기록일: 2026-10-12
- 영역: 공유
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: backend/README.md

<a id="b-bd065ba1319d232b"></a>

### Verification on 2026-10-12

<a id="b-2511097820481719"></a>

- Full backend suite with a dedicated PostgreSQL 16 database: **986 passed, zero
  skipped, 81.32 seconds**. The one warning is the existing Starlette TestClient
  `httpx` deprecation warning. The run includes 26 new share cases covering token
  scope, parent-session revocation, retries, concurrency, file cleanup and safe
  Instagram redirect resolution; existing test scenarios and assertions remain.
- `ruff check app alembic tests`, `python -m compileall -q app alembic tests` and
  the backend diff whitespace check passed.
- Migration `202610120014` passed on an empty database and when upgrading from
  `202610110013`, using separate disposable databases. `alembic check` reported
  no new upgrade operations. Migration commands used
  `YOUTUBE_SUMMARY_ENABLED=false` because this local test setup uses no Gemini key.
- The loopback harness passed an actual HTTP guest login, share-credential issue,
  save and same-key replay against PostgreSQL; a share credential was rejected by
  the user-read route. External metadata, OAuth, AI and OCR were test replacements.
  These results do not verify production deployment or live provider responses.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-af9c6aec7a855c74"></a>

### 2026-10-12 — 모바일 공유 창에서 직접 저장

<a id="b-89dc60450280e90b"></a>

- 브랜치: `feature/mobile-share-intake`, 기준 `af31ea9`(`origin/main`, 상단 안전 영역 PR #55 병합).
  구현 전 정적 분석 무오류와 기존 Flutter 전체 테스트 **522 passed**를 새로 확보했다.
- iOS는 Swift/UIKit Share Extension, Android는 Java ShareActivity에서 링크·이미지 미리보기,
  저장 계정 확인, 저장·완료·닫기를 제공한다. 정상 외부 공유는 Flutter 엔진·본앱을 시작하지 않는다.
  본앱에서 대기 초안을 선택하면 같은 네이티브 UI를 모달/내부 Activity로 열고 원래 화면으로 복귀한다.
- 공유 전용 토큰은 본앱 access/refresh와 분리한다. 플랫폼 영속 revision으로 계정 전환을 차단하고,
  발급 응답·401·저장 완료의 지연 응답을 원래 계정·서버 환경에 묶는다. 네이티브 저장 실패로 기존
  본앱 세션을 삭제하지 않으며, 확인된 본앱 인증 무효화는 공유 저장소 오류가 있어도 처리한다.
- 초안은 플랫폼 저장소만 소유한다. 같은 초안의 재시도는 같은 UUID를 사용하고, 성공 영수증은
  같은 계정·API 환경에서 목록·카테고리·통계 갱신이 완료된 뒤 소비한다. 후속 조회 실패는 저장을
  다시 실행하지 않는다. 공유 안내는 닫을 수 있으며 다음 앱 복귀에서 다시 확인할 수 있다.
- 본앱의 수동 저장·인증·게스트 승격·409 확인 흐름과 화면 경로를 유지한다. 외부 저장 반영은
  이미 조회한 목록 범위를 임시로 읽고 한 번에 반영해 검색어·필터·스크롤의 중간 초기화를 피한다.
- 서버에는 공유 자격 발급과 두 저장 API의 제한 인증·멱등성 영수증을 추가했다. 신규 migration은
  `202610120014`이며 기존 access 인증·멱등성 헤더 없는 저장도 계속 지원한다. 백엔드와 migration을
  먼저 배포한 후 새 앱을 배포해야 한다. 이번 작업에서 운영 배포는 수행하지 않는다.
- 테스트 전용 `test/support/share_preview.dart`, 로컬 소켓 fixture, 네이티브 송신 앱을 사용한다.
  실제 FastAPI 경로 확인에는 외부 공급자를 대체하고 폐기 가능한 별도 PostgreSQL DB를 연결한다.
  운영 서버·실제 OAuth·AI·사용자 데이터를 사용하지 않는다. 제품 진입점에 테스트 분기를 추가하지 않는다.
- 구현 중 발견한 경합도 회귀로 고정했다. 공유 준비 뒤 영수증 조회에서 토큰이 바뀌면 새 자격을
  한 번 더 준비하고, 성공한 저장의 목록 갱신이 실패해도 기존 항목·페이지 커서를 유지한다.
  커서 보존 검사는 수정 전 실패·수정 후 통과했다. 공유 안내의 실제 렌더링과 닫기·입력 보존도 검사한다.
- 네이티브 자격을 읽지 못한 경우에는 초안과 본앱 로그인을 보존하면서 공유 자격만 차단·재발급한다.
  발급이 거절된 뒤 기존 자격을 재사용할 때도 사용자·세션·만료뿐 아니라 API 환경을 확인한다.
  다른 서버 환경을 준비 완료로 오인하는 검사는 수정 전 실패·수정 후 통과했다.
- 백엔드 최종 검사: 전용 PostgreSQL을 포함해 **986 passed, 0 skipped**(81.32초), Ruff·compileall 통과.
  기존 Starlette `httpx` deprecation 경고 1건이 있다. 빈 DB 전체 upgrade와 직전 `202610110013`에서
  `202610120014`로 upgrade, `alembic check`를 통과했다. 실제 운영 DB에 적용한 결과가 아니다.
- Flutter 전체 테스트는 동시성 1로 **552 passed, 0 skipped**(1분 5초)를 확인했다.
  기존 522개에 공유 연동 회귀 30개가 추가됐으며 기존 assertion·시나리오는 축소하지 않았다.
  Dart 로컬 import 순환과 데이터 계층의 앱·기능 계층 역참조가 없는 것도 확인했다.
- 실제 수동 저장 경로에 공유 복구 안내를 띄우는 위젯 회귀를 추가했다. URL controller·화면 State,
  선택 이미지 bytes·파일명이 유지되고 사진을 다시 선택하거나 수동 저장을 자동 호출하지 않는 것을 확인했다.
- 최종 `flutter analyze --no-pub` **문제 없음**(7.7초), `flutter build web --no-pub` **성공**(102.4초).
  웹 빌드의 기존 CupertinoIcons 폰트 탐색 경고는 남아 있으며 실패는 없다.
- iPhone 16 / iOS 18.6 Simulator에서 네이티브 전체 **17 passed**. 실제 App Group·공유 Keychain,
  계정 revision·자격 교체·초안 파일 정리·401·잘못된 성공 응답·URLSession 경계를 확인했다.
  정상 링크, 이미지/지원하지 않는 입력, 401 후 본앱 모달 복구, 응답 유실, 30초 timeout의
  공유 UI 5개 시나리오도 각각 통과했다. 응답 유실·timeout 재시도는 서버 저장 건수가 한 번만 증가했다.
- 실제 Safari와 사진 앱의 시스템 공유 목록에서 허투루를 선택해 저장 완료·원래 앱 복귀를 확인했다.
  Safari가 같은 YouTube 영상의 `www` 주소와 `m` 주소(`ra=m`)를 함께 제공하는 경우를 재현했다.
  알려진 모바일 경로 표시만 정규화하고 다른 영상·query·여러 이미지는 거부한다.
  제공자 순서를 보존하며 이 재현 테스트는 수정 전 실패·수정 후 통과했다.
- 실제 로컬 FastAPI·전용 PostgreSQL을 사용한 iOS 시나리오도 통과했다(58.3초).
  기존 게스트 시작·온보딩·관심사 선택 → 검색어 작성 → 외부 Instagram 링크 공유 저장 →
  송신 앱 복귀 → 본앱 검색 화면 복귀를 실행했다. 콘텐츠와 같은 사용자의 멱등성 영수증이
  함께 commit된 것을 DB에서 확인했고 XCTest로 검색 입력값 `share warm state` 보존을 검사했다.
  복귀 PNG에는 남아 있던 초안 안내가 다시 표시되므로 입력 보존 근거는 전 화면 PNG와 값 assertion이다.
- iOS 저장 중 닫기·송신 앱 강제 종료의 추가 UI **2 passed, 0 failures**(122.8초).
  서버 저장 후 응답을 지연한 상태에서 중단하고 본앱 네이티브 모달로 같은 초안을 재개해,
  각 시나리오의 저장 건수가 한 번만 증가하고 작성 중인 수동 URL·저장창이 유지되는 것을 검사했다.
  최종 PNG는 안내를 닫아 기존 입력이 보이는 상태로 촬영했다. 마지막 Simulator fixture 빌드는
  36.1초에 성공했다. UI 검증은 위 시나리오별 실행 결과이며 하나의 일괄 테스트 실행 결과가 아니다.
- Android Medium Phone / API 36 Emulator의 네이티브 **25 passed, 0 skipped**(131.8초).
  실제 Keystore, 계정·서버 환경 경계, Activity 재생성·재공유, 저장 직후 닫기 경합,
  HTTP 401·응답 유실·30초 timeout·이미지 재시도를 확인했다.
  시스템 공유 목록 → 링크 저장 → 송신 앱 복귀와 401 → 본앱 대기 항목 → 복구 저장 →
  기존 검색 화면 복귀도 통과했다. 최종 PNG에는 안내를 닫은 뒤 검색어 `9`와 결과 목록이 보인다.
- Android API 33 Emulator에서도 동일 네이티브 **25 passed, 0 skipped**(74.6초).
  시스템 공유 목록에서 `content://` 이미지를 받아 미리보기 → 가로·세로 회전 → 저장 →
  시스템 뒤로 가기로 송신 앱 복귀를 확인했다. 기존 API 33 AVD는 데이터 공간이 부족해 설치가
  실패했으므로 기존 데이터를 보존하고 캐시된 동일 API 이미지로 전용 테스트 AVD를 만들었다.
  최신 코드의 실제 로컬 백엔드용 Android Debug APK 빌드도 성공했다(26초).
- Android의 실제 로컬 FastAPI·전용 PostgreSQL 검증은 기존 게스트 로그인·온보딩을 거쳐
  YouTube 링크와 PNG를 각각 한 건 저장했다. DB에서 콘텐츠 **2→4**, asset **0→1**,
  멱등성 영수증 **2→4**를 확인했다. 두 콘텐츠·영수증과 이미지 asset이 같은 테스트 게스트에
  귀속된 것도 대조했다. 외부 OAuth·metadata·OCR은 계속 테스트 대역이다.
- Android 홈의 기존 Weekly 카드에서 `BOTTOM OVERFLOWED BY 13 PIXELS`를 관찰했다.
  공유 전용 화면의 가림과는 별개이며, 해당 카드의 위젯·문구·높이는 이번 변경에 포함하지 않았다.
  공유 기능 검증을 앱 전체 화면의 레이아웃 무결성 검증으로 확대하지 않는다.
- 캡처·영상은 저장소 밖 `~/.codex/visualizations/2026/10/11/01a12b8d-120f-7aa1-a4c0-22b66028b14b/mobile-share/`
  아래 플랫폼별 폴더에 보관한다. 테스트 fixture·공급자 대역 검증과 실제 외부 앱 검증을 구분하며,
  실제 Instagram·YouTube 앱, OAuth 공급자, 외부 AI/OCR·metadata, 운영 서버 저장·배포, 원격 CI,
  실기기 서명·프로비저닝·TestFlight 검증은 수행하지 않았다.
- 최종 문서 링크·`git diff --check`·전체 staged diff 검사를 통과했다. 로컬 테스트 서버 2개와
  Simulator·Emulator·촬영 프로세스를 종료했고, 기존 AVD·Docker·DB 데이터는 보존했다.
  커밋에는 제품 코드·회귀 테스트·로컬 검증 도구·문서만 포함하며 `AGENTS.md`, 환경 파일,
  로컬 빌드 생성물·로그·PNG·영상은 포함하지 않는다.
