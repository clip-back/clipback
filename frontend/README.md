# Clipback Frontend

Flutter 앱의 현재 코드 구조·설정·실행과 API 연결 안내입니다.
기준 커밋의 정적 확인과 과거 실행 결과를 구분합니다. 상세 변경·검증·실패·미검증 범위는
[작업·검증 이력](../docs/history/README.md)에 한 번만 기록합니다.
사용자 변경은 [업데이트 내역](../CHANGELOG.md), 공개 여부는 [배포 절차](../docs/release-process.md)를 따릅니다.

## 준비 사항

잠금파일은 Flutter `>=3.44.0`·Dart `>=3.12.0 <4.0.0`을 요구합니다.
해당 조건을 만족하는 SDK로 의존성을 준비하며 잠금파일을 재해석하지 않습니다.

Flutter·Dart 조건은 아래 잠금파일 기준을 따릅니다. 모바일 실행에는 Android SDK 또는 Xcode가 필요합니다. 소셜 설정을 생략해도 게스트 실행·빌드는 가능하며, 실제 소셜 인증에는 [공개 앱 설정](../docs/frontend/development.md#공개-앱-설정)을 먼저 준비합니다. 로컬 API를 사용할 때는 [백엔드 준비](../backend/README.md)를 먼저 마칩니다.

## 빠른 실행

첫 코드 블록은 저장소 루트에서 시작합니다. 이후 명령은 `frontend/`에서 실행합니다.

```bash
cd frontend
flutter pub get --enforce-lockfile
flutter run
```

로컬 API 연결 시에는 실제 서버 주소를 명시합니다. 미지정 시 API 클라이언트의 Railway 기본 주소를 사용합니다.

```bash
flutter run -d chrome --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

기기별 실행·서명·API 주소 조건은 [Android 개발 실행](../docs/frontend/development.md#android-개발-실행), [iOS 개발 실행](../docs/frontend/development.md#ios-개발-실행)을 따릅니다. 제품 빌드의 진입점은 `lib/main.dart`이며 프리뷰 진입점을 배포하지 않습니다.

## 기본 검증

의존성 준비 후 `frontend/`에서 실행합니다.

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

테스트 범위·안전 영역 프리뷰·공유 대역과 실제 로컬 백엔드의 차이는 [개발·검증 안내](../docs/frontend/development.md)를 따릅니다. 테스트·빌드 통과와 실제 공급자·운영·실기기 검증은 구분합니다.

## 코드 구조와 의존 방향

화면·루트 상태·데이터 처리를 아래 경계로 나눕니다. Flutter 기본 `ChangeNotifier`와 생성자 주입을 사용합니다.
구조 분리 당시의 검사와 한계는 [작업 이력](../docs/history/README.md)을 확인합니다.

| 경로 | 책임 |
| --- | --- |
| `lib/main.dart` | 앱 시작 진입점 |
| `lib/app/` | 의존성 조립·화면 연결·UI 효과를 처리하는 앱 View와 인증·화면 흐름을 조정하는 AppViewModel |
| `lib/app/actions/` | 여러 Repository를 사용하는 계정 초기화·콘텐츠 변경 후 갱신 순서 |
| `lib/data/repositories/` | 세션, 콘텐츠·카테고리·피드, 사용자·서버 통계, 계정별 최근 검색어, 네이티브 공유 Repository의 계약과 구현 |
| `lib/data/services/api_request_scope.dart` | 최초 홈·부가 조회·마이 통계의 요청 수명과 공통 인증 갱신의 늦은 응답 차단 |
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

`main`은 앱을 시작하고, 앱 View는 Repository·Action·ViewModel을 생성해 기능 화면을 조립한다.
화면은 화면 모델·콜백을 사용하고, ViewModel은 Repository 계약과 필요한 Action을 호출한다.
`app/actions/`는 앱 View·AppViewModel보다 하위의 조정 계층이므로 기능 ViewModel에서도 참조할 수 있다.
Action은 Repository만 조정하며 앱 View·AppViewModel·기능 ViewModel을 다시 참조하지 않는다.
ViewModel끼리, Repository끼리 직접 참조하지 않으며 ViewModel·화면은 API·SDK 서비스에 직접 접근하지 않는다.

Repository는 API DTO와 데이터 계약을 사용하고 화면 경로·표시 문구·색상·스크롤 위치를 소유하지 않는다.
공유 표시 변환·화면 상태·기본 ViewModel이 사용하는 데이터 의존성은 DTO·스냅샷·추상 Repository 계약으로
제한한다. `shared`는 Repository 구체 구현·API/SDK 서비스·Action·앱·기능 화면을 참조하지 않는다.
`FeedPage`는 ViewModel이 유지하는 화면 상태 객체이며, Repository 스냅샷의 version이 바뀔 때만
저장한 스크롤 위치를 초기화한다.

여러 기능이 함께 사용하는 콘텐츠·카테고리 UI는 각각 `shared/content/`, `shared/category/`에 둔다.
콘텐츠 저장 화면은 `features/content/`의 `showContentSaveScreen`을 공통 진입점으로 사용한다.
입력·스크롤·이미지 컨트롤러, 파일 선택, 애니메이션과 시트 생명주기는 위젯에서 관리한다.
Snackbar·배너·확인창·Navigator 호출은 View가 소비하는 UI 효과로 전달한다.
API·세션 저장소·소셜 인증 어댑터는 기존 위치와 인터페이스를 유지하며, 해당 어댑터 추가·DTO 일괄 복제는 하지 않는다.
`ApiRequestScope`처럼 외부 API·SDK·저장소에 직접 접근하지 않고 요청 수명을 조정하는 도우미는 이 어댑터 추가 금지 대상에 포함하지 않는다.

### 현재 기능 연결과 디자인 기준

- Today·Weekly, 최근 검색어, 시스템 뒤로가기는 기준 커밋에 연결되어 있습니다. 작업별 실제 검증과 한계는 이력 목차를 확인합니다.
- 구조는 `lib/main.dart` → `lib/app/` → 기능 ViewModel·Action·Repository로 이어집니다. 추천 상세 흐름은 `app/clipback_app.dart`와 `features/content/view_models/detail_view_model.dart`에서 조정합니다.
- 현재 디자인·확인 필요 상태는 [Figma 맞춤 기준](../docs/figma-ui-alignment-plan.md)을 따릅니다.
- 최초 홈은 카테고리와 첫 목록을 전체 15초 안에 준비하며, 실패하면 기존 복구 화면에서 수동으로 다시 시도합니다. 사용자 정보·통계는 홈 진입을 막지 않는 별도 조회입니다. 범위와 인증 보존은 [홈 복구 정책](../docs/frontend/home-loading-recovery.md)을 따릅니다.
- 마이 통계는 사용자 Repository가 조회 상태를 소유하고 계정 ViewModel이 화면에 투영합니다. 미확인 값은 `—`이며, 통계만 전체 10초 안에 다시 시도할 수 있습니다. 프로필 조회와 성공한 통계 표시는 독립적입니다. 확정 정책과 적용 범위는 [마이 통계 정책](../docs/frontend/account-stats-recovery.md)을 따릅니다.
- 화면별 프리뷰·재현 명령은 관련 작업 기록에 보존합니다. 과거 명령은 당시 코드·기기·데이터 기준이며 제품 빌드에는 `lib/main.dart`를 명시합니다.

## 상세 문서

- [세션·저장·탐색·실패 복구와 화면 동작](../docs/frontend/behavior.md)
- [홈 최초 불러오기 복구 정책과 구현 범위](../docs/frontend/home-loading-recovery.md) · [구현 명세 #76](https://github.com/clip-back/clipback/issues/76)
- [마이 통계 조회 상태·복구 정책](../docs/frontend/account-stats-recovery.md) · [구현 명세 #80](https://github.com/clip-back/clipback/issues/80) · [본문 사본](../docs/frontend/account-stats-recovery-spec.md) · [구현·검증 이력](../docs/history/2026-10-25-account-stats-recovery-implementation.md)
- [소셜·플랫폼 설정과 실행·검증·TestFlight](../docs/frontend/development.md)
- [백엔드 API 계약](../docs/backend/api-contracts.md)
- [iOS 네이티브 공유 검증](ios/ShareVerification/README.md) · [Android 공유 검증](android/SHARE_TESTING.md)
- [카테고리 추천](../docs/category-recommendation-policy.md) · [콘텐츠 재발견](../docs/content-recommendation-plan.md) · [YouTube](../docs/youtube-summary.md)
- [Figma 화면·확인 필요 목록](../docs/figma-ui-alignment-plan.md)
- [작업·검증 이력](../docs/history/README.md) · [배포 절차](../docs/release-process.md)

<details>
<summary>이전 문서 링크와 제목 호환</summary>

- <a id="figma-공통-스타일과-기기-프리뷰"></a>[Figma 공통 스타일과 기기 프리뷰](../docs/history/2026-10-13-figma-common.md#b-96ab71a8caa21d28)
- <a id="홈-화면-맞춤-검증"></a>[홈 화면 맞춤 검증](../docs/history/2026-10-13-home-initial.md#b-ff1f5ef18a3cfa5c)
- <a id="확대-하단-탭과-최근-카테고리-행-d01873c"></a>[확대 하단 탭과 최근 카테고리 행 (`d01873c`)](../docs/history/2026-10-13-scaled-navigation.md#b-c2d65bc87207489b)
- <a id="os-하단-안전-영역과-공통-인디케이터-a9eb69d"></a>[OS 하단 안전 영역과 공통 인디케이터 (`a9eb69d`)](../docs/history/2026-10-14-bottom-safe-area.md#b-a0cc738fa71d25bd)
- <a id="저장-결과-문구와-제출-입력-고정-a14111f-2026-10-15"></a>[저장 결과 문구와 제출 입력 고정 (`a14111f`, 2026-10-15)](../docs/history/2026-10-15-save-submitted-input.md#b-d93c4e241dd57918)
- <a id="저장-화면의-확대-글자-높이-5d12e9d-2026-10-15"></a>[저장 화면의 확대 글자 높이 (`5d12e9d`, 2026-10-15)](../docs/history/2026-10-15-save-text-scale.md#b-c828c2f433e14d94)
- <a id="저장-화면-하단-안전-영역과-버튼-겹침-2026-10-15-해당-범위-적용검증-완료"></a>[저장 화면 하단 안전 영역과 버튼 겹침 (2026-10-15, 해당 범위 적용·검증 완료)](../docs/history/2026-10-15-save-keyboard.md#b-b523a72a0351ca61)
- <a id="붙여넣기-입력행의-확대-글자-높이-b0d0c71-기준-해당-범위-적용검증-완료"></a>[붙여넣기 입력행의 확대 글자 높이 (`b0d0c71` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-15-paste-input.md#b-cc7450bd0e958c64)
- <a id="figma-붙여넣기-버튼-스타일-52132f0-기준-해당-범위-적용검증-완료"></a>[Figma 붙여넣기 버튼 스타일 (`52132f0` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-15-paste-button.md#b-f4a60343963eaa17)
- <a id="저장-화면-기본-글자와-공통-상단-a54c387-기준-해당-범위-적용검증-완료"></a>[저장 화면 기본 글자와 공통 상단 (`a54c387` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-15-save-typography.md#b-d3f2bc5b36b20c47)
- <a id="저장-결과-미리보기-1배율-글자-b082db8-기준-해당-범위-적용검증-완료"></a>[저장 결과 미리보기 1배율 글자 (`b082db8` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-16-save-preview-text.md#b-549792ba1f453bc7)
- <a id="저장-결과-카테고리-1배율-글자-108ef0f-기준-해당-범위-적용검증-완료"></a>[저장 결과 카테고리 1배율 글자 (`108ef0f` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-16-save-category-text.md#b-e5cc20da889a931d)
- <a id="사진-선택-프레임의-내부-크기여백-4d46dfa-기준-해당-범위-적용검증-완료"></a>[사진 선택 프레임의 내부 크기·여백 (`4d46dfa` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-17-photo-frame.md#b-3e469cd2187b94db)
- <a id="저장-결과-상단-여백-d1f13d4-기준-해당-범위-적용검증-완료"></a>[저장 결과 상단 여백 (`d1f13d4` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-17-save-top-gap.md#b-d3bfe3e3f771d286)
- <a id="저장-결과-미리보기-제목출처-간격-a6dfb4e-기준-해당-범위-적용검증-완료"></a>[저장 결과 미리보기 제목–출처 간격 (`a6dfb4e` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-17-save-source-gap.md#b-b8e4bcdf8df4476f)
- <a id="저장-결과-미리보기-제목-최대-폭-63800e6-기준-해당-범위-적용검증-완료"></a>[저장 결과 미리보기 제목 최대 폭 (`63800e6` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-17-save-title-width.md#b-30ba5634f8713778)
- <a id="저장-결과-카테고리-시작-간격-fec6b66-기준-해당-범위-적용검증-완료"></a>[저장 결과 카테고리 시작 간격 (`fec6b66` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-17-save-category-gap.md#b-731d93674ef3eb6a)
- <a id="저장-결과-미리보기-시작-간격-b61a47d-기준-해당-범위-적용검증-완료"></a>[저장 결과 미리보기 시작 간격 (`b61a47d` 기준, 해당 범위 적용·검증 완료)](../docs/history/2026-10-17-save-preview-gap.md#b-1c03cc80e6d52c18)
- <a id="저장-결과-화면-단위-표현-c33a45d-기준승인-범위-적용검증-완료"></a>[저장 결과 화면 단위 표현 (`c33a45d` 기준·승인 범위 적용·검증 완료)](../docs/history/2026-10-17-save-result-layout.md#b-52384bc5f44dbbfb)
- <a id="콘텐츠-상세-화면의-1배율-표현-맞춤--2026-10-17"></a>[콘텐츠 상세 화면의 1배율 표현 맞춤 — 2026-10-17](../docs/history/2026-10-17-detail-layout.md#b-db79d84869b3c657)
- <a id="카테고리-목록-화면의-1배율-맞춤--2026-10-17"></a>[카테고리 목록 화면의 1배율 맞춤 — 2026-10-17](../docs/history/2026-10-17-category-list.md#b-9ed9bafec172edfd)
- <a id="카테고리-관리-화면의-1배율-맞춤--2026-10-17"></a>[카테고리 관리 화면의 1배율 맞춤 — 2026-10-17](../docs/history/2026-10-17-category-management.md#b-bd3d9dd1d71dba91)
- <a id="카테고리-관리-시트와-삭제-팝업의-1배율-맞춤--2026-10-17"></a>[카테고리 관리 시트와 삭제 팝업의 1배율 맞춤 — 2026-10-17](../docs/history/2026-10-17-category-dialogs.md#b-62c49a74b76de064)
- <a id="아카이브-전체보기의-1배율-맞춤--2026-10-17"></a>[아카이브 전체보기의 1배율 맞춤 — 2026-10-17](../docs/history/2026-10-17-archive-layout.md#b-46d54839798b9834)
- <a id="미분류-콘텐츠-목록확인된-빈-상태1배율--2026-10-17"></a>[미분류 콘텐츠 목록·확인된 빈 상태1배율 — 2026-10-17](../docs/history/2026-10-17-unclassified-layout.md#b-b2b6b93432601f40)
- <a id="적용-범위와-유지한-정책"></a>[적용 범위와 유지한 정책](../docs/history/2026-10-17-unclassified-layout.md#b-a59d9d7624c1dc71)
- <a id="원본재현최종-검사"></a>[원본·재현·최종 검사](../docs/history/2026-10-17-unclassified-layout.md#b-f6bb144abc085525)
- <a id="양-플랫폼-실행과-비교"></a>[양 플랫폼 실행과 비교](../docs/history/2026-10-17-unclassified-layout.md#b-bfc95a476ef57010)
- <a id="프리뷰-실행"></a>[프리뷰 실행](../docs/history/2026-10-17-unclassified-layout.md#b-57219f4aa59edac9)
- <a id="즐겨찾기-화면의1배율-맞춤--2026-10-17-작업"></a>[즐겨찾기 화면의1배율 맞춤 — 2026-10-17 작업](../docs/history/2026-10-17-bookmark-layout.md#b-b937d5dd13af95ea)
- <a id="적용-범위와-보존-정책"></a>[적용 범위와 보존 정책](../docs/history/2026-10-17-bookmark-layout.md#b-f44aaa26bb2e6dec)
- <a id="이번-원본재현자동-검사"></a>[이번 원본·재현·자동 검사](../docs/history/2026-10-17-bookmark-layout.md#b-7530f67e0b03515d)
- <a id="양-플랫폼-실행과-비교-1"></a>[양 플랫폼 실행과 비교](../docs/history/2026-10-17-bookmark-layout.md#b-de64566b89cb5247)
- <a id="즐겨찾기-프리뷰-실행"></a>[즐겨찾기 프리뷰 실행](../docs/history/2026-10-17-bookmark-layout.md#b-3e8fe2202548220d)
- <a id="검색-화면의1배율-맞춤--2026-10-18-작업"></a>[검색 화면의1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-search-layout.md#b-0e5f5d54a5dd50f8)
- <a id="이번-원본과-검사"></a>[이번 원본과 검사](../docs/history/2026-10-18-search-layout.md#b-eb696e5b78675598)
- <a id="양-플랫폼-실행과-새-비교"></a>[양 플랫폼 실행과 새 비교](../docs/history/2026-10-18-search-layout.md#b-a2412439728bb5fc)
- <a id="검색-프리뷰-실행"></a>[검색 프리뷰 실행](../docs/history/2026-10-18-search-layout.md#b-a5b81207586bc593)
- <a id="마이페이지의-1배율-맞춤--2026-10-18-작업"></a>[마이페이지의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-my-layout.md#b-9c38206aa64404e7)
- <a id="이번-원본과-자동-검사"></a>[이번 원본과 자동 검사](../docs/history/2026-10-18-my-layout.md#b-ed2764f1a2460ae2)
- <a id="양-플랫폼-실행과-새-비교-1"></a>[양 플랫폼 실행과 새 비교](../docs/history/2026-10-18-my-layout.md#b-82206490137ed103)
- <a id="계정-관리-화면의-1배율-맞춤--2026-10-18-작업"></a>[계정 관리 화면의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-account-layout.md#b-622a112492310aa9)
- <a id="이번-조회와-자동-검사"></a>[이번 조회와 자동 검사](../docs/history/2026-10-18-account-layout.md#b-0c2247df6efbc89e)
- <a id="양-플랫폼-실행과-새-비교-2"></a>[양 플랫폼 실행과 새 비교](../docs/history/2026-10-18-account-layout.md#b-c608591c2d0c0795)
- <a id="카드-다시보기-화면의-1배율-맞춤--2026-10-18-작업"></a>[카드 다시보기 화면의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-card-review.md#b-5191dd83e902e066)
- <a id="원본-확인과-자동-검사"></a>[원본 확인과 자동 검사](../docs/history/2026-10-18-card-review.md#b-2e5c948d8c88f135)
- <a id="양-플랫폼-실행새-비교와-후속-경계"></a>[양 플랫폼 실행·새 비교와 후속 경계](../docs/history/2026-10-18-card-review.md#b-8307ff71c7bd44d4)
- <a id="로그인-선택-화면의-1배율-맞춤--2026-10-18-작업"></a>[로그인 선택 화면의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-login-layout.md#b-acfbe599d99cce12)
- <a id="원본자동-검사보호-계약"></a>[원본·자동 검사·보호 계약](../docs/history/2026-10-18-login-layout.md#b-033e5b175a1eebe8)
- <a id="양-플랫폼-실행새-비교와-후속-경계-1"></a>[양 플랫폼 실행·새 비교와 후속 경계](../docs/history/2026-10-18-login-layout.md#b-7eec925e4a9282bd)
- <a id="스플래시의-1배율-표현과-실제-앱-시작-흐름--2026-10-18-작업"></a>[스플래시의 1배율 표현과 실제 앱 시작 흐름 — 2026-10-18 작업](../docs/history/2026-10-18-splash-layout.md#b-a27213e83d9876db)
- <a id="적용-범위와-원본"></a>[적용 범위와 원본](../docs/history/2026-10-18-splash-layout.md#b-c5fd2c3c33787d69)
- <a id="시작-흐름자동-검증"></a>[시작 흐름·자동 검증](../docs/history/2026-10-18-splash-layout.md#b-e5c5acedb43aa574)
- <a id="양-플랫폼-실행비교와-한계"></a>[양 플랫폼 실행·비교와 한계](../docs/history/2026-10-18-splash-layout.md#b-ab3b0d4bdf0106fb)
- <a id="a01-재현-명령과-프리뷰"></a>[A01 재현 명령과 프리뷰](../docs/history/2026-10-18-splash-layout.md#b-207829e1e7eab4d9)
- <a id="관심사-선택-화면의-1배율-맞춤--2026-10-18-작업"></a>[관심사 선택 화면의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-interest-layout.md#b-855c7f6e6b2d3d08)
- <a id="기준표현승인된-선택-동작"></a>[기준·표현·승인된 선택 동작](../docs/history/2026-10-18-interest-layout.md#b-0e6f7c2199a09c51)
- <a id="기능-경계검사와-기록"></a>[기능 경계·검사와 기록](../docs/history/2026-10-18-interest-layout.md#b-018b939e79065565)
- <a id="관심사-화면-재현-명령"></a>[관심사 화면 재현 명령](../docs/history/2026-10-18-interest-layout.md#b-1f8e2817cfcb78a6)
- <a id="로그아웃-확인-화면의-1배율-맞춤--2026-10-18-작업"></a>[로그아웃 확인 화면의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-logout-layout.md#b-d9056bebb32be428)
- <a id="로그아웃-확인-재현-명령"></a>[로그아웃 확인 재현 명령](../docs/history/2026-10-18-logout-layout.md#b-cc59826cdae093b7)
- <a id="홈-c01c02의-1배율-표현-마무리--2026-10-18-작업"></a>[홈 C01·C02의 1배율 표현 마무리 — 2026-10-18 작업](../docs/history/2026-10-18-home-layout.md#b-0d276965454810a8)
- <a id="홈-1배율-재현-명령"></a>[홈 1배율 재현 명령](../docs/history/2026-10-18-home-layout.md#b-ffff2ce597980720)
- <a id="공지사항-목록의-1배율-맞춤--2026-10-18-작업"></a>[공지사항 목록의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-notice-list.md#b-c0ed255138c46cfb)
- <a id="공지사항-재현-명령"></a>[공지사항 재현 명령](../docs/history/2026-10-18-notice-list.md#b-d7f15afb7d40142a)
- <a id="홈-알림-화면의-1배율-맞춤--2026-10-18-작업"></a>[홈 알림 화면의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-notification-list.md#b-09899fbf1fcb497a)
- <a id="알림-화면-재현-명령"></a>[알림 화면 재현 명령](../docs/history/2026-10-18-notification-list.md#b-f859211f6ec5ff31)
- <a id="로그인-권한-안내-시트의-1배율-맞춤--2026-10-18-작업"></a>[로그인 권한 안내 시트의 1배율 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-permission-guide.md#b-5722b897db7b8e73)
- <a id="기준과-적용-경계"></a>[기준과 적용 경계](../docs/history/2026-10-18-permission-guide.md#b-04bf37183a629541)
- <a id="검사화면-증거"></a>[검사·화면 증거](../docs/history/2026-10-18-permission-guide.md#b-b60bb187fd90802f)
- <a id="공통-하단-탭의-1배율-아이콘-맞춤--2026-10-18-작업"></a>[공통 하단 탭의 1배율 아이콘 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-tab-icons.md#b-be76b1b7edb54ec8)
- <a id="기준과-적용-경계-1"></a>[기준과 적용 경계](../docs/history/2026-10-18-tab-icons.md#b-dab0d1aeeed8a96d)
- <a id="실제-검사와-증거"></a>[실제 검사와 증거](../docs/history/2026-10-18-tab-icons.md#b-db99107b4cc1c0b7)
- <a id="공통-하단-저장-버튼의-1배율-아이콘-맞춤--2026-10-18-작업"></a>[공통 하단 저장 버튼의 1배율 아이콘 맞춤 — 2026-10-18 작업](../docs/history/2026-10-18-save-add-icon.md#b-33bc65009db890d6)
- <a id="기준과-적용-경계-2"></a>[기준과 적용 경계](../docs/history/2026-10-18-save-add-icon.md#b-1e9891c613369d65)
- <a id="실제-검사와-증거-1"></a>[실제 검사와 증거](../docs/history/2026-10-18-save-add-icon.md#b-1161d2560d27f081)
- <a id="d07-사진-선택-후-원본-비율전체-보기-b9f77ff-기준-2026-10-18해당-범위-적용검증-완료"></a>[D07 사진 선택 후 원본 비율·전체 보기 (`b9f77ff` 기준, 2026-10-18·해당 범위 적용/검증 완료)](../docs/history/2026-10-18-photo-contain.md#b-2ccf8f20e73917d6)
- <a id="홈-최초-조회-전면-로딩의-1배율-맞춤--2026-10-18-작업-해당-범위-적용검증-완료"></a>[홈 최초 조회 전면 로딩의 1배율 맞춤 — 2026-10-18 작업 (해당 범위 적용·검증 완료)](../docs/history/2026-10-18-initial-loading.md#b-02092515b6c1136e)
- <a id="일반-소셜-로그인-실패-화면의-1배율-맞춤--2026-10-19-적용검증"></a>[일반 소셜 로그인 실패 화면의 1배율 맞춤 — 2026-10-19 적용·검증](../docs/history/2026-10-19-login-failure.md#b-0856dc5fa65433ea)
- <a id="게스트-계정-연결-충돌-안내의-1배율-맞춤--2026-10-19-적용검증"></a>[게스트 계정 연결 충돌 안내의 1배율 맞춤 — 2026-10-19 적용·검증](../docs/history/2026-10-19-account-conflict.md#b-8fbf92cfd035d399)
- <a id="f01-카테고리별-콘텐츠-목록1배율"></a>[F01 카테고리별 콘텐츠 목록1배율](../docs/history/2026-10-19-category-content.md#b-5c6452578d60afa9)
- <a id="상세-페이지-이동의1배율-figma-맞춤-2026-10-19"></a>[상세 페이지 이동의1배율 Figma 맞춤 (2026-10-19)](../docs/history/2026-10-19-detail-paging.md#b-c2d3a09a33af76cb)
- <a id="a03a04-프리뷰와-실제-검증--2026-10-19"></a>[A03·A04 프리뷰와 실제 검증 — 2026-10-19](../docs/history/2026-10-19-login-progress.md#b-d76a1a3db770838c)
- <a id="d04-링크-처리-중-프리뷰--2026-10-19"></a>[D04 링크 처리 중 프리뷰 — 2026-10-19](../docs/history/2026-10-19-link-pending.md#b-360238b6f8ebba42)
- <a id="d08-사진-저장-처리-중-1배율-적용--2026-10-19"></a>[D08 사진 저장 처리 중 1배율 적용 — 2026-10-19](../docs/history/2026-10-19-photo-pending.md#b-e89a77cc4447558f)
- <a id="원본-링크-외부-열기-검증--2026-10-21"></a>[원본 링크 외부 열기 검증 — 2026-10-21](../docs/history/2026-10-21-original-link.md#b-2bd6ea5e13e45e30)
- <a id="홈-today-추천의-실제-연결--2026-10-21"></a>[홈 Today 추천의 실제 연결 — 2026-10-21](../docs/history/2026-10-21-today-frontend.md#b-eb03dee3ff2fe3fd)
- <a id="2026-10-21-weekly-프론트-연결--승인-범위-완료"></a>[2026-10-21 Weekly 프론트 연결 — 승인 범위 완료](../docs/history/2026-10-21-weekly-frontend.md#b-fb24b149d2b8b8bb)
- <a id="실제-최근-검색어-저장삭제-2026-10-22"></a>[실제 최근 검색어 저장·삭제 (2026-10-22)](../docs/history/2026-10-22-search-history.md#b-b7ba8549412c0475)
- <a id="시스템-뒤로가기-검증-프리뷰"></a>[시스템 뒤로가기 검증 프리뷰](../docs/history/2026-10-22-system-back.md#b-561acce3c1c38cdb)

</details>

<details>
<summary>상세 설명 이동과 이전 제목 안내</summary>

- <a id="초기-세션-복원과-재시도"></a>[초기 세션 복원과 재시도](../docs/frontend/behavior.md#초기-세션-복원과-재시도)
- <a id="모바일-소셜-로그인"></a>[모바일 소셜 로그인](../docs/frontend/behavior.md#모바일-소셜-로그인)
- <a id="공개-앱-설정"></a>[공개 앱 설정](../docs/frontend/development.md#공개-앱-설정)
- <a id="검증-범위"></a>[검증 범위](../docs/frontend/development.md#검증-범위)
- <a id="갱신-토큰-저장"></a>[갱신 토큰 저장](../docs/frontend/behavior.md#갱신-토큰-저장)
- <a id="동시-인증-오류와-로그아웃"></a>[동시 인증 오류와 로그아웃](../docs/frontend/behavior.md#동시-인증-오류와-로그아웃)
- <a id="스크린샷-저장과-인증-재시도"></a>[스크린샷 저장과 인증 재시도](../docs/frontend/behavior.md#스크린샷-저장과-인증-재시도)
- <a id="저장된-스크린샷-원본-조회"></a>[저장된 스크린샷 원본 조회](../docs/frontend/behavior.md#저장된-스크린샷-원본-조회)
- <a id="콘텐츠-저장과-자동-분류"></a>[콘텐츠 저장과 자동 분류](../docs/frontend/behavior.md#콘텐츠-저장과-자동-분류)
- <a id="피드-추가-조회와-상세-탐색"></a>[피드 추가 조회와 상세 탐색](../docs/frontend/behavior.md#피드-추가-조회와-상세-탐색)
- <a id="콘텐츠-변경과-실패-복구"></a>[콘텐츠 변경과 실패 복구](../docs/frontend/behavior.md#콘텐츠-변경과-실패-복구)
- <a id="카테고리-삭제"></a>[카테고리 삭제](../docs/frontend/behavior.md#카테고리-삭제)
- <a id="실행과-검증"></a>[실행과 검증](README.md#빠른-실행)
- <a id="상단-안전-영역과-헤더"></a>[상단 안전 영역과 헤더](../docs/frontend/behavior.md#상단-안전-영역과-헤더)
- <a id="android-개발-실행"></a>[Android 개발 실행](../docs/frontend/development.md#android-개발-실행)
- <a id="ios-개발-실행"></a>[iOS 개발 실행](../docs/frontend/development.md#ios-개발-실행)
- <a id="testflight-권한-설명과-재업로드"></a>[TestFlight 권한 설명과 재업로드](../docs/frontend/development.md#testflight-권한-설명과-재업로드)
- <a id="backend-integration-boundaries"></a>[Backend integration boundaries](../docs/frontend/behavior.md#backend-integration-boundaries)
- <a id="모바일-공유-저장"></a>[모바일 공유 저장](../docs/frontend/behavior.md#모바일-공유-저장)
- <a id="플랫폼-설정"></a>[플랫폼 설정](../docs/frontend/development.md#플랫폼-설정)
- <a id="로컬-공유-검증"></a>[로컬 공유 검증](../docs/frontend/development.md#로컬-공유-검증)

</details>
