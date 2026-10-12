# Clipback Frontend

Flutter mobile frontend for the Clipback MVP.

FE 병합 전 수정 순서와 PR별 검증 결과는
[FE 병합 전 수정 진행 현황](../docs/fe-merge-fixes.md)에 기록합니다.

현재 FE는 인증·콘텐츠·카테고리·계정 통계를 API와 연동합니다.
추천·알림 등 일부 화면은 로컬 또는 mock 동작이 남아 있으며, 아래 연동 범위와 진행 문서를 따릅니다.

The current implementation mirrors the supplied Figma flows:

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

## 상단 안전 영역과 헤더

일반 화면의 헤더 높이는 `shared/theme/layout.dart`의 `appHeaderHeight`(64 논리 픽셀)를
사용합니다. 시스템 상태바·노치 높이는 이 64px에 포함하지 않습니다. 각 `Scaffold.body`에서
상단 `SafeArea`를 한 번 적용하며, `PhoneFrame`이나 헤더 안에서 중복 적용하지 않습니다.
기존 하단 내비게이션·저장 버튼 위치는 유지하고 검색 화면의 기존 하단 SafeArea도 유지합니다.

전체 화면 저장 창은 별도 Navigator 경로이므로 자체 SafeArea를 가집니다. 하단 시트는 호출부의
`useSafeArea: true`로 최대 높이를 보호하며, 시트 내용에 일반 화면의 64px 헤더를 강제하지 않습니다.
로그인·온보딩·관심사 선택은 기존 배치를 유지합니다. 홈 헤더는 본문과 함께 스크롤하고,
랜덤 보기는 기존 단일 Stack을 유지하되 안전 영역 내부의 ClipRect로 드래그 중 노치 침범을 막습니다.

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
