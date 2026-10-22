# 프론트 상태·데이터 계층 분리와 회귀 수정

- 최초 기록일: 2026-10-12
- 영역: 구조
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-3c503fd1d2042f8f"></a>

2026-10-12의 1차 분리에서 화면·공유 요소를 역할별 파일로 옮겼으며, 2차 분리에서 아래 경계로
루트 상태와 데이터 처리를 분리했다. 검사별 실제 결과와 검증 범위는
[진행 기록](../fe-merge-fixes.md)을 따른다. 화면 동작과 API 계약을 유지하고 Flutter 기본
`ChangeNotifier`와 생성자 주입을 사용한다. 상태 관리 패키지·라우터·코드 생성 도구는 추가하지 않는다.

<a id="b-76b74b557bfbc767"></a>

| 경로 | 책임 |
| --- | --- |
| `lib/main.dart` | 앱 시작 진입점 |
| `lib/app/` | 의존성 조립·화면 연결·UI 효과를 처리하는 앱 View와 인증·화면 흐름을 조정하는 AppViewModel |
| `lib/app/actions/` | 여러 Repository를 사용하는 계정 초기화·콘텐츠 변경 후 갱신 순서 |
| `lib/data/repositories/` | 세션, 콘텐츠·카테고리·피드, 사용자·서버 통계를 각각 소유하는 세 Repository의 계약과 구현 |
| `lib/data/models/` | 읽기 전용 피드 스냅샷, 요청 세대와 변경 핸들 등 데이터 처리 계약 |
| `lib/shared/models/` | 여러 기능에서 사용하는 화면 모델 |
| `lib/shared/presentation/` | 날짜·색상·문구 변환과 공통 ViewModel·피드 표시 상태 투영 |
| `lib/shared/theme/` | 색상·문자 스타일 등 공통 화면 표현 |
| `lib/shared/contracts/` | `AppRoute`와 저장 콜백 등 기능과 앱이 공유하는 계약 |
| `lib/shared/data/` | 기존 초기 카테고리와 샘플 콘텐츠 데이터 |
| `lib/shared/widgets/` | 기능 모델에 의존하지 않는 범용 위젯 |
| `lib/shared/content/` | 콘텐츠 모델에 의존하는 재사용 UI |
| `lib/shared/category/` | 카테고리 모델에 의존하는 재사용 UI |
| `lib/features/auth/`, `home/`, `archive/`, `search/` | 인증·홈·보관함·검색 화면, 기능 전용 UI와 필요한 ViewModel |
| `lib/features/content/`, `categories/`, `account/` | 콘텐츠·카테고리·계정 화면, 기능 전용 UI와 필요한 ViewModel |
| `lib/clipback_api.dart`, `lib/social_auth.dart` | 기존 API·세션 처리와 소셜 SDK 연동 |

<a id="b-86aa36372705a361"></a>

여러 기능이 함께 사용하는 콘텐츠·카테고리 UI는 각각 `shared/content/`, `shared/category/`에 둔다.
콘텐츠 저장 화면은 `features/content/`의 `showContentSaveScreen`을 공통 진입점으로 사용한다.
입력·스크롤·이미지 컨트롤러, 파일 선택, 애니메이션과 시트 생명주기는 위젯에서 관리한다.
Snackbar·배너·확인창·Navigator 호출은 View가 소비하는 UI 효과로 전달한다.
API·세션 저장소·소셜 인증 서비스는 기존 위치와 인터페이스를 유지하며, 서비스 추가·DTO 일괄 복제는 하지 않는다.
추천 연결·원문 열기·랜덤 보기 개선과 백엔드·네이티브 설정 변경은 이번 분리 범위에 포함하지 않는다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-c3ac399806db588b"></a>

### 2026-10-12 — 프론트엔드 2차 상태·데이터 계층 분리

<a id="b-2de100141f2ed258"></a>

- 상태: 2차 구현과 전체 정적 분석·테스트·웹 빌드·로컬 로그인 진입 화면 확인 완료.
  1차 변경이 남아 있는 `refactor/frontend-module-split`에서 이어가며 1차 결과와 기존 `AGENTS.md`
  변경을 보존한다. 과거 FE 작업의 자동 커밋·푸시·PR 규칙은 적용하지 않는다.
  자동 커밋·stash·reset·푸시·PR 생성·병합은 수행하지 않는다.
