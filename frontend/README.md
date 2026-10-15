# Clipback Frontend

Flutter mobile frontend for the Clipback MVP.

FE 병합 전 수정 순서와 PR별 검증 결과는
[FE 병합 전 수정 진행 현황](../docs/fe-merge-fixes.md)에 기록합니다.

현재 디자인 기준은 [허투루의 261008](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-13961)입니다.
파일 키 `b2lmAo9VtbL6Qi0mzX5IMu`의 **WireFrame & UI(`3:5961`) > 261008(`912:13961`)**을 사용합니다.
[홈 C01](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16240),
[빈 홈 C02](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16337),
[하단 탭](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16336)과
[최초 로딩](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16483)의 최초 상세 조회는
2026-10-14 12:36~12:41 KST(03:36~03:41 UTC)에 수행했습니다. 섹션 메타데이터는
2026-10-14 12:43:38 KST(03:43:38 UTC)에 다시 조회했습니다. 확인 범위는 섹션 구조·화면 라벨과
선별한 네 화면의 상세이며 전체 본문 스타일을 새로 대조한 것은 아닙니다.
조회 근거·노드 대응·다음 작업은 [Figma 화면 맞춤 계획](../docs/figma-ui-alignment-plan.md)을 따릅니다.

`a9eb69d`까지의 앱 구현·검증은 이전 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 `261007` 기준입니다.
공통 텍스트·섹션 제목·기본 버튼은 `6f8fa73`, 홈은 `cc73b21`, 확대 레이아웃은 `d01873c`,
OS 하단 안전 영역은 `a9eb69d`에서 적용했습니다. **새 261008과 전체 화면의 재대조·적용은 미완료**이며,
아래 과거 조회 시각·`111:*` 노드·테스트 수·이미지/영상은 당시 출처와 결과로 보존합니다.
`b905769`의 기준 전환은 문서만 갱신했습니다. 이후 2026-10-15에는 최신 D05/D09를 조회해
사진 결과의 링크 전용 문구와 성공한 제출 입력의 고정을 `a14111f`에 적용했습니다. 당시 집중 11개·관련 132개·전체 703개 검사와
정적 분석을 통과했고 양 플랫폼의 문구·입력 고정 동작을 확인했습니다. 당시 남긴 배율 2의 넘침은 아래 후속 확대 작업에서
사용자 확정 기준으로 수정하고 `5d12e9d`에서 자동·양 플랫폼 실행 검증을 완료했습니다. `b0d0c71`에서는 저장 화면 하단 안전 영역·본문/버튼 겹침을 정리하고 자동·양 플랫폼 실행 검증을 마쳤습니다. 이번에는 그 커밋을 기준으로 링크 입력의 붙여넣기 문구와 입력행 확대 높이를 수정하고 자동·양 플랫폼 실행 검증을 마쳤습니다. 각 결과는 아래 별도 기록을 따릅니다.
이 부분 적용을 새 디자인 전체의 완료로 보고하지 않습니다.

