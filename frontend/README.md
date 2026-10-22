# Clipback Frontend

Flutter 앱의 현재 코드 구조·설정·실행과 API 연결 안내입니다.
기준 커밋의 정적 확인과 과거 실행 결과를 구분합니다. 상세 변경·검증·실패·미검증 범위는
[작업·검증 이력](../docs/history/README.md)에 한 번만 기록합니다.
사용자 변경은 [업데이트 내역](../CHANGELOG.md), 공개 여부는 [배포 절차](../docs/release-process.md)를 따릅니다.

## 코드 구조와 의존 방향

화면·루트 상태·데이터 처리를 아래 경계로 나눕니다. Flutter 기본 `ChangeNotifier`와 생성자 주입을 사용합니다.
구조 분리 당시의 검사와 한계는 [작업 이력](../docs/history/README.md)을 확인합니다.

| 경로 | 책임 |
| --- | --- |
| `lib/main.dart` | 앱 시작 진입점 |
| `lib/app/` | 의존성 조립·화면 연결·UI 효과를 처리하는 앱 View와 인증·화면 흐름을 조정하는 AppViewModel |
| `lib/app/actions/` | 여러 Repository를 사용하는 계정 초기화·콘텐츠 변경 후 갱신 순서 |
| `lib/data/repositories/` | 세션, 콘텐츠·카테고리·피드, 사용자·서버 통계, 계정별 최근 검색어, 네이티브 공유 Repository의 계약과 구현 |
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

## 초기 세션 복원과 재시도

- 앱 시작에는 A01을900ms 표시하면서 세션 복구를 병렬 실행합니다. 이후 복구 완료 시 기존 로그인/홈, 진행/오류 시 기존 복구·재시도 화면으로 이어집니다. 카테고리·피드 조회가 끝나기 전에는 홈·샘플 콘텐츠·저장 기능을 노출하지 않습니다. 공유 준비/안내·UI 효과·최신 저장 실패 배너는 후속 첫 프레임 뒤 재개하며 보안 차단·세션 무효화·Apple credential 확인은 지연하지 않습니다.
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
공통 하단 내비게이션은 시스템 하단 안전 영역을 유지합니다. 저장 버튼은 별도 저장 창 정책의 `32 + max(viewInsets.bottom, viewPadding.bottom)`을 적용하며 검색 화면의 기존 하단 SafeArea는 유지합니다.

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


## iOS 개발 실행

iOS 프로젝트는 `ios/Runner.xcworkspace`로 엽니다. 앱 이름은 **허투루**, Bundle ID는
`com.huturu.app`이며, Debug·Profile·Release의 서명 Team은 `8X6N747PQM`으로 설정되어 있습니다.
실제 기기 실행에는 해당 팀의 접근 권한과 유효한 서명·프로비저닝이 필요합니다.
Runner의 Deployment Target은 현재 Xcode의 `Recommended` 설정을
사용합니다(Xcode 27.0에서는 iOS 17). Xcode 버전을 바꾸면 실제 최소 버전을 다시 확인합니다.


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

권한 설명을 수정한 뒤에는 새 빌드 번호로 배포용 바이너리를 다시 만듭니다. `APP_BUILD_NUMBER`에
이미 업로드한 번호보다 큰 미사용 값을 로컬에서 지정합니다. 위 공개 앱 설정의 세 값을
환경변수에 지정하고 `SocialAuth.xcconfig`도 준비해야 합니다. Android Studio의 실행 인자는
터미널 빌드에 자동 전달되지 않습니다.

```bash
# frontend/에서 실행
flutter build ipa --release --no-pub -t lib/main.dart --build-number="$APP_BUILD_NUMBER" \
  --dart-define="CLIPBACK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define="CLIPBACK_GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID" \
  --dart-define="CLIPBACK_KAKAO_NATIVE_APP_KEY=$KAKAO_NATIVE_APP_KEY"
open build/ios/archive/*.xcarchive
```

Xcode Organizer에서 새 아카이브를 검증하고 `Distribute App → App Store Connect`로 업로드합니다.
이전 아카이브에는 수정된 문구가 반영되지 않습니다. 로컬 빌드 성공과 App Store Connect 처리·심사
통과는 별도이며, 새 빌드의 처리 결과와 실제 사진 선택·저장 동작을 확인합니다.



## Backend integration boundaries

Use the backend public HTTPS domain and `/api/v1` exactly once in request URLs.
Protected APIs require the backend-issued Bearer access token. Account data and
statistics should come from `/users/me` and `/users/me/stats`; display statistics as
누적 저장 / 누적 열람, not current content totals.

Today uses the server recommendation response and opens the recommended detail sequence.
Weekly loads server cards, opens the selected category, and records actual visible-card exposures.
Similar content still filters already-loaded items by category. The feed has no total-count field.
Reminder and notification screens retain mock data; see [MVP scope decisions](../docs/backend-mvp-plan.md).

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

## 현재 기능 연결과 디자인 기준

- Today·Weekly, 최근 검색어, 시스템 뒤로가기는 기준 커밋에 연결되어 있습니다. 작업별 실제 검증과 한계는 이력 목차를 확인합니다.
- 구조는 `lib/main.dart` → `lib/app/` → 기능 ViewModel·Action·Repository로 이어집니다. 추천 상세 흐름은 `app/clipback_app.dart`와 `features/content/view_models/detail_view_model.dart`에서 조정합니다.
- 현재 디자인·확인 필요 상태는 [Figma 맞춤 기준](../docs/figma-ui-alignment-plan.md)을 따릅니다.
- 화면별 프리뷰·재현 명령은 관련 작업 기록에 보존합니다. 과거 명령은 당시 코드·기기·데이터 기준이며 제품 빌드에는 `lib/main.dart`를 명시합니다.

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