- 범위: 기존 화면과 API 계약을 유지하면서 `ChangeNotifier`와 생성자 주입으로 MVVM과 데이터 계층을
  분리했다. 앱 View는 의존성 조립·화면 연결·Flutter 생명주기·UI 효과를, AppViewModel은 인증과 계정·
  화면 전환을 담당한다. 홈·보관함·북마크·검색·상세·계정·카테고리 관리·저장 상태는 기능 ViewModel
  8개로 옮겼다. `app/clipback_app.dart`는 2,041줄에서 434줄로 줄었고, 인증·조회·쓰기 구현은
  ViewModel과 세 Repository·두 Action으로 분리했다.
- 데이터 경계: `SessionRepository`는 세션 복원·인증·저장/삭제 큐·소셜 인증 자격 상태,
  `ContentRepository`는 피드·상세·카테고리·변경 상태·늦은 응답 조정,
  `UserRepository`는 사용자와 서버 통계를 담당한다. 각 Repository의 추상 계약과 구현을 두되
  서로 직접 참조하지 않는다. API DTO를 재사용하고 표시 형식은 공용 mapper로 분리한다.
- 조정 경계: `app/actions/`가 계정 초기화와 콘텐츠·카테고리 변경 후 조회·통계 갱신 순서를 담당한다.
  기능 ViewModel은 이 하위 조정 계층과 Repository 계약을 참조할 수 있지만 앱 View·AppViewModel이나
  다른 기능 ViewModel을 참조하지 않는다. 공유 표시 코드는 데이터 계약만 사용하며 상위 계층을 참조하지 않는다.
- 유지할 계약: 네 피드는 읽기 전용 스냅샷을 제공하고 추가 조회의 진행 중 Future를 공유한다.
  화면의 `FeedPage` 객체는 유지하며 query version이 바뀔 때만 스크롤을 초기화한다.
  요청·계정·인증·화면 탐색의 세대를 구분하고, 변경 잠금은 후속 조회까지 유지한다.
  서버 쓰기 성공 후 조회 실패는 쓰기를 되돌리지 않는다. 원본 이미지 요청 공유와 시트 정리도 보존한다.
- 제외: 서비스 파일·의존성·라우터·백엔드 계약·네이티브 설정 변경, 추천 연결·원문 열기·랜덤 보기 개선.
  실제 OAuth·운영 서버 쓰기·실기기 출시는 이번 완료 조건에 포함하지 않는다.
- 구현 전 기준: 이번 작업에서 새로 실행한 `flutter analyze --no-pub`는 **문제 없음**(2.6초),
  `flutter test --no-pub`는 **434 passed**(22초)다. 앞선 1차 작업의 실행 기록을 재사용하지 않았다.
- 최종 자동 검사: `flutter analyze --no-pub` **문제 없음**(2.1초), `flutter test --no-pub`
  **492 passed**(24초). 기존 434개에 새 경계 테스트 58개를 추가했으며 기존 테스트를 줄이거나
  skip하지 않았다. 추가 범위는 콘텐츠 Repository 19개, 세션·사용자·AppViewModel 13개,
  표시 변환·피드 투영 14개, 기능 ViewModel·Action 10개, 오래된 Action 요청 차단 2개다.
- 경계 검증: 조회·쓰기 경합과 필드별 복구, 삭제 데이터 부활 방지, 세션 저장 큐, 피드 요청 공유와
  스크롤 보존, 상세 닫기 후 동일 콘텐츠 재진입, 후속 통계 조회까지 변경 잠금 유지, dispose 이후
  저장 결과·UI 효과·통계 조회 차단을 확인했다. 이는 로컬 대역 테스트 결과이며 실제 공급자·서버 검증은 아니다.
- 보존·구조 검사: 기존 테스트·helper의 소스 바이트는 2차 작업 시작 시점과 동일하다.
  `clipback_api.dart`·`social_auth.dart`·`pubspec.yaml`·잠금파일과 기존 `AGENTS.md` 해시도 그대로다.
  `lib/`의 Dart 파일 77개에서 로컬 import 순환·공유 계층의 상위 참조·Repository 간 참조는 0건이다.
- 웹 빌드: `flutter build web --no-pub --no-web-resources-cdn
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18766/api/v1` **성공**(27.5초).
  기존 CupertinoIcons 폰트 경고는 남아 있지만 종료 코드는 0이었다.