카테고리 삭제 시 콘텐츠 보존과 `64px + 글자 확대 증가분 + viewPadding.bottom`을 한 번 합산하는
공통 하단 바의 OS 정책은 유지합니다. 저장 창의 별도 키보드 회피 기준은 아래 후속 작업에 기록합니다. 미정·불명확한 화면은 임의로 구현하지 않습니다.
최신 K02·K03의 공지 본문과 J07·K04의 미작성 본문, 최초 로딩 화면과 스켈레톤 설명의 불일치는
[디자인 확인 필요 목록](../docs/figma-ui-alignment-plan.md#디자인-확인-필요)에 정리합니다.
K05에는 약관 본문이 있지만 예시 내용을 운영 원문으로 확정하는 작업이 필요합니다.
안내·공지 신규 카드와 추천 API 연결은 별도 후속 범위입니다.

현재 FE는 인증·콘텐츠·카테고리·계정 통계를 API와 연동합니다.
추천·알림 등 일부 화면은 로컬 또는 mock 동작이 남아 있으며, 아래 연동 범위와 진행 문서를 따릅니다.

The current implementation covers these flows. The alignment plan above distinguishes
the active design reference from earlier implementation and verification:

- Onboarding
- Login entry
- Home
- Search
- Archive list
- Category archive
- Bookmark list
- Content detail

Figma-exported SVG assets are registered under `assets/figma/` and `assets/icons/`.
Large exported illustration SVGs include embedded raster data, so matching PNG fallbacks are generated in `assets/figma/` for reliable Flutter rendering.

## 코드 구조와 의존 방향

2026-10-12의 1차 분리에서 화면·공유 요소를 역할별 파일로 옮겼으며, 2차 분리에서 아래 경계로
루트 상태와 데이터 처리를 분리했다. 검사별 실제 결과와 검증 범위는
[진행 기록](../docs/fe-merge-fixes.md)을 따른다. 화면 동작과 API 계약을 유지하고 Flutter 기본
`ChangeNotifier`와 생성자 주입을 사용한다. 상태 관리 패키지·라우터·코드 생성 도구는 추가하지 않는다.

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
API·세션 저장소·소셜 인증 서비스는 기존 위치와 인터페이스를 유지하며, 서비스 추가·DTO 일괄 복제는 하지 않는다.
추천 연결·원문 열기·랜덤 보기 개선과 백엔드·네이티브 설정 변경은 이번 분리 범위에 포함하지 않는다.

## 초기 세션 복원과 재시도

- 앱 시작에는 로딩 화면을 표시하며, 카테고리·피드 조회가 끝나기 전에는 홈·샘플 콘텐츠·저장 기능을 노출하지 않습니다.
- 저장소 읽기 실패, 조회의 403·서버 오류·연결 실패·응답 파싱 실패에는 세션을 보존하고
  “저장한 콘텐츠를 불러오지 못했어요.”와 “다시 시도” 버튼을 표시합니다.
- 재시도는 현재 메모리 세션을 우선 사용합니다. 진행 중인 복원은 중복 실행하지 않으며,
  성공하면 서버 데이터가 반영된 홈으로 이동합니다.
- API의 토큰 갱신·재요청 후에도 최종 401이면 저장소 삭제 성공 후 로그인·게스트 선택으로 돌아갑니다.
  삭제에 실패하면 전환을 중단합니다. 만료된 세션을 새 게스트로 자동 교체하지 않습니다.
- 저장된 세션이 없는 최초 실행은 로그인·게스트 선택을 표시합니다. 사용자가 게스트를 선택해
  발급받은 세션은 조회 실패 후에도 유지합니다.
  프로필·통계의 비인증 오류는 홈 진입을 허용하고, 최종 401은 인증 만료로 처리합니다.
- 저장·조회 중에도 보호 API의 최종 401이면 저장소 삭제 후 로그인 선택으로 돌아갑니다.
  공급자 인증 자체의 401은 기존 게스트 세션 만료와 구분합니다.

## 모바일 소셜 로그인

Android는 Google·카카오, iOS는 Google·카카오·Apple을 지원합니다. 웹·데스크톱에는 소셜 버튼을
표시하지 않으며 게스트 사용은 유지합니다. 최초 실행·로그아웃 후 로그인 또는 게스트 사용을 선택합니다.
새 게스트·새 소셜 계정은 온보딩으로, 기존 계정·게스트의 소셜 승격은 홈으로 이동합니다.

- 게스트의 계정 연결은 `/auth/social/{provider}/upgrade`를 사용해 기존 콘텐츠를 유지합니다.
  이미 연결된 소셜 계정으로 409가 오면 게스트 데이터를 합치지 않는다는 경고를 표시합니다.
  **기존 계정으로 전환**을 확인한 경우에만 SDK 인증부터 다시 시작합니다. 취소하면 게스트를 유지합니다.
- 계정당 소셜 공급자는 한 종류입니다. 회원 화면에 다른 공급자를 추가 연결하는 기능은 없습니다.
  Apple 계정은 이번 범위에서 iOS로만 로그인할 수 있습니다. 같은 이메일의 Google·카카오 계정을 자동으로 합치지 않습니다.
- 게스트 승격의 401은 일회용 코드를 자동 재전송하지 않고 `/users/me`로 게스트 세션을 별도 확인합니다.
  정상 게스트는 유지하며, 다시 연결하려면 새 SDK 인증부터 시작합니다.
- SDK에서 사용자가 취소하면 화면과 세션을 유지합니다. 카카오톡 취소·동의 거절은 카카오계정 로그인으로
  이어지지 않습니다. 카카오톡 미설치 또는 취소 이외의 실패 때만 계정 로그인으로 진행합니다.
- Google·카카오의 ID token을 백엔드에 전달합니다. 카카오는 OpenID Connect 설정이 필요하며
  `idToken`이 없으면 오류를 표시합니다. access token을 대신 보내지 않습니다.
- Apple은 서버 challenge의 nonce를 네이티브 인증에 전달하고 identity token·authorization code·challenge ID를
  백엔드에 전송합니다. 최초 제공되는 이름만 함께 보냅니다. 재시도와 계정 전환은 새 challenge·code를 사용합니다.
- 성공한 Apple 로그인의 사용자 식별자는 `clipback.apple_user_id`에 별도 저장합니다. 기존
  `clipback.session` JSON 형식은 유지합니다. 앱 복원·포그라운드 복귀·네이티브 취소 알림에서
  Apple credential state를 확인합니다. `revoked`·`notFound`가 확인되면 로그인 선택으로 돌아가고,
  조회 실패·로컬 식별자 없음은 취소로 판단하지 않습니다.
- 일반 로그아웃은 Clipback 세션과 기기 SDK 상태를 정리합니다. Google은 `signOut`, 카카오는
  로컬 token manager `clear`를 사용합니다. 공급자 연결 해제·동의 철회·회원 탈퇴는 하지 않습니다.

### 공개 앱 설정

`google_sign_in` 7.2.0, `kakao_flutter_sdk_user` 2.0.1, `sign_in_with_apple` 8.2.0을 사용합니다.
`lib/social_auth.dart`의 SDK 어댑터는 초기화를 한 번만 수행하고, 설정 누락·불일치를 인증창 전에
안내합니다. 설정을 생략해도 게스트 실행·빌드는 가능합니다. 공급자 비밀키는 프론트엔드에 넣지 않습니다.

| Dart define | 용도 |
| --- | --- |
| `CLIPBACK_GOOGLE_SERVER_CLIENT_ID` | 양 모바일 공통 Google **웹 OAuth client ID**. 백엔드 ID token audience |
| `CLIPBACK_GOOGLE_IOS_CLIENT_ID` | `com.huturu.app`용 iOS OAuth client ID. iOS에서 필수 |
| `CLIPBACK_KAKAO_NATIVE_APP_KEY` | 양 모바일 공통 카카오 Native app key |

공급자 콘솔에서 발급한 공개 값을 아래 환경변수에 지정한 뒤 실행합니다. 이 값들을 Dart define으로
전달해도 앱에 포함되므로 서버 client secret·Apple `.p8`·토큰·암호화키를 넣지 않습니다.

```bash
# frontend/에서 실행. DEVICE_ID 및 각 공개 ID는 로컬에서 지정합니다.
flutter run -d "$DEVICE_ID" --no-pub \
  --dart-define="CLIPBACK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define="CLIPBACK_GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID" \
  --dart-define="CLIPBACK_KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY"
```

Android의 `applicationId`는 `com.clipback.frontend`입니다. Google 콘솔에는 이 패키지와 실제
Debug/Release 서명 SHA를, 카카오 콘솔에는 패키지와 해당 서명 key hash를 등록합니다.
Google `serverClientId`를 명시하므로 `google-services.json`을 추가하지 않습니다.
Gradle은 Flutter `dart-defines`에서 카카오 Native key를 읽어 manifest의
`AuthCodeHandlerActivity` 콜백 `kakao{Native key}://oauth`를 구성합니다.
([Google Android 설정](https://pub.dev/packages/google_sign_in_android),
[카카오 Flutter 설정](https://developers.kakao.com/docs/en/flutter/getting-started))

iOS는 같은 `com.huturu.app`을 Google·카카오 콘솔에 등록하고 다음 파일을 준비합니다.

```bash
# frontend/에서 최초 한 번. 기존 로컬 파일은 덮어쓰지 않습니다.
test -f ios/Flutter/SocialAuth.xcconfig || \
  cp ios/Flutter/SocialAuth.example.xcconfig ios/Flutter/SocialAuth.xcconfig
```

Git에서 제외된 `SocialAuth.xcconfig`의 `CLIPBACK_GOOGLE_IOS_URL_SCHEME`은 iOS OAuth
`REVERSED_CLIENT_ID`, `CLIPBACK_KAKAO_IOS_URL_SCHEME`은 `kakao` 뒤에 Native key를 붙인
값으로 바꿉니다. `Debug`·`Profile`·`Release`에서 이 설정을 포함합니다. Dart client ID를 전달해도
네이티브 URL scheme은 별도로 필요합니다. 로그인 전에 Info.plist의 실제 scheme과 Dart define의
일치를 검사하므로 한쪽만 수정하면 설정 오류를 표시합니다. `LSApplicationQueriesSchemes`에는
카카오톡 확인용 `kakaokompassauth`가 있습니다. 설정 변경 후에는 앱을 완전히 다시 빌드합니다.
([Google iOS 설정](https://pub.dev/packages/google_sign_in_ios))

Apple은 Runner의 Sign in with Apple entitlement와 콘솔의 `com.huturu.app` App ID capability를
모두 활성화하고, 해당 entitlement를 포함한 서명·프로비저닝을 준비합니다. 이 기능의 실제 기기 검증에는
Sign in with Apple을 지원하는 Developer Program 팀이 필요합니다. Apple 로그인은 네이티브 iOS만
사용하며 Services ID·웹 redirect는 설정하지 않습니다.
([Apple capability 설정](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple))

백엔드는 `GOOGLE_CLIENT_IDS`에 사용한 웹 OAuth client ID를 허용하고, `KAKAO_CLIENT_IDS`에는
실제 SDK가 발급하는 ID token의 audience를 허용해야 합니다. 카카오 콘솔의 로그인·OpenID Connect
활성화와 동의항목도 확인합니다. Apple 서버 설정·암호화키·migration은
[백엔드 README](../backend/README.md)와 [MVP 계획](../docs/backend-mvp-plan.md)을 따릅니다.
비밀키·서버 토큰은 앱과 로컬 공개 URL scheme 설정에 복사하지 않습니다.

Bundle ID를 기존 `com.clipback.app`에서 `com.huturu.app`으로 변경했으므로 실제 로그인 전에는
Google의 iOS OAuth client와 URL scheme, 카카오의 iOS 플랫폼 등록, Apple App ID·프로비저닝을
새 식별자 기준으로 확인합니다. 백엔드 Apple 설정의 `APPLE_CLIENT_ID`도 `com.huturu.app`이어야 하며,
`APPLE_TEAM_ID`·키는 해당 App ID에 사용할 개발자 팀과 일치해야 합니다. 저장소 설정 변경만으로
공급자 콘솔이나 배포 환경변수가 변경되지는 않습니다. Android 패키지명은 그대로 유지합니다.

### 검증 범위

`test/social_auth_test.dart`는 SDK 대역으로 플랫폼 제한, 초기화, 설정 불일치, 취소·카카오 fallback,
ID token 누락, Apple nonce·code·사용자 식별자, credential state, 로컬 로그아웃을 확인합니다.
`test/social_login_test.dart`는 HTTP·SDK 대역으로 로그인 선택, 게스트 유지/승격, 409 확인·취소,
새 인증 재시도, 로그아웃·세션 복원과 Apple 취소 상태 처리를 확인합니다.

로컬 테스트·APK/iOS 빌드·로그인 선택 화면 실행은 실제 공급자 인증 성공을 뜻하지 않습니다.
릴리스 전 실제 설정으로 양 모바일 Google/카카오, iPhone Apple 로그인·취소·재로그인·앱 재시작,
카카오톡 설치/미설치, 게스트 승격/409 전환, Apple 연결 철회 후 복귀를 각각 검증해야 합니다.

## 갱신 토큰 저장

- 게스트 생성·토큰 갱신·소셜 인증으로 새 세션을 받으면 메모리에 적용한 뒤 바로 저장을 시도합니다.
  토큰 갱신으로 인한 원래 요청의 재시도는 저장 시도가 끝난 뒤 실행합니다.
- 토큰과 만료 정보는 `clipback.session`의 JSON 한 값으로 저장합니다. 새 키가 없을 때만 기존 네 키를
  읽으며, 새 값이 손상됐다면 이전 토큰으로 되돌아가지 않고 초기 복원 오류로 처리합니다.
  기존 세션은 읽기만으로 변환하지 않고 다음 발급·갱신부터 새 형식을 사용합니다.
- 저장과 삭제는 같은 큐에서 순서대로 처리합니다. 삭제는 기존 키들을 먼저 제거하고 새 키를 마지막에
  제거합니다. 저장·삭제 API의 `false` 반환과 예외는 실패로 처리합니다.
- 저장 실패 시 새 메모리 토큰으로 현재 작업을 계속하며 다음 배너와 **다시 저장** 버튼을 표시합니다.
  “로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.”
- **다시 저장**은 현재 메모리의 최신 세션만 저장합니다. 토큰 갱신·콘텐츠 저장·카테고리 작업은
  반복하지 않으며, 저장 중 중복 실행을 막고 최신 세션 저장 성공 시 안내를 제거합니다.
- 저장 실패를 해결하기 전에 앱을 종료하면 계정 복원이 보장되지 않습니다. 저장 성공은 기기 저장 API의
  성공 응답을 기준으로 하며, 기기 장애나 강제 종료에 대한 영구 보존 보장을 뜻하지 않습니다.

## 동시 인증 오류와 로그아웃

다음 보호는 JSON·multipart 공통 요청 경로와 세션 발급에 적용합니다.

- 같은 API 인스턴스의 인증 요청들이 동시에 401을 받으면 진행 중인 refresh를 공유합니다.
  HTTP 응답부터 새 토큰 저장 시도까지 기다린 뒤 원래 메서드·본문을 유지해 한 번만 재요청합니다.
- 이미 갱신이 끝난 뒤 이전 토큰의 401이 도착해도 추가 갱신 없이 최신 토큰을 사용합니다.
  재요청의 최종 401은 호출자에게 전달하며, 갱신 실패 뒤의 새 요청은 다시 갱신할 수 있습니다.
- 세션을 복원·삭제·교체하면 이전 세션에서 시작한 응답은 새 세션을 덮어쓰거나 다른 계정으로
  재전송하지 않습니다. 이 취소는 인증 만료 401과 구분합니다.
- 로그아웃은 진행 중인 갱신과 저장 시도를 기다린 뒤 최신 메모리 토큰을 사용합니다.
  로그아웃 중 새 갱신·인증 재시도를 막고, 나중에 생성된 세션의 저장값과 화면은 보호합니다.
- refresh HTTP 응답 대기는 10초로 제한합니다. 저장 콜백에는 제한을 적용하지 않습니다.
  갱신 실패에도 현재 토큰으로 로그아웃을 시도하지만, 시간 초과는 서버 요청 취소를 보장하지 않습니다.
  서버에서 이미 토큰이 회전했다면 이전 토큰으로 해당 서버 세션을 해제하지 못할 수 있습니다.

## 스크린샷 저장과 인증 재시도

- 만료된 access token으로 업로드가 401을 받으면 공통 refresh를 기다리고, 갱신 토큰 저장 시도가 끝난 뒤
  같은 계정으로 업로드를 한 번만 재전송합니다. 일반 API 요청과 겹쳐도 하나의 갱신을 공유합니다.
- 파일 바이트·파일명·카테고리·태그를 보존해 매 시도마다 새로운 multipart 요청을 구성합니다.
  복수 카테고리·태그는 각각 반복 form part로 모두 보내며, 빈 목록은 생략합니다.
- 링크·사진 저장의 최종 401은 저장된 세션 삭제 후 로그인 선택으로 돌아갑니다.
  자동 게스트 생성·다른 계정으로 재저장은 하지 않습니다. 인증 오류 이외의 저장 실패는 입력과 선택 사진을 유지합니다.
- 업로드 전송 대기와 응답 본문 수신은 각각 10초입니다. 일반 HTTP 오류·연결 실패·시간 초과에는
  자동 재전송하지 않습니다. 실패 후 사용자가 다시 저장할 수 있으며 저장 중 중복 제출은 차단합니다.
- 시간 초과·연결 종료·세션 변경은 서버 저장을 취소하지 않습니다. 서버에서 이미 저장됐다면 수동 재시도로
  중복 콘텐츠가 생길 수 있으며, 이번 변경은 서버 중복 저장 방지 기능을 추가하지 않습니다.

## 저장된 스크린샷 원본 조회

- 저장한 사진은 상세의 **원본 이미지 보기**와 원문 창에서 인증된 자산 API로 다시 내려받습니다.
  확인창의 선택 사진 메모리에 의존하지 않으므로 앱을 재시작한 뒤에도 조회할 수 있습니다.
- 원본 영역을 처음 열 때만 다운로드하며, 같은 상세에서는 펼침 영역과 원문 창이 진행 중 요청과
  성공한 이미지를 공유합니다. 원래 비율을 유지하고 긴 이미지는 세로 스크롤로 확인합니다.
- 이미지 바이트는 기기에 영속 저장하지 않습니다. 상세 이탈·다른 콘텐츠/자산·계정 전환 시 정리하고,
  이전 화면의 늦은 응답은 표시하지 않습니다. 별도 확대·파일 다운로드·오프라인 보관은 제공하지 않습니다.
- 다운로드 전송 대기와 본문 수신은 각각 10초입니다. 최초 401은 기존 공유 토큰 갱신과 저장 시도를
  기다린 뒤 한 번만 재요청합니다. 최종 401은 로그인 선택으로 돌아가며, 그 외 다운로드 실패는 세션을 유지합니다.
- 자산 없음·404·통신 오류·이미지 디코딩 실패를 구분해 안내하며, 다운로드/표시 실패에는 **다시 시도**를
  제공합니다. 자동 반복이나 샘플 이미지 대체는 하지 않으며, 이미지 조회만으로 열람·클릭 이벤트를 늘리지 않습니다.
- 시간 초과와 화면 이탈은 서버 전송 취소를 보장하지 않습니다. 원본은 서버의 소유권 검사와 저장 파일에
  의존하므로 삭제되거나 유실된 파일은 다시 표시할 수 없습니다.

## 콘텐츠 저장과 자동 분류

- 저장 화면은 카테고리를 강제 지정하지 않습니다. 링크는 빈 `category_ids` 목록으로,
  사진은 해당 multipart part 없이 보내 백엔드의 자동 분류를 요청합니다.
  카테고리 이름을 태그로 자동 생성하지 않습니다.
- 저장 확인창은 서버가 반환한 카테고리를 표시합니다. 미분류로 저장돼도 콘텐츠 저장은 성공이며,
  응답에 없는 AI 성공 여부나 실패 원인을 추정하지 않습니다.
- YouTube의 `queued`·`processing`은 동영상 정보를 처리 중이라고 안내합니다.
  확인창은 폴링하지 않으며, 다음 상세 조회나 앱 새로고침에서 최종 카테고리를 반영합니다.
  `completed` 상태여도 추천 결과가 없으면 미분류가 유지될 수 있습니다.
- 수동 카테고리 변경은 기존 상세 화면에서 합니다. 생성의 빈 목록은 자동 분류 요청이지만,
  분류 수정 API의 빈 목록은 미분류 지정이므로 저장 직후 별도 분류 수정 요청을 보내지 않습니다.
  명시적 선택과 기존 API의 복수 카테고리·태그 전송 계약은 유지합니다.

## 피드 추가 조회와 상세 탐색

- 아카이브·분류·북마크·검색은 서버 커서로 20개씩 조회합니다. 남은 스크롤이 300px 이하이면
  다음 페이지를 불러오며, 짧은 화면도 레이아웃 후 같은 기준을 확인합니다.
- 홈은 선택한 분류의 최신 카드 4개를 미리 보여줍니다. 최근 저장한 콘텐츠의 더보기로
  같은 분류의 아카이브에 들어갑니다. 검색은 제출 또는 최근 검색어 선택으로 실행합니다.
- 북마크 우선은 서버의 북마크 페이지들을 먼저 조회하고, 끝나면 일반 콘텐츠 페이지로 이어집니다.
  각 구간은 최신순이며, 복수 분류 콘텐츠도 서버가 반환한 해당 분류 목록에 표시합니다.
- 목록의 `불러온 N개`는 현재 내려받은 수입니다. 카테고리 폴더와 작업 메뉴의 개수는 서버 집계를
  사용하며, 폴더는 마지막 저장 시각 내림차순·동일 시각 ID 오름차순·저장 이력 없는 폴더는 마지막입니다.
- 추가 조회 실패 시 기존 카드와 커서를 유지하고 다시 시도할 수 있습니다. 커서가 유효하지 않으면
  처음부터 다시 불러옵니다. 조회의 최종 401은 저장된 세션 삭제 후 로그인 선택으로 돌아갑니다.
- 상세 이전·다음은 진입한 목록의 순서를 따릅니다. 마지막으로 불러온 카드의 다음을 누르면 추가 페이지를
  기다리며, 전체 끝에서는 순환하지 않습니다. 상세에서 돌아오면 목록과 스크롤 위치를 유지합니다.
- 저장·삭제·분류·북마크 변경 성공 후에는 같은 조건의 첫 페이지를 새로 조회합니다. 열린 상세는 유지하지만
  갱신한 목록에 없으면 이전·다음을 사용할 수 없습니다. 현재 콘텐츠 삭제 시 진입 목록으로 돌아갑니다.
- 커서는 요청 사이의 DB 스냅샷을 보장하지 않습니다. 다른 기기에서 추가한 최신 콘텐츠는 다음 새 조회에
  반영됩니다.

## 콘텐츠 변경과 실패 복구

- 북마크·분류·삭제는 같은 콘텐츠에서 한 번에 하나만 실행합니다. 처리 중 카드와 상세에
  **변경 중…** 또는 **삭제 중…**을 표시하고 해당 콘텐츠의 변경 버튼을 잠급니다.
  다른 콘텐츠 변경과 화면 탐색은 계속 사용할 수 있습니다.
- 북마크와 분류는 목록·검색·열린 상세에 즉시 반영합니다. 실패하면 변경한 필드만 함께 복구하며,
  연결 오류·응답 파싱 오류도 안내하고 잠금을 해제합니다. 최종 401은 로그인 선택으로 돌아갑니다.
- 삭제 중에는 항목과 상세를 유지하고 서버 성공 후 제거합니다. 실패하면 원래 화면과 순서를 유지하며,
  성공 시 그 콘텐츠 상세를 보고 있을 때만 진입 목록으로 돌아갑니다.
- 먼저 시작한 조회가 늦게 끝나도 진행 중이거나 완료된 변경을 되돌리지 않습니다. 검색·필터·계정이
  바뀌면 이전 항목을 새 목록에 삽입하지 않으며, 일반 토큰 갱신은 계정 변경으로 취급하지 않습니다.
- 성공 후 같은 조건의 첫 페이지 갱신이 실패해도 성공한 쓰기를 취소하지 않습니다. 목록의 조회 재시도로
  다시 확인할 수 있습니다. 처리와 후속 조회가 끝나면 같은 콘텐츠를 다시 변경할 수 있습니다.
- 연결 종료·응답 파싱 실패는 서버 변경 취소를 보장하지 않습니다. 실패 시 화면은 마지막 확인값으로
  복구하며, 다음 정상 조회에서 서버 상태를 반영합니다. 기존 인증 갱신 외의 자동 쓰기 재시도는 하지 않습니다.

## 카테고리 삭제

- 카테고리를 삭제해도 콘텐츠·북마크·태그·원본 파일은 보존합니다. 다른 분류가 남으면 유지하고,
  마지막 분류가 없어질 때만 미분류로 이동합니다. 콘텐츠의 전체 분류를 보존하며 화면에는 첫 분류를 표시합니다.
- 확인창을 닫고 해당 폴더에 **삭제 중…**을 표시합니다. 응답 전에 항목을 선제적으로 제거하지 않습니다.
  같은 카테고리 수정·삭제와 삭제 중 분류의 새 지정을 막고, 다른 콘텐츠·카테고리 변경과 탐색은 허용합니다.
- 서버 성공 후 카테고리를 제거하고 집계·로드된 목록·열린 상세를 다시 조회합니다. 삭제된 활성 필터만
  전체 콘텐츠로 바꾸며, 사용자가 다른 필터나 화면으로 이동했다면 유지합니다.
- 삭제 실패는 기존 항목·순서·계정을 유지합니다. 성공 후 조회 실패는 삭제를 되돌리지 않으며,
  **다시 불러오기**는 조회만 재시도합니다. 연결·파싱 실패는 서버의 삭제 취소를 보장하지 않습니다.
- 늦은 조회·콘텐츠 변경 응답·실패 복구에서 삭제 성공한 분류 ID를 제외합니다. 같은 이름의 새 ID는 허용하며
  계정 교체 시 보호 상태를 초기화합니다. 공용 미분류는 삭제할 수 없고 사용자 소유 기본 카테고리는 삭제할 수 있습니다.

## 실행과 검증

잠금파일은 Flutter `>=3.44.0`·Dart `>=3.12.0 <4.0.0`을 요구합니다.
해당 조건을 만족하는 SDK로 의존성을 준비하며 잠금파일을 재해석하지 않습니다.

```bash
cd frontend
flutter pub get --enforce-lockfile
flutter run
```

로컬 API 연결 시에는 실제 서버 주소를 명시합니다. 미지정 시 API 클라이언트의 Railway 기본 주소를 사용합니다.

```bash
flutter run -d chrome --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:8000/api/v1
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

세션 복원·저장·동시 갱신 회귀 테스트는 `test/session_restore_test.dart`, `test/session_persistence_test.dart`,
`test/session_refresh_test.dart`에서 HTTP와 저장소 오류를 대체해 확인합니다.
`test/screenshot_auth_test.dart`는 실제 multipart 본문과 파일 선택 대역으로 업로드·저장 실패를 검증합니다.
`test/content_auto_category_test.dart`는 선택 없는 요청과 실제 서버 분류·YouTube 처리 상태 표시를 검증합니다.
`test/feed_pagination_test.dart`는 커서·필터·북마크 우선·실패 재시도·늦은 응답·상세 경계 탐색을 검증합니다.
`test/screenshot_asset_test.dart`와 `test/screenshot_asset_api_test.dart`는 원본 표시·다운로드 인증·시간 초과·화면 전환 경합을 검증합니다.
`test/content_mutation_test.dart`는 변경 중 잠금·실패 복구·늦은 조회·계정 전환·삭제 성공 시점과 상태 보존을 검증합니다.
삭제 응답 직후 화면에 남아 있는 카드를 눌러도 상세 열기가 거부되면 목록에 머물고, 다른 콘텐츠를 대신 표시하지 않는지도 확인합니다.
`test/category_delete_test.dart`는 삭제 안내·진행·실패 보존·전체 분류·동시 변경·늦은 응답과 조회 재시도를 검증합니다.
`test/app/account_stats_regression_test.dart`와 `test/data/user_repository_test.dart`는 프로필 재조회 시
이미 받은 서버 통계를 보존하고, 계정 초기화 때만 기존 통계를 비우는 경계를 검증합니다.
토큰 저장은 플랫폼 저장 대역과 캐시 초기화 후 읽기도 검증합니다.
실제 PostgreSQL·Chrome 검증 결과와 미검증 범위는 위 진행 문서에 별도로 기록합니다.

## Figma 공통 스타일과 기기 프리뷰

공통 스타일의 구현·검증 기록은 이전 `svNWsTFh8Ws1Mpt8XQIcrN / 261007` 기준입니다.
테스트 전용 프리뷰의 사용법은 유지하며 실행 성공을 새 `261008` 디자인 적용 완료로 보고하지 않습니다.

`AppText.sectionTitle`은 Pretendard 18px/SemiBold, 자간 −0.45px과 폰트 기본 행간을 사용합니다.
`SectionHeader`는 최소 높이 44px·세로 여백 각 8px이며, 긴 제목을 한 줄 말줄임으로 표시하고
오른쪽 24px 아이콘을 유지합니다. 글자가 확대되면 헤더 높이가 늘어납니다.
`AppText.primaryButtonLabel`은 기존 16px/w700을 공유합니다. 글자 색상은 각 버튼의
`foreground`를 따르며 기존 높이·모서리·탭 동작을 유지합니다.

`test/common_text_style_test.dart`는 320·375px 폭과 글자 배율 1·2에서 제목과 아이콘의 배치·탭을,
버튼 높이 52·56px에서 기본·사용자 지정 색상과 탭 동작을 확인합니다.

```bash
# frontend/에서 실행. 연결된 Simulator 또는 Emulator ID를 지정합니다.
flutter test --no-pub test/common_text_style_test.dart

# 기본 모드: 상단 도구막대에서 home, empty, components, scaled를 선택합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_common_style_preview.dart

# 자동 모드: 화면 캡처, 합성 포인터 스크롤·탭과 컴포넌트 측정을 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_common_style_preview.dart \
  --dart-define=FIGMA_COMMON_STYLE_CHECK=true
```

자동 모드는 기기 임시 폴더 `clipback-common-style-*`에 PNG 5개와 `report.json`을 저장하고,
로그에 경로와 `FIGMA_COMMON_STYLE PASS/FAIL`을 출력합니다. 홈·홈 스크롤·빈 홈·공통 컴포넌트·
글자 배율 2의 컴포넌트를 캡처합니다. 영상은 별도로 기기 화면을 촬영합니다.
`report.json`의 `passed`는 전체 실행의 성공 여부이고, `checksCompleted`는 측정·탭 시나리오를 끝까지
실행했는지 표시합니다. `componentChecksPassed`와 `componentFrameworkErrors`는 변경한 공통 컴포넌트의
검증 결과·오류를 표시하며 `frameworkErrorDetails`에는 오류가 발생한 화면을 기록합니다.
따라서 기존 홈의 오류가 남아 전체 실행이 실패해도 공통 컴포넌트 결과와 구분해 확인할 수 있습니다.
첫 공통 스타일 커밋 `6f8fa73`의 Android 실행은 기존 Weekly 카드 넘침으로 전체 `passed: false`, 공통 `componentChecksPassed: true`였습니다. 아래 홈 작업에서 같은 오류를 새로 재현하고 수정 후 재검증했습니다. 일반 배율의 홈과 글자 배율 2의 기존 하단 탭 오류를 구분합니다.
이 프리뷰는 실제 홈·공통 위젯에 메모리 데이터를 전달하며 실제 세션·HTTP·네이티브 공유 서비스를
사용하지 않습니다. 합성 포인터 검증은 사람의 수동 조작·실제 OAuth·운영 서버 검증과 구분합니다.
제품 진입점은 `lib/main.dart`이며 테스트 전용 프리뷰를 출시하지 않습니다.
플랫폼별 전체·공통 컴포넌트 실행 결과는 [프론트 진행 기록](../docs/fe-merge-fixes.md)을 따릅니다.

## 홈 화면 맞춤 검증

홈 커밋 `cc73b21` 당시 기준은 이전 파일 `svNWsTFh8Ws1Mpt8XQIcrN / 261007`의
C01 `111:3584`·C02 `111:3681`입니다. 당시 적용 영역과 과거 증거는
[Figma 화면 맞춤 계획](../docs/figma-ui-alignment-plan.md)에 보존하며 새 기준·현재 보류 항목도 같은 문서를 따릅니다.
새 빈 홈은 `feed.initialized`, 로딩/오류 없음, 양쪽 필터 ID 없음과 콘텐츠 0개가 모두 확인될 때만 표시합니다.
미조회·필터 결과 없음·로딩·오류는 기존 표현을 유지합니다. 현재 최근 카테고리 블록도 유지합니다.

홈 추천·최근 카드는 기본 크기 133×120px·298×186px이며 글자 확대 시 높이가 늘어납니다.
제목·요약은 각각 최대 2·3줄이고 요약은 카드의 남은 공간을 넘지 않습니다.
페이지 점은 최대 4개 카드의 중심을 기준으로 바뀝니다. 필터·피드 버전·표시 콘텐츠 ID 순서 변경은
첫 카드로 초기화하고, 북마크만 변경되면 현재 위치를 보존합니다. 추천 목적지는 현재 연결을 유지합니다.

```bash
# frontend/에서 실행합니다.
flutter test --no-pub test/home_alignment_test.dart test/top_safe_area_test.dart

# 제품 수정 전에 양 플랫폼에서 before 실행을 마친 뒤 원본 PNG/보고서를 보존합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_home_preview.dart \
  --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=before

# 수정 후 같은 기기·대역 데이터·글자 배율·스크롤 위치로 재촬영하고 동작을 검증합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_home_preview.dart \
  --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=after
```

이 전용 진입점은 실제 `HomeScreen`에 고정된 콘텐츠 4개/0개와 동일한 카테고리·조회 완료 상태를 전달합니다.
제품 `main.dart`나 서버 API를 변경하지 않고 실제 세션·HTTP·저장을 사용하지 않습니다.
자동 입력은 Flutter 합성 포인터입니다. 저장 시트 진입·키보드·닫기까지 확인하며 실제 저장 완료 검증은 아닙니다.
기기 임시 폴더 `clipback-home-*`에 PNG와 `report.json`을 저장하고 `FIGMA_HOME PASS/FAIL`을 출력합니다.
현재 프리뷰는 정상/빈 홈·각 배율 2·긴 카테고리의 빈 홈 배율 1/2, 총 여섯 상태를 수정 전후 각각 촬영합니다.
현재 프리뷰는 양 phase 모두 스크롤·마지막 카드·저장 입력의 키보드·확대 카드 관련 동작 다섯 장을 추가로 촬영해 총 11장을 남깁니다.
`baselineCaptured`는 여섯 비교 상태 촬영 완료 여부이며, 오류가 있어도 촬영 성공을 전체 검증 성공으로 바꾸지 않습니다.
`frameworkErrors`, `checksCompleted`, `passed`, 콜백·스크롤 측정값을 함께 확인합니다.
`normalHomeChecksPassed`·`interactionChecksCompleted`·`scaledScenesCaptured`는 일반 홈/동작/확대 촬영의 별도 결과입니다.
프레임워크 오류가 있으면 전체 `passed: false`로 기록하고 촬영 성공과 구분합니다.
이번 OS 작업의 `before` 통과는 기존 화면·동작의 기록이며, 새 OS 안전 영역 기준은 `after`에서만 판정합니다.
영상은 별도 `simctl recordVideo`/`adb screenrecord`로 촬영합니다. 화면 증거·로그·빌드 결과는 Git에서 제외합니다.
이전 홈 커밋 `cc73b21`은 전체 Flutter 테스트 **595 passed**, 정적 분석 문제 없음과 양 플랫폼 일반 배율의
홈·저장 진입·스크롤·페이지 점을 확인했습니다. 당시 배율 2의 하단 탭과 좁은 최근 카테고리 행 오류는 보류했고,
후속 승인에 따른 변경과 이번 재검증 결과는 아래에 구분합니다.
변경 전·후·Figma 3열 비교와 영상은 [프론트 진행 기록](../docs/fe-merge-fixes.md)에 기록합니다.

## 확대 하단 탭과 최근 카테고리 행 (`d01873c`)

아래 조회 노드·96/124/140px 측정과 625개 테스트는 이전 `svNWsTFh8Ws1Mpt8XQIcrN / 261007`으로 이 커밋 당시 수행한 검증입니다.
현재 OS 하단 안전 영역의 승인 기준과 이번 실행 명령·결과는 다음 절을 따릅니다.

공유 `ClipbackNavigationBar`의 라벨은 56px 폭에서 실제 글자 배율을 유지하고 최대 두 줄·말줄임으로 표시합니다.
네 라벨 중 가장 높은 값을 공통 영역으로 사용해 아이콘 상단을 맞추며, 증가분을 항목 56px·행 64px·전체 바 96px에
함께 더합니다. 배율 1의 전체 높이 96px, 기존 색상·탭 목적지·하단 인디케이터를 유지합니다.
추가 버튼은 72×72px·중앙·위로 22px 위치이며, 행의 제약을 받지 않게 바 전체 Stack에 배치합니다.
버튼의 중심과 바 안쪽 하단 가장자리 탭을 각각 확인합니다.

빈 홈의 `CategoryHomeRow`는 텍스트 열에 남은 폭을 할당하고 이름·시각을 각각 한 줄 말줄임으로 표시합니다.
폴더·화살표·색상·글자 크기·행 탭과 기존 고정 시각 문구를 유지합니다.
API·데이터 모델·콘텐츠 보존/삭제 정책과 다른 카테고리 행의 디자인은 변경하지 않습니다.
확대 상태는 별도 Figma 프레임이 없어 사용자가 승인한 위 배치를 기준으로 합니다.
일반 디자인 기준은 하단 탭 `111:3680`, C01 `111:3584`, C02 `111:3681`이며
2026-10-13 22:23:08 KST(13:23:08 UTC)에 다시 조회했습니다.

```bash
# frontend/ — 단위 회귀와 기존 안전 영역 검사를 함께 실행합니다.
flutter test --no-pub test/scaled_navigation_layout_test.dart test/home_alignment_test.dart test/top_safe_area_test.dart
flutter analyze --no-pub
flutter test --no-pub

# 실제 공유 탭의 여섯 사용 화면 및 확대 탭 단독 검사: 대역 데이터/합성 포인터입니다.
flutter run --no-pub -d <device-id> -t test/support/navigation_layout_preview.dart
```

`test/scaled_navigation_layout_test.dart`는 Android/iOS 설정, 폭 320·375px, 배율 1·1.5·2에서
하단 탭 높이·라벨·아이콘 정렬·활성 표시·네 탭과 추가 버튼 입력, 긴 카테고리의 말줄임·전체 행 탭을 검사합니다.
상세의 페이지 이동/저장 진입과 Placeholder의 실제 Navigator 복귀도 확인합니다.
제품 두 위젯에 대한 수정 전 실패를 재현한 후 수정 코드에서 전체 Flutter 테스트 **625 passed**와
`flutter analyze --no-pub` **문제 없음**을 확인했습니다.

`navigation_layout_preview.dart`는 실제 홈·아카이브·즐겨찾기·마이·상세·Placeholder를 일반 배율로 순회하고,
공통 탭은 375px의 배율 1.5/2 및 320px의 배율 2에서 따로 검사합니다.
실제 탭·홈 카드·상세 이전/다음·Placeholder 복귀와 추가 버튼 중심/하단 입력을 합성 포인터로 실행합니다.
`clipback-navigation-*` 기기 임시 폴더에 PNG 9개와 `report.json`을 저장하며 `NAV_LAYOUT PASS/FAIL`을 출력합니다.
실제 세션·HTTP·네이티브 공유·저장은 사용하지 않고, 제품 진입점은 `lib/main.dart`로 유지합니다.

최종 iOS/Android 홈 프리뷰는 모두 통과했습니다. 동일한 여섯 비교 상태의 프레임워크 오류는 플랫폼별
**14건 → 0건**이며 수정 후 `passed`·`checksCompleted`·동작 완료·확대 촬영 완료는 모두 `true`입니다.
바 높이 96px/140px(배율 1/2), 추가 버튼 72×72px·위로 22px 위치, 스크롤·페이지 점·저장 시트의
키보드·닫기를 확인했습니다. 최종 공유 내비게이션 프리뷰도 양 플랫폼에서
`passed`·`checksCompleted: true`, 프레임워크 오류 0건·`failure: null`로 통과했습니다.
바 높이 96/124/140px(배율 1/1.5/2), 네 아이콘 정렬·탭, 상세 이전/다음 각 1회와
Placeholder 복귀, 세 확대 조건에서 추가 버튼 중심/하단 입력 총 6회를 확인했습니다.
여섯 실제 본문은 일반 배율이며 확대는 공통 탭 단독 검사라는 범위를 유지합니다.
기종·OS·최종 코드의 측정값과 영상은 [프론트 진행 기록](../docs/fe-merge-fixes.md)에 기록하며
과거 커밋의 성공을 이번 결과로 사용하지 않습니다.
비교 자료 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout`이고
`comparison-document.html`과 플랫폼별 `ios-expanded-comparison.html`·`android-expanded-comparison.html`에서
변경 전·후·Figma를 원본 그대로 비교합니다. 확대 Figma 화면을 임의로 만들어 채우지 않습니다.

마이·상세 본문의 배율 2에는 변경 전부터 있는 별도 넘침이 있어 새 배치를 임의로 구현하지 않았습니다.
이 두 본문의 통합 검사는 일반 배율이며, 공통 탭 단독 확대 성공을 전체 본문 성공으로 확대하지 않습니다.
본문 확대 디자인과 진입/저장 화면의 별도 홈 인디케이터는 [디자인 확인 필요 목록](../docs/figma-ui-alignment-plan.md#디자인-확인-필요)에 남깁니다.
실제 OAuth·운영 서버·실기기·원격 CI는 이번 로컬 화면 검증에 포함하지 않습니다.

## OS 하단 안전 영역과 공통 인디케이터 (`a9eb69d`)

아래 Figma 노드·조회 시각과 692개 테스트·기기 화면/영상은 이전 `svNWsTFh8Ws1Mpt8XQIcrN / 261007` 당시의 검증입니다.
사용자가 승인한 OS 안전 영역 정책은 새 디자인 기준에서도 유지합니다.

사용자가 승인한 공통 바의 총높이는 **64px + 글자 확대 증가분 + `viewPadding.bottom`**입니다.
기기 하단 안전 영역은 한 번만 더하며 키보드의 `viewInsets.bottom`은 더하지 않습니다.
별도 `SafeArea`로 다시 합산하지 않고, 기존 두 줄 라벨·아이콘 정렬·활성 색상과 네 탭의 콜백을 유지합니다.
추가 버튼은 72×72px·중앙·바 위로 22px 위치와 중심/바 안쪽 하단 입력을 유지합니다.
Figma의 고정 96px과 달리 기기 inset에 따라 바 상단과 본문 사용 높이가 달라집니다.

공통 탭을 사용하는 홈·아카이브·즐겨찾기·마이·상세·Placeholder와 카드 다시보기가 이번 범위입니다.
카드 다시보기의 빈/일반 목록 양쪽은 하단 `SafeArea`를 적용하며, 일반 목록은 `ClipRect`를
실제 하단 안전 영역 앞에서 끝냅니다. 기존 카드 크기·상단 좌표·드래그/전환을 유지하고 OS 영역에 그리지 않습니다.
공통 `NavigationHomeIndicator`와 두 사용부를 제거하고 실제 인디케이터 표시를 OS에 맡깁니다.
OS 플래그·화면 생성자·API·데이터 모델·콘텐츠 보존/삭제 처리와 상세 페이지 이동/시트 입력 계약은 변경하지 않습니다.

이 공통 바 커밋 당시 진입 스플래시의 `EntryHomeIndicator`와 저장 화면의 `_SaveHomeIndicator`·본문/버튼 배치는 보류했습니다.
진입 스플래시는 계속 보류하며 저장 창은 아래 사용자 확정 기준의 후속 하단 작업으로 분리합니다.
마이·상세 본문의 글자 배율 2 넘침도 기존 디자인 확인 대상으로 남기며,
공통 탭 단독 확대 검사를 전체 본문 성공으로 보고하지 않습니다.
기준 Figma는 공통 탭 `111:3680`, C01 `111:3584`, C02 `111:3681`, G02 `111:5047`이고
2026-10-14 01:58:26 KST(2026-10-13 16:58:26 UTC)에 최초 조회하고,
제품 수정 직전 2026-10-14 02:28:08 KST(2026-10-13 17:28:08 UTC)에 원본을 다시 조회했습니다.

```bash
# frontend/ — 관련 회귀와 전체 검사입니다.
flutter test --no-pub test/bottom_safe_area_test.dart test/scaled_navigation_layout_test.dart test/home_alignment_test.dart test/top_safe_area_test.dart test/save_search_safe_area_test.dart test/sheet_safe_area_test.dart
flutter analyze --no-pub
flutter test --no-pub

# 코드 수정 전에 같은 기기·데이터·배율·스크롤·OS 내비게이션 모드로 세 프리뷰를 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_home_preview.dart \
  --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=before
flutter run --no-pub -d <device-id> -t test/support/navigation_layout_preview.dart \
  --dart-define=NAV_LAYOUT_PHASE=before
flutter run --no-pub -d <device-id> -t test/support/card_review_safe_area_preview.dart \
  --dart-define=CARD_REVIEW_PHASE=before

# 수정 후에는 세 PHASE 값을 각각 after로 바꿔 동일 조건에서 다시 실행합니다.
# 실제 OS 인디케이터 확인용 원본 화면도 별도로 확보합니다.
# SIMULATOR_ID/EMULATOR_ID는 연결된 기기의 로컬 ID로 지정합니다.
xcrun simctl io "$SIMULATOR_ID" screenshot /private/tmp/clipback-ios-bottom-safe-area.png
adb -s "$EMULATOR_ID" exec-out screencap -p > /private/tmp/clipback-android-bottom-safe-area.png
```

`test/bottom_safe_area_test.dart`는 폭 320·375px, 배율 1·1.5·2와 하단 inset 0·24·34·48px에서
공통 바 높이·탭/FAB 입력·키보드 전후 inset 유지·가짜 인디케이터 없음과 카드의 하단 보호를 검사합니다.
카드의 빈/일반 상태와 드래그·전환 중 하단 렌더링 픽셀도 확인합니다.
이번 수정 후 관련 검사 **148개**와 전체 Flutter 테스트 **692개**를 통과했고 정적 분석은 **문제 없음**입니다.
관련 검사는 하단 67·확대 30·홈 35·상단 11·저장/검색 2·시트 3개이며 Dart 파일 7개의 형식 검사도 변경 없이 통과했습니다.
최종 iOS·Android 제스처·Android 3버튼의 세 프리뷰, 총 9개 `after` 보고서가 모두
`passed`·`checksCompleted: true`, 프레임워크 오류 0건·`failure: null`로 통과했습니다.
이전 625개 테스트나 기기 통과를 이번 결과로 사용하지 않습니다.
수정 전 iOS·Android 제스처·Android 3버튼의 프리뷰 세 종류, 총 9개 보고서는 모두
`phase: before`, `passed`·`checksCompleted: true`와 프레임워크 오류 0건을 확인했습니다.
새 안전 영역 기준은 `after`에서만 검사하므로 변경 전 통과가 중복 인디케이터나 안전 영역 문제의 부재를 뜻하지 않습니다.

이번 홈 프리뷰는 `before`·`after` 양쪽에서 여섯 비교 상태와 다섯 동작 화면, 총 11장을 촬영하고
스크롤·저장 시트/키보드·닫기를 확인합니다.
내비게이션 프리뷰는 실제 여섯 본문 일반 배율과 공통 탭 단독 확대를 구분하고 실제 탭·상세 이전/다음·복귀를 확인합니다.
카드 프리뷰는 실제 다시보기의 일반·드래그 중·다음 카드·빈 목록 PNG 네 장과
북마크·카드 열기·드래그 진입·전환·양쪽 나가기, 하단 viewport/inset을 기록합니다.
각각 `clipback-home-*`, `clipback-navigation-*`, `clipback-card-review-*`에 PNG·`report.json`을 생성하고
`FIGMA_HOME`, `NAV_LAYOUT`, `CARD_REVIEW`의 `PASS/FAIL`을 출력합니다. 실제 세션·HTTP·저장은 사용하지 않습니다.
Flutter 캡처는 실제 OS 인디케이터를 포함하지 않으므로 `simctl`·`adb` 원본 캡처와 플랫폼별 영상을 함께 보존합니다.

증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area`입니다.
`ios`, `android-gesture`, `android-three-button`의 `before`/`after` 아래 `home`, `navigation`, `card-review`로 구분합니다.
각 모드의 phase마다 홈 11장·내비게이션 9장·카드 4장, 총 24개 화면을 기록합니다.
수정 전에는 원본 OS 캡처와 Flutter 캡처 각 72개·영상 9개를 보존했습니다.
수정 후에도 같은 수의 원본 OS/Flutter 캡처와 영상을 보존했습니다.
이번 측정에서 iOS의 하단 inset 34px·바 높이 98/126/142px(배율 1/1.5/2),
Android 두 모드의 `viewPadding.bottom` 0px·바 높이 64/92/108px을 확인했습니다.
카드 viewport 하단은 iOS 818px, Android 제스처 783.2727px·3버튼 759.2727px로 안전한 영역 끝과 일치했습니다.
Android 3버튼 모드에서는 OS 영역이 Flutter 화면 바깥을 차지하므로 바에 그 높이를 다시 더하지 않습니다.
카드의 고정 496px·드래그/다음 카드·북마크·열기·양쪽 나가기, 상세 이전/다음·Placeholder 복귀·추가 버튼 입력을 확인했습니다.
여섯 실제 본문의 일반 배율과 공통 탭 단독 확대 검사의 한계는 유지합니다.

[원본 3열 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/comparison-document.html)는
3조건 × 홈 6개·내비게이션 9개·카드 4개, 총 57개 비교를 제공합니다. 원본 PNG와 OS 픽셀을 보정하지 않습니다.
동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/ios/interaction-final.mp4),
[Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-gesture/interaction-final.mp4),
[Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/bottom-safe-area/android-three-button/interaction-final.mp4).
플랫폼·내비게이션 모드별 원본 변경 전·후·Figma를 나란히 비교하고 OS 안전 영역과 디자인 프레임의 차이를 설명합니다.
기종·OS·글자 배율·화면 상태·측정값·영상·누락된 비교 항목은 [프론트 진행 기록](../docs/fe-merge-fixes.md)에 기록합니다.
실제 OAuth·운영 서버·실기기·원격 CI는 이 로컬 대역 화면 검증으로 증명하지 않습니다.

## 저장 결과 문구와 제출 입력 고정 (`a14111f`, 2026-10-15)

작업 기준은 `b905769`이고 최신 `261008`의
[링크 결과 D05](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16639)와
[사진 결과 D09](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16602)를 대상으로 합니다.
상세 컨텍스트·원본을 구현 직전 2026-10-15 17:28:27 KST(08:28:27 UTC)에 다시 조회했습니다.
사진 결과는 ‘저장할 사진’으로 표시하고 링크 검증 문구와 전용 5px 간격을 제거합니다.
링크 결과의 ‘저장할 링크’·‘유효한 링크예요!’는 유지합니다.

요청 직전의 URL/파일명·사진 바이트 참조를 실제 저장 콜백과 성공 결과에 함께 사용합니다.
요청 중 탭 이동·다른 초안 편집·재선택은 허용하고, 성공하면 제출한 종류의 탭으로 돌아가 결과 맨 위를 한 번 표시한 뒤
닫을 때까지 결과·탭을 고정합니다. 실패하면 현재 초안을 유지하고 재시도 시 그때의 입력을 새로 캡처합니다.
늦게 완료된 사진 선택기·붙여넣기와 오래된 제출 콜백은 성공 결과·스크롤을 바꾸거나 재저장하지 않습니다.

공개 `SavedContentConfirmation` 생성자·콜백·API·저장 시점·분류·콘텐츠 보존은 유지합니다.
사진 프리뷰 배치/비율, 결과 상단 80px·고정 미리보기, 카테고리 추가/제거(DEC-03), 하단 버튼/스크롤과
`_SaveHomeIndicator`는 후속 범위이며 [계획과 디자인 확인 목록](../docs/figma-ui-alignment-plan.md#디자인-확인-필요)을 따릅니다.

```bash
# frontend/ — 집중 회귀입니다. 관련 검사·전체 검사는 진행 기록의 실제 결과를 따릅니다.
flutter test --no-pub test/saved_content_confirmation_test.dart

# 연결된 Simulator/Emulator ID로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# 수정 후 같은 기기·데이터·배율·스크롤 상태에서 PHASE를 after로 바꿔 다시 실행합니다.

# Android에서는 기기 서버 8767을 호스트 8768로 연결합니다.
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl http://127.0.0.1:8768/status
curl http://127.0.0.1:8768/run
# iOS Simulator의 제어 주소는 http://127.0.0.1:8767 입니다.
```

프리뷰는 실제 저장 위젯·대역 사진 선택기·메모리 저장 콜백과 합성 포인터/텍스트 입력을 사용합니다.
서버는 프리뷰 조작을 위한 루프백 제어용이며 실제 백엔드·인증·저장을 사용하지 않습니다.
`a14111f` 당시 `/scene?kind=photo|link&scale=1|2`, `/run`, `/keyboard`, `/scroll`, `/status`를 제공했고
기기 임시 `clipback-save-result-*`에 PNG·`report.json`을 저장합니다.
실제 OS 화면은 별도 `simctl`·`adb` 원본 캡처와 영상으로 기록합니다.

집중 검사 **11개**·관련 검사 **132개**·전체 Flutter 테스트 **703개**를 통과했고 정적 분석은 **문제 없음**입니다.
변경 전·후 배율 2에서 기존 결과 미리보기의 높이 100px 텍스트 열 넘침은
iOS 46px·Android 47px, 선택 전 `PhotoEmptyPrompt`의 89px 안내 열 넘침은 2px·4px였습니다.
선택된 사진을 표시하는 `SelectedPhotoPreview` 자체의 텍스트 열 오류로 분류하지 않습니다.
`checksCompleted`·`behaviorPassed`와 `layoutPassed`·전체 `passed`를 구분하며 기존 레이아웃 실패를 문구 수정의 성공으로 덮지 않습니다.
이번 범위는 위 문구·상태 고정이며 확대 배치를 임의로 바꾸지 않습니다.
수정 후 양 플랫폼의 18개 기록은 `checksCompleted`·`behaviorPassed: true`이고
`layoutPassed`·전체 `passed: false`입니다. 기존 배율 2의 오류 종류·크기는 전후 동일합니다.

iPhone 16/iOS 18.6은 논리 393×852·DPR 3·안전 영역 상단 59px/하단 34px,
Pixel 3a 설정의 Android 13/API 33 제스처 모드는 논리 392.7×783.3·DPR 2.75·상단 24px/하단 0px입니다.
실제 저장 창에서 문구·제출 입력·탭 복귀/고정·수동 재시도·닫기/늦은 완료를 확인했습니다.
사진 결과 배율 2의 스크롤 위치는 iOS 124px·Android 161.727px이었습니다.
키보드는 양쪽 OS 캡처에서 보였으며 iOS inset은 336px입니다. Android는 보이는 IME와 달리 Flutter 스냅샷의
`viewInsets.bottom`이 0이어서 키보드 inset 반영 검증은 한계로 남겼습니다.

증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording`입니다.
[원본 변경 전·후·Figma 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/comparison-document.html),
[iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/ios/after/interaction.mp4),
[Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/android/after/interaction.mp4)을 보존했습니다.
두 플랫폼의 링크/사진·배율 1/2, 원본 OS 화면 비교 8건의 조건·파일·해시를 대조했습니다.
최종 기종·OS·자동/기기 결과와 미검증 범위는 [프론트 진행 기록](../docs/fe-merge-fixes.md)에 기록했습니다.
실제 공급자·AI/OCR·운영 서버·실기기·원격 CI는 이번 대역 렌더링으로 검증하지 않습니다.

## 저장 화면의 확대 글자 높이 (`5d12e9d`, 2026-10-15)

`a14111f`를 기준으로 **글자를 줄이지 않고 필요한 만큼 높이를 늘리는** 사용자 기준을 적용합니다.
사진 선택 전 안내는 최소 89px, 링크·사진 결과 미리보기는 최소 116px이며 기본 배율의 기존 크기를 유지합니다.
텍스트 열은 자연 높이를 사용하고 `TextScaler`·글꼴·글자 크기를 바꾸지 않습니다.
40×40px 선택 아이콘·좌우 16px·기존 간격, 결과 카드 안쪽 8px·164×100px 썸네일·제목 최대 두 줄·출처 한 줄·말줄임과
이미지/텍스트 세로 중앙 정렬을 유지합니다. 배율별 높이나 수동 글자 높이 계산은 추가하지 않습니다.

최신 `261008`의 D06 `912:16524`·D05 `912:16639`·D09 `912:16602` 컨텍스트·기본 원본을
2026-10-15 17:56:18 KST(08:56:18 UTC)에 확보했습니다. 제품 수정 직전 D05 재조회는 18:07:32 KST(09:07:32 UTC)에 성공했고
D06·D09는 Starter 호출 한도에 막혀 같은 작업에서 확보한 위 원본·컨텍스트를 사용했습니다.
확대 전용 디자인은 없으므로 기본 원본과 사용자 확정 기준을 구분해 비교합니다.
사진 확대/잘림·결과 상단 80px·카테고리·하단 버튼과 인디케이터·안전 영역은 이번 범위에서 바꾸지 않습니다.
공개 생성자·콜백·API·모델·실제 제출 입력과 완료 탭 고정·저장 시점도 유지합니다.

```bash
# frontend/ — 새 확대 검사와 기존 입력·탭·키보드 회귀입니다.
flutter test --no-pub test/save_scaled_layout_test.dart test/saved_content_confirmation_test.dart test/save_search_safe_area_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 같은 고정 프리뷰를 before/after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# 아래는 iOS 주소입니다. Android 호스트 요청은 8768 포트를 사용합니다.
curl 'http://127.0.0.1:8767/scene?kind=photo-empty&scale=1.5'
curl http://127.0.0.1:8767/run
```

이 커밋 당시 프리뷰는 `kind=photo-empty|link|photo`, 배율 `1|1.5|2`의 9개 상태를 제공했으며
`photo_empty_scale_1_5.png`처럼 배율별 파일명을 구분합니다. `/status`, `/scene`, `/run`, `/scroll`, `/keyboard`, `/keyboard-hide`를 제공합니다.
`/run`은 양 phase에서 기존 문구·제출 입력·성공 탭 고정·중복 제출 방지·실패 후 재시도·재선택·확대 스크롤·늦은 응답·키보드 표시/해제를 검사합니다.
안내·미리보기·텍스트·이미지 경계/크기와 실제 글자 크기를 `report.json`에 기록하고 AFTER에서는 새 레이아웃을 엄격 판정합니다.
제품 수정 전 고정한 파일 SHA256은 `2e45d3ca0d562b52bf6f9accf498b70034fd09f73a596c2c608c5568a61e3880`이며 변경 전·후에 같은 파일을 사용합니다.

제품 수정 전 iPhone 16/iOS 18.6·Android 13/API 33의 세 상태·배율 1/1.5/2를 새로 촬영했습니다.
새 확대 검사는 제품 수정 전 **38개 중 18개 실패·20개 통과**로 넘침을 재현했습니다. 수정 후
집중 확대 검사 **38개**(5초)·관련 회귀 **170개**(32초)·전체 Flutter 테스트 **741개**(1분 20초)를 통과했습니다.
`flutter analyze --no-pub`는 **문제 없음**(12.2초)입니다. 수정 후 두 플랫폼 보고서는 각각 **32개 기록·프레임워크 오류 0건**이며 `checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`입니다.
이번 변경 전 기기 보고서는 두 플랫폼 각각 32개 기록이며 `checksCompleted`·`behaviorPassed: true`, `layoutPassed`·전체 `passed: false`였습니다.
안내/결과 텍스트 열의 확대 넘침을 iOS 2px/46px·Android 4px/47px로 재현했습니다. 이번 변경 전 키보드 inset은 iOS 336px·Android 274.909px로
양쪽에서 측정했으며 위 `a14111f` 당시 Android 0px 한계와 구분합니다.
iPhone 16/iOS 18.6은 논리 393×852·DPR 3·안전 영역 상단/하단 59/34px,
Pixel 3a 설정/Android 13(API 33) 제스처 모드는 논리 392.7×783.3·DPR 2.75·상단/하단 24/0px입니다.
배율 1/1.5의 안내·미리보기 높이는 두 플랫폼 모두 89/116px, 배율 2는 iOS 91/162px·Android 93/163px입니다.
썸네일 164×100px·기존 글자 크기와 배율·텍스트 경계·세로 중앙 정렬을 확인했습니다.
양쪽에서 저장·재선택·실패 후 재시도·요청 중 탭 이동·완료 탭 고정·확대 본문 스크롤·닫기/늦은 응답을 확인했습니다.
키보드 표시/해제 inset은 iOS 336→0px·Android 274.909→0px이고 양쪽 OS 원본에서 표시를 확인했습니다.
이전 `a14111f`의 테스트·확대 오류·기기 결과는 위 당시 기록에 남기고 이번 통과로 사용하지 않습니다.

증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout`입니다.
[변경 전 → 변경 후 → Figma 비교 18건](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/comparison-document.html),
[iOS 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/ios/after/interaction.mp4),
[Android 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-scaled-layout/android/after/interaction.mp4)을 제공합니다.
동일 기종·데이터·배율·스크롤 위치의 OS 원본과 Figma 기본 원본을 비교하고 실제 안전 영역 차이를 설명합니다.
확대용 대체 디자인을 만들지 않으며 사진 비율/잘림·상단/하단 배치의 보류 범위를 표시합니다. 저장 화면 전체 디자인 맞춤의 완료로 보고하지 않습니다.
실제 서버·인증·AI/OCR·실기기·원격 CI는 대역 프리뷰 검증 범위에 포함하지 않습니다.

## 저장 화면 하단 안전 영역과 버튼 겹침 (2026-10-15, 해당 범위 적용·검증 완료)

현재 작업 기준은 `5d12e9d`입니다. 사용자 승인으로 본문 스크롤과 하단 CTA/토스트 영역을 분리하고,
버튼 아래 **`32 + max(viewInsets.bottom, viewPadding.bottom)`**을 한 번만 적용합니다.
키보드가 열리면 키보드 위 32px, 닫히면 실제 OS 안전 영역 위 32px을 유지합니다.
공통 내비게이션의 `64 + fontExtra + viewPadding.bottom` 및 키보드 높이를 더하지 않는 정책은 그대로이며,
입력 화면인 저장 창에 적용하는 위 회피 정책과 구분합니다.

본문 하단 패딩 24px·버튼 높이 56px/좌우 16px·토스트 좌우 40px/버튼 위 16px·토스트 3초 표시를 유지합니다.
토스트 표시 중에는 본문이 토스트 뒤로 이어지지 않도록 필요한 높이를 확보합니다.
저장 창의 `_SaveHomeIndicator`를 제거하고 실제 탐색 표시는 OS에 맡깁니다.
글자 축소·사진 비율/잘림·결과 상단 80px·카테고리 편집·공개 생성자/콜백/API/모델과 저장 정책은 바꾸지 않습니다.

이번 작업의 구현 준비 중 **2026-10-15 18:53:53 KST(09:53:53 UTC)**의 D01 `912:16502`·D06 `912:16524`·D07 `912:16551`·D05 `912:16639`·D09 `912:16602`
재조회는 모두 Figma Starter 호출 한도에 막혔습니다. D05는 앞선 확대 작업의 **18:07:32 KST(09:07:32 UTC)**,
D06/D09는 **17:56:18 KST(08:56:18 UTC)** 원본·컨텍스트를 출처와 함께 사용하며 이번 새 조회로 보고하지 않습니다.
D01/D07은 기존 원본도 없어 Figma 칸을 미확보로 표시합니다. 확대·키보드 전용 디자인이나 누락 원본을 만들어 채우지 않습니다.
기본 비교는 3개 기기/탐색 구성 × 5개 상태 × 3개 배율의 45쌍을 대상으로 하며,
이 중 D06/D05/D09 27건은 세 화면 비교, D01/D07 18건은 Figma 누락 사유를 표시합니다. 키보드·오류·최대 스크롤의 추가 비교는 45쌍이며 최종 산출/매체 확인은 별도 검증 기록을 따릅니다.

```bash
# frontend/ — 하단 배치와 기존 입력/사진 보존 회귀입니다.
flutter test --no-pub test/save_footer_layout_test.dart test/save_search_safe_area_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 같은 고정 프리뷰를 before/after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# iOS 주소이며 Android 호스트 요청은 8768 포트를 사용합니다.
curl 'http://127.0.0.1:8767/scene?kind=link-input&scale=1.5'
curl 'http://127.0.0.1:8767/scene?kind=photo-selected&scale=2'
curl 'http://127.0.0.1:8767/keyboard?scale=2'
curl 'http://127.0.0.1:8767/error?scale=1.5&keyboard=1'
curl 'http://127.0.0.1:8767/scroll?max=1'
curl http://127.0.0.1:8767/run
```

현재 프리뷰는 `kind=link-input|photo-empty|photo-selected|link|photo`, 배율 `1|1.5|2`의 15개 장면과
`/status`·`/scene`·`/run`·`/scroll?max=1`·`/keyboard?scale=...`·`/error?scale=...&keyboard=1`·`/keyboard-hide`를 제공합니다.
기존 `link`/`photo`는 성공 결과이며 새 `link-input`/`photo-selected`는 제출 전 입력 상태입니다.
제품 수정 전 동결한 SHA256은 `4b0ab767520f98b570a5741b1ca1f6cb5cbc4eaf6257005857765f9ebccc7cd3`이고 변경 전·후 동일 소스를 사용합니다.
`report.json`은 본문 viewport/마지막 항목/버튼/토스트의 경계와 실제 inset·최대 스크롤,
`targetLayoutFindings`·`targetLayoutPassed`를 기록합니다. `layoutPassed`·전체 `passed`는 프레임워크 오류뿐 아니라 실제 하단 정책 위반도 반영합니다.

BEFORE는 새 정책 위반을 기록하면서 기존 동작 검사를 계속하고 AFTER는 이를 엄격 판정합니다.
IME에 가려진 BEFORE 버튼은 합성 탭으로 OS 창을 우회할 수 있어 접근 가능 증거로 쓰지 않습니다.
`/run`은 해당 기대 실패를 기록한 뒤 키보드를 닫아 재시도를 이어갑니다. AFTER는 실제 양수 keyboard inset·입력 보존·실패/재시도·완료 탭·닫기를 확인합니다.
선택 사진이 viewport보다 클 때는 최대 스크롤의 사진 하단 노출을, 마지막 안내 텍스트는 전체 경계를 검사합니다.

최초 재현 실행은 하단 검사 96개 모두 실패·기존 저장/검색 2개 중 1개 실패로 **98개 중 1개 통과·97개 실패**였습니다.
수정 후 집중 **98개**(8초)·관련 8개 파일 **266개**(20초)·전체 Flutter 테스트 **837개**(76초)가 통과했고
`flutter analyze --no-pub`는 **문제 없음**(5.1초)입니다.
제품 수정 전 iOS·Android 제스처·Android 3버튼 각각 30장, 총 **90장**의 OS 원본을 새로 확보하고 `before-gate.json`의 해시 검증 뒤 제품을 수정했습니다.
세 구성의 BEFORE는 각각 **87개 기록·프레임워크 오류 0건**, 동작 완료/보존은 통과하지만 하단 정책 위반으로 `layoutPassed`·전체 `passed: false`입니다.
AFTER는 iOS **84개 기록**·Android 제스처 **86개 기록**(촬영 재시도 2개 포함)·3버튼 **84개 기록**, 각각 프레임워크 오류 0건·`checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`입니다.
각 구성의 기본 15장·추가 15장, 총 90장의 AFTER OS 원본을 새로 확보했습니다.

실제 창은 iOS 논리 393×852·DPR 3·안전 영역 59/34px,
Android 제스처 392.7×783.3·DPR 2.75·24/0px, Android 3버튼 392.7×759.3·DPR 2.75·24/0px입니다.
Android 3버튼은 OS 탐색 바가 Flutter 창 밖에 있어 창이 24px 짧으므로 이미 반영된 여백을 다시 더하지 않습니다.
키보드 표시/해제 inset은 iOS 336→0px, Android 제스처 274.909→0px·3버튼 250.909→0px입니다.
AFTER 버튼 아래 간격은 iOS 키보드 없음/있음 66/368px, Android 키보드 없음 32px·표시 시 각각 306.909px/282.909px로 승인식에 일치했습니다.
본문/버튼/토스트 분리·마지막 안내의 최대 스크롤·키보드 실패/재시도/닫기와 기존 제출/완료 탭 정책을 세 구성에서 확인했습니다.
두 Android 구성은 실제 `adb shell input tap`으로 키보드 위 중심 탭의 원래 URL 1회 저장·완료 탭 유지·버튼 하단 2px 탭의 닫기도 확인했습니다.
각 `native-taps/report.json`의 다섯 검사는 모두 `true`이며 실제 저장 API가 아닌 메모리 콜백입니다.
검증 후 탐색 모드/오버레이를 원래 제스처 설정으로 복원했고 `android-navigation-restored.json`의 `restored: true`를 확인했습니다. 임시 포워딩 제거·에뮬레이터 종료도 마쳤습니다.

변경 전 Android 제스처 배율 1.5 오류 토스트는 최초 촬영 시 표시가 끝나 OS 원본을 재촬영했습니다. 최초 시도는 보존하고 전체 87개 보고서는 수정하지 않았습니다.
해당 변경 전 키보드 화면에서 기존 64×44px ‘붙여넣기’ 버튼의 확대 문구 두 줄 잘림도 확인했습니다.
버튼 크기/줄 정책은 D01 원본 및 확대 디자인이 없어 [디자인 확인 필요 목록](../docs/figma-ui-alignment-plan.md#디자인-확인-필요)에 남기며 이번 하단 작업에서 바꾸지 않습니다.
기본 45쌍의 본문 노드 225개에서 폭·높이·글자 크기/배율·줄 수·말줄임 변경 0건, fixture 동결 SHA 일치를 확인했습니다.
이전 `5d12e9d`의 통과 결과는 이번 성공으로 사용하지 않으며 이번 결과를 저장 화면 전체 디자인·확대 표시 완료로 보고하지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area`입니다.
[기본 45쌍·추가 45쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-document.html),
[iOS 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/interaction.mp4)·[iOS 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/ios/after/layout-keyboard.mp4),
[Android 제스처 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/interaction.mp4)·[제스처 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/layout-keyboard.mp4),
[Android 3버튼 동작](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/interaction.mp4)·[3버튼 키보드/레이아웃](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/layout-keyboard.mp4),
[제스처 실제 OS 탭 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-gesture/after/native-taps/report.json)·[3버튼 실제 OS 탭 보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/android-threebutton/after/native-taps/report.json)를 제공합니다.
OS 원본을 보정하지 않으며 [최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/comparison-qa.json)에서 기본/추가 각 45쌍의 조건 불일치 0건·BEFORE 원본 90개 해시 불변·토스트 36개 상태 누락 0건을 확인했습니다.
[이번 촬영 영상 14개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-footer-safe-area/media-verification.json)를 모두 끝까지 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했습니다.
iOS/Android 빌드는 성공했고 기존 Kotlin 2.2.10 지원 종료 예정·Java native-access 경고는 빌드 실패와 구분합니다.
운영 서버·실제 인증/저장·실기기·원격 CI는 대역 프리뷰 검증에 포함하지 않습니다.

## 붙여넣기 입력행의 확대 글자 높이 (`b0d0c71` 기준, 해당 범위 적용·검증 완료)

사용자는 **글자를 줄이지 않고 필요한 높이를 늘리며 URL 입력박스도 붙여넣기 버튼과 같은 높이로 확장**하는 기준을 확정했습니다.
두 영역의 기본·최소 높이는 44px이고 확대 시 실제 글자 레이아웃에 맞춰 같은 높이로 늘어납니다.
붙여넣기는 폭 64px·기존 14px/Medium·자간 −0.35px·최대 두 줄과 세로 중앙 배치를 유지하며,
URL은 한 줄 입력·기존 글자 크기·18px 지우기 아이콘·8px 간격을 유지합니다.
`IntrinsicHeight`와 공통 최소 44px로 입력행을 맞추고 suffix 영역 안에서 지우기 아이콘을 중앙에 둡니다. 지우기 아이콘의 기존 실제 탭 영역 48×44px을 보존해 기본 URL viewport 폭과 아이콘의 가로 위치를 유지합니다.
붙여넣기 글자 위아래에는 각각 1px의 경계 여유를 적용합니다. 기본 높이 44px은 유지하고 확대 시 자연 높이에 총 2px을 더해 실제 줄 경계가 버튼 밖으로 나가지 않게 합니다.
배율별 높이 상수·수동 글자 높이 계산·글자 축소·글꼴 줄 높이 재정의는 추가하지 않습니다.

이번 범위는 확대 입력행의 표시이며 기존 하단 `32 + max(viewInsets.bottom, viewPadding.bottom)`·56px 저장 버튼,
실제 제출 입력·완료 탭 고정·실패/수동 재시도·공개 생성자/콜백/API/모델은 바꾸지 않습니다.
사진 비율·잘림·카테고리 편집·저장 화면 전체 맞춤은 후속으로 남깁니다.
이번 작업의 Figma D01 `912:16502` 컨텍스트 재조회는 **2026-10-15 20:21:07 KST(11:21:07 UTC)**, 원본 스크린샷 재조회는 같은 분에 시도했으나 둘 다 Starter 호출 한도로 실패했습니다.
기존 D01 원본도 없으므로 비교의 Figma 칸은 누락 사유를 표시합니다. 사용자 확정 확대 기준을 Figma에 새로 존재하는 디자인으로 표시하지 않습니다.

```bash
# frontend/ — 확대 입력행과 붙여넣기 동작 회귀입니다.
flutter test --no-pub test/save_paste_layout_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 모바일 Simulator/Emulator에서 같은 프리뷰를 before/after로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# Android: adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
# iOS 주소이며 Android 호스트 요청은 8768 포트를 사용합니다.
curl 'http://127.0.0.1:8767/paste-scene?scale=1.5&keyboard=0'
curl 'http://127.0.0.1:8767/paste-scene?scale=2&keyboard=1'
curl http://127.0.0.1:8767/paste-run
```

`/paste-scene`은 배율 `1|1.5|2`와 키보드 `0|1`의 여섯 장면을 제공합니다.
`paste_scale_1_5_keyboard_1.png`처럼 이름을 구분하고 같은 URL·커서 끝 위치·본문 스크롤 0으로 맞춥니다.
프리뷰는 iOS/Android 앱의 `Clipboard.setData`로 고정 URL을 넣고 실제 붙여넣기 버튼을 Flutter 합성 포인터로 누릅니다.
Mac 클립보드 API를 사용하지 않으며 `/paste-run`은 붙여넣기·직접 입력·지우기·유효/무효 검증·키보드·드래그·실패/재시도·완료 탭 고정·닫기를 검사합니다.
기존 `/run`과 다섯 저장 장면은 유지합니다. 실제 서버·인증·저장은 사용하지 않습니다.

제품 수정 전 동결한 프리뷰 SHA256은 `93390e39a9ffb71613cbc9a3c3df1dc2c33eebd7638af925f3d7390a935af4de`입니다.
보고서의 `geometry`는 입력행·URL 박스·EditableText·지우기 버튼/아이콘·붙여넣기 버튼/문단을 기록합니다.
`pasteMetrics`의 실제 `RenderParagraph` 줄 경계·전체 문구·폰트·배율·줄 수·문단/입력/아이콘 중앙 정렬과
`pasteLayoutFindings`·`pasteLayoutPassed`를 하단 판정에 합산합니다. BEFORE는 새 기준의 실패를 기록하고 기존 동작을 계속 검사하며 AFTER는 엄격 판정합니다.
기존 실제 저장 창 위젯 검사 22개는 FontLoader에 Pretendard를 로드했어도 버튼의 상속 스타일 `fontFamily: null`로 테스트 기본 글꼴을 사용했습니다. 이 검사를 실제 Pretendard 렌더링 증거로 보고하지 않습니다.
추가 13개는 모두 Pretendard family를 명시한 분리 모델입니다. 12개는 제품 버튼 스타일·자식에서 family만 바꾼 폭/배율/플랫폼 조합이며, 1개는 상속 행간 1.18·안쪽 여백 없음·기존 고정 44px을 대조합니다. 실제 저장 창·네이티브 상속 글꼴·분리 Pretendard 모델의 결과를 구분합니다.
네이티브 프리뷰는 `fontFamily: null` 기록을 그대로 유지하며 제품의 글꼴 설정을 바꾸지 않습니다. 기존 14px/Medium·자간·실제 배율과 줄 경계를 계속 검사합니다.
최초 네이티브 시도의 `fontFamily` 강제 판정 오탐은 별도 보존하고, 해당 판정만 교정한 위 동결 소스로 모든 구성의 변경 전 화면을 새로 촬영했습니다.
`before-gate.json`은 제품 원본·동결 SHA와 18개 변경 전 OS 원본 확보를 확인합니다. BEFORE 보고서는 iOS 24개·Android 제스처 30개(재촬영 6개 포함)·3버튼 24개 기록이며, 모두 프레임워크 오류 0건·동작 통과·`layoutPassed`/전체 `passed: false`입니다.

집중 회귀 **35개**·[관련 10개 파일의 330개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/related-green-final.log)(14초)·[전체 Flutter 테스트 872개](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/full-test.log)(50초)를 통과했습니다. [정적 분석](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/tests/analyze.log)은 **문제 없음**(3.6초)이며 Dart 세 파일 포맷 검사도 **0개 변경**으로 통과했습니다. 중간 네이티브 AFTER의 공통 높이 60px에서는 상속 글꼴의 실제 줄 경계가 버튼 위로 약 0.408px 벗어나 엄격 검사에 실패했습니다. 글꼴 높이 동작을 바꾸는 시도는 제거하고 위아래 1px 여유를 적용했으며, Android 배율 1.5 단독 재검사에서 공통 높이 62px·모든 줄 경계 포함을 확인했습니다. 허용 오차를 넓히지 않았습니다.
중간 AFTER는 지우기 탭 영역을 34px로 줄여 기본 URL viewport가 14px 넓어지고 지우기 아이콘이 7px 이동한 문제가 추가로 확인됐습니다. 기존 실효 48×44px 탭 영역으로 복원하고 모든 구성의 AFTER를 새로 촬영했습니다. 이전 Android 3버튼 AFTER는 레이아웃 플래그가 통과했어도 가로 배치 보존을 충족하지 못해 `.attempts/after-clear-hit-width`에 별도 보존하며 최종 증거로 쓰지 않습니다.
지우기 탭 영역을 복원한 최종 AFTER는 iOS·Android 제스처·3버튼 각각 **24개 기록·프레임워크 오류 0건**이며,
`checksCompleted`·`behaviorPassed`·`layoutPassed`·전체 `passed`가 모두 `true`입니다.

| 실제 실행 환경 | 배율 1/1.5/2의 공통 높이 | 키보드·실행 결과 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6, 논리 393×852·DPR 3·상단/하단 59/34px | 44/52/70px | IME 336px, 24개 기록·오류 0건·네 완료 플래그 통과 |
| Android 13/API 33 제스처, 392.7×783.3·DPR 2.75·상단/하단 24/0px | 44/62/84px | IME 274.909px, 24개 기록·오류 0건·네 완료 플래그 통과 |
| 같은 Android 3버튼, 392.7×759.3·DPR 2.75·상단/하단 24/0px | 44/62/84px | IME 250.909px, 24개 기록·오류 0건·네 완료 플래그 통과 |

높이는 각 플랫폼의 상속 글꼴과 실제 TextScaler에 따른 측정값이며 배율별 고정 목표값이 아닙니다.
[18쌍 최종 비교 QA](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-qa.json)는 조건 불일치 0건·BEFORE 원본 해시 불변·fixture/최종 빌드 소스 일치·폰트/초안 변경 0건·입력/지우기 가로 기하 변경 0건과 모든 실제 줄 경계 포함을 확인했습니다.
기본 배율의 채워진 URL 여섯 상태는 박스 크기/색상과 지우기 아이콘 픽셀을 보존했습니다. 붙여넣기 글자의 raster·커서 깜박임 차이는 원본 그대로 기록하며 전체 픽셀 동일로 보고하지 않습니다.
빈 URL 상태는 위젯 검사와 지우기 동작으로 확인했고 별도 네이티브 빈 상태 픽셀 쌍은 촬영하지 않았습니다.
네이티브의 최종 플랫폼 글꼴 식별자는 측정하지 않아 Pretendard 실행 증거로 보고하지 않습니다.
[Android 탐색 복원 기록](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-navigation-restored.json)의 `matchesOriginal: true`로 원래 모드 2와 전체 여섯 오버레이 일치를 확인했습니다. 포워딩 8768 제거·에뮬레이터와 iOS Simulator 종료를 마쳤고 시뮬레이터/AVD 데이터는 보존했습니다.
[영상 검사](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/media-verification.json)는 이번 BEFORE/AFTER 영상 여섯 개 모두 전체 디코딩 종료 코드 0·오류 로그 0바이트를 확인했습니다. 중간 반복의 검사·단독 재검사나 이전 `b0d0c71`의 성공은 최종 결과로 사용하지 않습니다.
증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled`이며 기본 비교는 3개 기기/탐색 구성 × 3개 배율 × 키보드 2개 상태의 18쌍입니다.
[18쌍 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-document.html)·[비교 manifest](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/comparison-manifest.json)·[전후 상태 검증](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/pair-verification.json)을 제공합니다.
18건 모두 변경 전/후 두 원본을 나란히 표시하며 Figma 칸에는 D01 미확보 사유를 표시합니다. 완전한 세 원본 비교는 0건이고 확대용 대체 이미지는 만들지 않았습니다.
AFTER 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/ios/after/interaction.mp4), [Android 제스처](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-gesture/after/interaction.mp4), [Android 3버튼](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-paste-scaled/android-threebutton/after/interaction.mp4).
사진 비율/잘림·카테고리 편집 등 보류 디자인은 유지하며 이 결과를 저장 화면 전체 디자인 맞춤이나 실제 서버·인증·운영 저장·실기기·원격 CI 성공으로 보고하지 않습니다.

## 상단 안전 영역과 헤더

일반 화면의 헤더 높이는 `shared/theme/layout.dart`의 `appHeaderHeight`(64 논리 픽셀)를
사용합니다. 시스템 상태바·노치 높이는 이 64px에 포함하지 않습니다. 각 `Scaffold.body`에서
상단 `SafeArea`를 한 번 적용하며, `PhoneFrame`이나 헤더 안에서 중복 적용하지 않습니다.
공통 하단 내비게이션 높이는 위 공통 바의 OS 안전 영역 기준을 따릅니다. 저장 버튼은 별도 저장 창 정책의 `32 + max(viewInsets.bottom, viewPadding.bottom)`을 적용하며 검색 화면의 기존 하단 SafeArea는 유지합니다.

전체 화면 저장 창은 별도 Navigator 경로이므로 자체 SafeArea를 가집니다. 하단 시트는 호출부의
`useSafeArea: true`로 최대 높이를 보호하며, 시트 내용에 일반 화면의 64px 헤더를 강제하지 않습니다.
로그인·온보딩·관심사 선택은 기존 배치를 유지합니다. 홈 헤더만 상단 여백 8px + 내부 높이 56px으로 구성하고 본문과 함께 스크롤합니다. 다른 화면의 `appHeaderHeight` 64px은 유지합니다.

랜덤 보기는 기존 단일 Stack·카드 기하를 유지하고 상·하단 안전 영역 내부의 ClipRect로 드래그 중 시스템 영역 침범을 막습니다.

`top_safe_area_test.dart`는 상단 inset 0/20/44/59/62와 375×812·430×932에서 헤더 위치·높이·탭을
검사하고, 스크롤·드래그 중 상태바 영역의 렌더링 픽셀을 비교합니다.
`auth_safe_area_test.dart`, `save_search_safe_area_test.dart`, `sheet_safe_area_test.dart`는
인증 배치, 입력·선택 사진 보존, 높은 시트와 상세 이미지 요청 공유를 검증합니다.

기기에서 화면만 확인하려면 아래 테스트 전용 진입점을 사용합니다. 실제 `ClipbackApp`에 HTTP 대역과
메모리 세션·인증을 연결하므로 운영 서버나 기기에 저장된 실제 세션을 사용하지 않습니다.
지원하지 않는 HTTP 요청은 오류로 끝나며 실제 서버로 전달하지 않습니다. 새 의존성은 필요하지 않습니다.

```bash
# frontend/에서 실행. 연결된 기기의 ID를 지정합니다.
flutter run --no-pub -d <iPhone-device-id> -t test/support/safe_area_preview.dart

# 화면 콜백·합성 포인터로 자동 순회하고 기기 좌표 및 PNG를 기록합니다.
flutter run --no-pub -d <iPhone-device-id> -t test/support/safe_area_device_check.dart
```

자동 순회는 앱 임시 폴더에 `report.json`과 PNG를 저장하고 경로 및 PASS/FAIL을 출력합니다.
무선 iOS 실행에서 Flutter 터미널에 앱 로그가 보이지 않으면 Xcode 콘솔이나 기기의
`tmp/clipback-safe-area-*` 결과 파일을 확인합니다.
이 결과는 **실제 기기의 렌더링과 프로그램 입력 검증**이며 사람의 수동 탭·실제 OAuth·운영 API 검증과
구분합니다. 이 진입점을 출시하지 않으며 제품 빌드의 진입점은 계속 `lib/main.dart`입니다.

## Android 개발 실행

Android SDK Platform 36을 설치하고, 실제 기기는 개발자 옵션의 USB 디버깅을 켠 뒤
Mac의 디버깅 연결을 허용합니다. `flutter doctor --android-licenses`로 필요한 라이선스를
확인하고 동의한 다음 실행합니다.

```bash
# frontend/에서 실행
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <Android-device-id> --debug --no-pub
```

실행 중 터미널에서 `r`로 hot reload, `R`로 hot restart를 할 수 있습니다.
Android Gradle 설정·네이티브 플러그인을 바꿨다면 실행을 종료한 뒤 다시 빌드합니다.
기기 없이 APK 빌드만 확인하려면 `flutter build apk --debug --no-pub`를 사용합니다.

현재 잠금파일의 `file_picker` 8.3.7은 API 34로 컴파일하도록 설정되어 있지만,
`flutter_plugin_android_lifecycle` 2.0.35는 API 36 이상을 요구합니다.
`android/build.gradle.kts`에서 `file_picker` 모듈에만
[`finalizeDsl`](https://developer.android.com/reference/tools/gradle-api/9.0/com/android/build/api/variant/LibraryAndroidComponentsExtension)을 적용해
compileSdk를 36으로 맞춥니다. 앱의 minSdk·targetSdk와 패키지 잠금파일은 유지합니다.
`file_picker`를 업데이트할 때 플러그인 자체의 compileSdk를 확인하고 이 보정의 필요성을 재검토합니다.

2026-10-08 검증 환경은 Flutter 3.44.9 / Dart 3.12.2, AGP 9.0.1 / Gradle 9.1.0입니다.
수정 전 `:file_picker:checkDebugAarMetadata` 실패를 재현하고 수정 후 통과를 확인했습니다.
`flutter build apk --debug --no-pub`, `flutter analyze --no-pub`, `flutter test --no-pub`의
기존 테스트 400개가 통과했습니다. `flutter run --debug --no-pub --no-resident`로
연결된 SM-S938N(Android 16)에 설치·실행하고 홈의 빈 콘텐츠 화면을 확인했습니다.
사진 선택·업로드, 다른 앱에서 공유받기와 Release 빌드는 이번 검증에 포함하지 않습니다.

## iOS 개발 실행

iOS 프로젝트는 `ios/Runner.xcworkspace`로 엽니다. 앱 이름은 **허투루**, Bundle ID는
`com.huturu.app`이며, Debug·Profile·Release의 서명 Team은 `8X6N747PQM`으로 설정되어 있습니다.
실제 기기 실행에는 해당 팀의 접근 권한과 유효한 서명·프로비저닝이 필요합니다.
Runner의 Deployment Target은 현재 Xcode의 `Recommended` 설정을
사용합니다(Xcode 27.0에서는 iOS 17). Xcode 버전을 바꾸면 실제 최소 버전을 다시 확인합니다.

이번 준비에는 Flutter **3.44.9 / Dart 3.12.2**를 사용했습니다. 터미널의 `flutter --version`으로
SDK를 먼저 확인하세요. 더 오래된 Flutter로 잠금파일을 다시 생성하지 않습니다.

```bash
# frontend/에서 실행
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
open ios/Runner.xcworkspace
```

첫 빌드에서 Flutter 설정·플러그인 등록 파일과 Swift 패키지를 생성하고, Xcode가 네이티브
의존성을 내려받습니다. `Generated.xcconfig`, `GeneratedPluginRegistrant.*`,
`Flutter/ephemeral/`은 자동 생성물이므로 직접 작성하거나 커밋하지 않습니다.

실제 iPhone은 Mac에 연결하고 기기에서 신뢰·개발자 모드를 설정한 뒤, Xcode의 Runner 타깃에서
본인의 Team과 자동 서명을 확인합니다. 실행 대상으로 연결된 iPhone을 선택해 Run하거나
다음 명령을 사용합니다. 기기 설정은 [Flutter iOS 준비 문서](https://docs.flutter.dev/platform-integration/ios/setup)를 따릅니다.

```bash
flutter devices
flutter run -d <iPhone-device-id> --no-pub
```

현재 Runner에는 Sign in with Apple entitlement가 있으므로 실제 기기 빌드는 해당 capability를
지원하는 Apple Developer Program 팀과 프로비저닝이 필요합니다. TestFlight도 이 프로그램을 사용합니다
([Apple 계정 안내](https://developer.apple.com/help/account/basics/about-your-developer-account)).
시뮬레이터 빌드 성공만으로 기기 서명이나 설치 성공을 판단하지 않습니다.
기본 API는 HTTPS Railway 주소이며, 실제 기기에서 로컬 서버에
연결할 때는 `127.0.0.1` 대신 기기가 접근할 수 있는 서버 주소를 사용합니다.

### TestFlight 권한 설명과 재업로드

`ios/Runner/Info.plist`에는 `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`,
`NSLocationWhenInUseUsageDescription`을 유지합니다. 사진 권한 설명은 선택한 사진·스크린샷을
저장하고 분류하는 목적입니다. 현재 앱은 사진 보관함에서 이미지를 선택하며 카메라와 현재 위치에는
접근하지 않으므로, 나머지 두 문구도 미사용 사실을 안내합니다.

`file_picker` 8.3.7의 Swift Package 의존성인 `DKImagePickerController`에 `DKCamera`가 포함되어
카메라·위치 API가 바이너리에 연결됩니다. 해당 기능을 호출하지 않아도 App Store Connect의
정적 검사에서 `ITMS-90683`이 발생할 수 있습니다. 설명 키만 추가해 카메라나 위치를 요청하지는
않습니다. 의존성을 변경할 때는 미사용 API 포함 여부와 이 설명들의 필요성을 함께 재확인합니다.

권한 설명을 수정한 뒤에는 새 빌드 번호로 배포용 바이너리를 다시 만듭니다. 아래는 빌드 1 다음에
빌드 2를 올리는 예시이며, 이미 업로드한 번호보다 큰 값을 사용합니다. 위 공개 앱 설정의 세 값을
환경변수에 지정하고 `SocialAuth.xcconfig`도 준비해야 합니다. Android Studio의 실행 인자는
터미널 빌드에 자동 전달되지 않습니다.

```bash
# frontend/에서 실행
flutter build ipa --release --no-pub --build-number=2 \
  --dart-define="CLIPBACK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define="CLIPBACK_GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID" \
  --dart-define="CLIPBACK_KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY"
open build/ios/archive/*.xcarchive
```

Xcode Organizer에서 새 아카이브를 검증하고 `Distribute App → App Store Connect`로 업로드합니다.
이전 아카이브에는 수정된 문구가 반영되지 않습니다. 로컬 빌드 성공과 App Store Connect 처리·심사
통과는 별도이며, 새 빌드의 처리 결과와 실제 사진 선택·저장 동작을 확인합니다.

2026-10-08 로컬 준비 검증: Flutter 3.44.9에서 `pub get --enforce-lockfile`, `analyze --no-pub`,
기존 테스트 400개와 iOS 시뮬레이터 Debug 빌드를 통과했습니다. `flutter run --debug --no-pub
--no-resident`로 iPhone 16 Pro(iOS 18.6) 시뮬레이터에 설치·실행하고 홈의 빈 콘텐츠 화면을
확인했습니다. 실제 iPhone 서명·설치, 사진 선택·업로드, TestFlight 업로드와 갤럭시 설치는
이 검증에 포함하지 않습니다.

이 Mac에서는 생성된 `Flutter.framework`에 `com.apple.FinderInfo`가 반복 부착되어 서명이
실패했습니다([Apple의 오류 설명](https://developer.apple.com/library/archive/qa/qa1940/_index.html)).
프로젝트 소스와 전역 Flutter 설정은 유지하고, `build/ios` 생성물만
`~/Library/Caches/Clipback/` 아래로 옮겨 원래 경로에 심볼릭 링크를 만들고,
이전 위치의 속성이 남은 생성 프레임워크를 재생성한 뒤 빌드·실행했습니다.
이 링크는 로컬 환경용이며 Git에 포함하지 않습니다. `flutter clean` 등으로 빌드 폴더를
다시 만들면 동일 오류가 재발하는지 확인하고, 필요한 경우 출력 경로를 다시 분리합니다.

## Backend integration boundaries

Use the backend public HTTPS domain and `/api/v1` exactly once in request URLs.
Protected APIs require the backend-issued Bearer access token. Account data and
statistics should come from `/users/me` and `/users/me/stats`; display statistics as
누적 저장 / 누적 열람, not current content totals.

The existing similar-content section filters already-loaded items by category;
today's content opens the first local item. Neither is a server recommendation.
The feed has no total-count field. Reminder and notification screens use mock data.
See [MVP scope decisions](../docs/backend-mvp-plan.md) before adding APIs for these.

For public URL and web CORS configuration, follow the
[deployment guide](../docs/railway-deployment.md).

## 모바일 공유 저장

시스템 공유 목록에서 **허투루**를 선택하면 링크·이미지와 저장 계정을 확인하고 바로 저장합니다.
iOS는 Swift Share Extension, Android는 Java `ShareActivity`를 사용합니다. 이 경로는 Flutter
엔진을 새로 띄우거나 기존 수동 저장 화면·홈·상세로 이동하지 않습니다. 외부 공유를 닫으면 송신
앱으로, 본앱에서 대기 초안을 재개한 경우에는 본앱의 원래 화면으로 돌아옵니다.

- 지원: Instagram·YouTube 링크 하나 또는 PNG·JPEG·WebP 한 장(기본 10MiB).
  여러 장·동영상·HEIC 변환·공유 화면 안의 로그인·분류 편집은 지원하지 않습니다.
- 본앱의 기존 로그인/게스트 선택·세션 복원 후 저장 전용 자격을 준비합니다. 처음 업데이트한 뒤
  본앱을 한 번 열어야 합니다. 자격이 없거나 만료되면 초안을 보관하고 본앱에서 확인하도록 안내하며,
  본앱을 강제로 열거나 새 게스트를 자동 생성하지 않습니다.
- 기기 공유 자격을 읽지 못한 경우 재시도는 공유 자격 차단·재발급을 먼저 시도합니다.
  본앱 로그인이나 보관한 초안을 초기화하지 않습니다.
- 본앱의 대기 항목 안내에서 초안을 선택하면 같은 네이티브 공유 UI로 재개합니다. 안내의 `나중에`는
  현재 화면만 가리고 있던 안내를 닫습니다. 다음 앱 복귀 때 대기 항목을 다시 확인합니다.
- 초안은 최대 10개·총 100MiB·7일입니다. 한도 초과 시 기존 항목을 임의로 지우지 않습니다.
  이미 전송한 초안은 최초 저장 계정으로만 재시도합니다.
- 요청은 30초 제한이며 응답 유실·전송 후 닫기는 결과 불명으로 보관합니다. 같은 초안의 UUID를
  `Idempotency-Key`로 재사용하므로 새 저장을 반복하지 않습니다. 서버 생성 응답을 받으면 완료이며
  YouTube 요약 완료나 자동 백그라운드 저장을 기다리지 않습니다.

`lib/data/services/native_share_service.dart`의 `com.huturu.app/share` 채널은 자격 준비·차단,
대기 초안·성공 영수증 조회, 네이티브 UI 재개만 연결합니다. 영속 원본은 각 플랫폼 저장소이며
Dart Repository는 같은 데이터를 별도로 저장하지 않습니다. `app/actions/share_coordinator.dart`는
세션 저장 콜백 밖에서 자격을 발급하고, 계정 변경 전에 영속 revision을 올려 이전 자격을 차단합니다.
성공 영수증은 같은 계정·API 환경의 카테고리·활성 목록·통계 갱신 후 소비합니다. 목록은 이미 읽어 둔 범위를
한 번에 갱신해 현재 화면·필터·스크롤을 보존하며, 실패 시 기존 항목·커서로 이어서 조회합니다.
후속 조회 실패는 저장 재전송 사유가 아닙니다.

자격은 `POST /auth/share-credential`에서 발급하며 본앱 access/refresh 토큰과 분리합니다.
네이티브 코드는 공유 토큰으로 `/contents/share`, `/uploads/screenshots`만 호출합니다.
백엔드 migration·권한·중복 방지 계약은 [백엔드 README](../backend/README.md)를 따릅니다.
백엔드와 migration을 먼저 배포한 후 앱을 배포해야 합니다.

### 플랫폼 설정

- iOS: Runner `com.huturu.app`, 확장 `com.huturu.app.ShareExtension`, App Group
  `group.com.huturu.app`, 공유 Keychain `$(AppIdentifierPrefix)com.huturu.app.share`.
  기존 기본 Keychain 그룹과 소셜 설정은 유지합니다. 실기기·배포 시 Apple 개발자 계정에
  App Group과 두 App ID의 capabilities를 등록하고 프로비저닝을 갱신해야 합니다.
- Android: application ID `com.clipback.frontend` 유지. 공유 수신 Activity에만 `ACTION_SEND`
  `text/plain`·`image/*`를 등록하며 복구 Activity는 외부에 공개하지 않습니다.
  자격은 Android Keystore AES-GCM으로 암호화해 앱 전용 저장소에 기록합니다.
- Dart와 두 네이티브 구현의 API 주소는 같은 `CLIPBACK_API_BASE_URL` 빌드 값을 사용합니다.
  저장된 자격의 대상 환경이 빌드 주소와 다르면 저장하지 않습니다. 릴리스에서 로컬 HTTP를
  허용하지 않으며, 웹·데스크톱은 네이티브 공유 연동 없이 기존 수동 저장을 사용합니다.

### 로컬 공유 검증

HTTP 대역은 Flutter와 네이티브 양쪽에서 실제 소켓으로 접근합니다. 운영 서버 fallback은 없습니다.

```bash
# frontend/ — 별도 터미널에서 유지
python3 tool/share_fixture_server.py

# iOS Simulator
flutter run --no-pub -d <simulator-id> -t test/support/share_preview.dart \
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18765/api/v1

# Android Emulator
flutter run --no-pub -d <emulator-id> -t test/support/share_preview.dart \
  --dart-define=CLIPBACK_API_BASE_URL=http://10.0.2.2:18765/api/v1
```

`SHARE_PREVIEW_SIGNED_OUT=true`를 추가하면 미로그인 초안 복구를 확인할 수 있습니다.
실제 FastAPI·전용 PostgreSQL 검증은 백엔드 README의 `share_live_server`를 실행하고,
주소를 18766 포트로 변경한 뒤 `SHARE_PREVIEW_REAL_BACKEND=true`를 추가합니다.
이 경우 본앱의 게스트 시작 버튼으로 테스트 서버 세션을 발급받습니다.
외부 OAuth·AI/OCR·metadata는 대역이며 실제 공급자 동작이나 운영 저장을 증명하지 않습니다.

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
flutter build apk --debug --no-pub
flutter build ios --simulator --debug --no-pub
```

기존 Flutter 회귀 테스트에 공유 자격·계정 차단·오래된 발급·영수증·목록 범위 보존 테스트를
추가했습니다. 네이티브 저장소와 실제 OS 공유 UI 검증은 각 플랫폼 테스트 타깃으로 별도 수행합니다.
공유 확장·실제 Keychain·송신 앱 UI 테스트 명령은 [iOS 공유 검증 안내](ios/ShareVerification/README.md)를 참고합니다.
Android의 Keystore·수신 Activity·HTTP 테스트와 API 33·36 재현 명령은
[Android 공유 검증 안내](android/SHARE_TESTING.md)에 있습니다.
실행 환경과 실제 결과는 [프론트 진행 기록](../docs/fe-merge-fixes.md)에 기록합니다.