- 화면 확인: Codex 내장 브라우저에서 로컬 정적 서버 `http://127.0.0.1:18765`의 웹 빌드를 열어
  브랜드 로고·소개 문구·**게스트로 시작하기**가 있는 로그인 선택 화면을 확인했다.
  웹 소셜 버튼이 표시되지 않는 기존 정책을 유지했고, 콘솔 경고·오류는 0건이었다.
  게스트·소셜 로그인 버튼을 누르거나 백엔드 쓰기를 수행하지 않았다.
- 최종 문서 변경 후 `git diff --check`를 통과했다. 화면 확인은 로그인 진입 화면으로 한정하며,
  저장·분류·검색 등 후속 흐름을 브라우저에서 수동 검증한 것은 아니다.
  원격 CI·운영 배포·실제 OAuth/AI·PostgreSQL·Android/iOS 빌드·실기기 검증은 수행하지 않았다.

<a id="b-60e3be7c3fe2335e"></a>

### 2026-10-12 — 2차 분리 리뷰에서 확인한 회귀 수정

<a id="b-fe6fc96c3a3e36fc"></a>

- 상세 진입: `DetailViewModel.open()`이 상세 선택 성공 여부를 반환하고, 앱 View는 성공한 경우에만
  상세 경로로 전환한다. 삭제 응답 직후 아직 렌더된 카드를 눌러도 목록에 머물며, 마지막 항목의
  빈 목록 예외나 다른 홈 콘텐츠를 대신 표시하는 문제가 발생하지 않는다. 저장 후 상세 진입에도
  같은 성공 검사를 적용하며, 뒤로 가기 목적지는 홈이고 저장 자체의 추가 열람 이벤트는 없다.
- 통계 보존: 일반 프로필 조회 `UserRepository.loadMe()`에서 통계를 0으로 덮는 처리를 제거했다.
  계정 초기화의 `resetAccount()`가 기존 통계를 비우는 책임은 유지한다. 초기 프로필 조회 실패 후
  후속 조회로 복구한 통계가 계정 정보 재확인·연결 화면 취소 후에도 유지된다.
- 재현 테스트 5개를 추가했다. `content_mutation_test.dart`는 삭제 응답 처리 후 다음 프레임 전
  실제 카드를 탭해 남은 항목 0개·1개 모두에서 경로 유지와 잘못된 상세 GET·열람·클릭 이벤트 부재를
  확인한다. `user_repository_test.dart`의 2개 테스트는 프로필 재조회 시 통계 보존과 계정 초기화의
  통계 제거를 검사한다. `app/account_stats_regression_test.dart`는 실제 ViewModel·Action·Repository를
  조립하고 HTTP만 대체해 최초 프로필 실패 → 통계 복구 → 계정 연결 → 뒤로 가기에서 70/30 보존과
  추가 통계·소셜 인증 요청 부재를 확인한다.
- 새 테스트는 구현 수정 전 5개 모두 실패했고 수정 후 통과했다. 기존 assertion·시나리오를 줄이거나
  skip하지 않았다. 관련 목록·상세·저장·원본 이미지 테스트 **192 passed**(16초), 통계·AppViewModel
  테스트 **12 passed**를 확인한 뒤 전체 검사를 실행했다.
- 이번 수정 후 `flutter analyze --no-pub` **문제 없음**(3.4초), `flutter test --no-pub`
  **497 passed**(30초). 앞선 492개에 회귀 테스트 5개가 추가된 결과이며 이전 실행 결과를 재사용하지 않았다.
- `flutter build web --no-pub --no-web-resources-cdn
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18766/api/v1` **성공**(45.1초).
  기존 CupertinoIcons 폰트 경고는 남아 있다. 로컬 웹 로그인 진입 화면의 로고·소개·게스트 시작 표시를
  확인했고 브라우저 콘솔 경고·오류는 0건이었다. 검증용 탭과 로컬 서버는 종료했다.
- `git diff --check`와 수정 전 비교로 기존 테스트 본문·`AGENTS.md` 보존 및 변경 범위를 확인했다.
  두 경합의 동작 검증은 HTTP 대역과 Flutter 테스트 환경의 결과다. 실제 OAuth·운영 서버 쓰기·
  원격 CI·실기기 실행은 이번에 수행하지 않았으며 웹 수동 확인은 로그인 진입 화면에 한정했다.
- 기존 1차·2차 변경과 사용자 `AGENTS.md`를 보존하고 `refactor/frontend-module-split`에서 수정했다.
  API·소셜 인증 서비스·의존성·백엔드·네이티브 설정 변경과 커밋·푸시·PR은 수행하지 않았다.
