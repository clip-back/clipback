# app-v0.6.1-ios-b15-android-b11

## 배포 개요

- 배포 식별자: app-v0.6.1-ios-b15-android-b11
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-15T17:23:55+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 글꼴을 따로 주지 않은 글자 Pretendard (#391, CHANGELOG 앱 0.6.1 수정); [앱] 홈 최근 저장한 콘텐츠 카드 가운데 맞춰 멈춤 (팀 피드백 시트 53, #389, CHANGELOG 앱 0.6.1 수정); [앱] HEIC 사진 JPEG 변환 저장·지원 형식 안내 (팀 피드백 시트 100, #380, CHANGELOG 앱 0.6.1 수정); [앱] 홈 이번주 허투루 픽 시작 로딩에서 받아 한 번에 표시 (팀 피드백 시트 99, #379, CHANGELOG 앱 0.6.1 수정); [Android] 백업·기기 이전에서 로그인 세션 제외 (#363, CHANGELOG 앱 0.6.1 수정); [앱] 이미 지워진 콘텐츠 삭제 404를 성공으로 처리 (팀 피드백 시트 76, #364, CHANGELOG 앱 0.6.1 수정); [앱] 카테고리 목록 랜덤 보기 버튼 띄움 (#355, CHANGELOG 앱 0.6.1 수정); [앱] 이번주 허투루 픽 제목 탭 이동 제거 (#356, CHANGELOG 앱 0.6.1 수정); [앱] 빈 홈 안내 글자 1.3배 넘침 (#357, CHANGELOG 앱 0.6.1 수정); [앱] 미분류 이름 통일 (#358, CHANGELOG 앱 0.6.1 수정); [앱] 화면 아래 안내 마지막 하나만 표시 (#353, CHANGELOG 앱 0.6.1 수정); [앱] 화면 아래 안내 글자 Pretendard (#354, CHANGELOG 앱 0.6.1 수정); [앱] 알림 화면 고정 예시 제거·빈 안내 (팀 피드백 시트 17, #375, CHANGELOG 앱 0.6.1 수정); [앱] YouTube·Instagram 요약 만드는 중·실패 안내 (팀 피드백 시트 38, #376, CHANGELOG 앱 0.6.1 수정); [앱] 로그인 화면 게스트로 시작하기 아래 기준 (팀 피드백 시트 45, #377, CHANGELOG 앱 0.6.1 수정); [앱] 마이 알림 설정·앱 권한 줄 숨김 (팀 피드백 시트 10, #378, CHANGELOG 앱 0.6.1 수정)
- 관련 PR·작업 링크: [스낵바 쌓임·글꼴 #360](https://github.com/clip-back/clipback/pull/360)(#353, #354), [랜덤 보기·픽 제목·빈 홈·미분류 #368](https://github.com/clip-back/clipback/pull/368)(#355–#358), [삭제 404 성공 처리 #371](https://github.com/clip-back/clipback/pull/371)(#364), [Android 백업 로그인 세션 제외 #381](https://github.com/clip-back/clipback/pull/381)(#363), [알림 빈 상태·요약 상태·로그인 아래 기준·마이 관리 줄 #385](https://github.com/clip-back/clipback/pull/385)(#375–#378), [홈 주간 추천 처음부터 표시 #388](https://github.com/clip-back/clipback/pull/388)(#379), [HEIC 사진 저장 #392](https://github.com/clip-back/clipback/pull/392)(#380), [최근 콘텐츠 카드 가운데 멈춤 #393](https://github.com/clip-back/clipback/pull/393)(#389), [Pretendard 기본 글꼴 #394](https://github.com/clip-back/clipback/pull/394)(#391)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.6.0(14)·Android 0.6.0(10)](app-v0.6.0-ios-b14-android-b10.md)
- 후보 준비 상태·미확인 사유: iOS 0.6.1(15) 아카이브·IPA와 Android 0.6.1(11) AAB 빌드 완료(2026-11-15). 두 산출물 모두 업로드 대상 후보이며 업로드 금지로 지정한 산출물은 없음. 사용자 승인(2026-11-15 "진행해줘", 조율 전달) 뒤 후보 태그 생성·푸시, Android 11은 Play 내부 테스트(internal) 트랙에 초안으로 업로드(2026-11-15 17:48 KST), iOS 15는 App Store Connect에 업로드(2026-11-15 17:50 KST, Upload succeeded). Play 내부 테스트 출시·Alpha 승급, App Store Connect 처리 완료·TestFlight 테스터 제공은 사용자 단계로 미확인. 실기기 확인·정식 공개 미실행

사용자 결정(2026-11-15, 조율 전달): 사용자 버전 0.6.1, iOS 15·Android 11, 소스 main `2db2b19`, 포함 변경은 CHANGELOG `미배포`의 앱·Android 항목 전부. 사용자 원문 "391 뒤에 하자". 스토어 최대 업로드 번호는 사용자 채팅 답 "10, 14"(2026-11-15, 시각 미기재)를 [0.6.0 후보](app-v0.6.0-ios-b14-android-b10.md)와 맞춰 Play Console 10·App Store Connect 14로 해석했고, 조율이 사용자에게 이 해석을 알렸으며 반대라는 정정은 없었습니다.
포함 변경은 모두 `수정` 16개라 [버전 결정](../release-process.md#버전-결정)의 PATCH(0.6.0 → 0.6.1)와 맞습니다. 같은 `미배포`의 `[서버]` 항목 셋(#362 둘, #361)은 [backend-2026-11-15-1](backend-2026-11-15-1.md)로 옮겼습니다.

`app-ios-v0.6.0-b14`(`84ff8b0`)..`2db2b19`의 `frontend/` 변경은 위 PR 아홉과 #387(#372, 삭제 404 계약 보존 테스트만)뿐입니다(`git log 84ff8b0..2db2b19 -- frontend/`). 그 밖의 커밋은 서버(`67b7547` #365: #361, `ce54bc5` #382: #362 — [backend-2026-11-15-1](backend-2026-11-15-1.md)), 테스트·CI(`af2fb2b` #390), 문서(#359, #370, #386)입니다.

팀 피드백 시트(“[허투루] 앱 테스트 피드백”)에서 이 빌드에 든 줄(2026-11-15 17:25 KST 무렵 조회, H열 이슈 기준): B열 10 → #378, B열 17 → #375, B열 38 → #376, B열 45 → #377, B열 53 → #389, B열 72 → #355, B열 74 → #353, B열 75 → #356, B열 76 → #364(H열 "#364·#366", I열 "진행중"), B열 78 → #358, B열 80 → #354, B열 84 → #357, B열 95 → #363, B열 99 → #379, B열 100 → #380. B열 76을 뺀 열네 줄은 I열 "구현 완료". #391은 시트 줄 없음. 시트는 고치지 않았습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-15T17:23:55+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-15T17:23:55+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인(조율 전달, 2026-11-15 채팅 답 "10, 14"를 Play 10·App Store Connect 14로 해석; 정확한 확인 시각은 미확인이라 배포 세션 확인 시각 기재) / 2026-11-15T17:25:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 14 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 versionCode https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인(조율 전달, 2026-11-15 채팅 답 "10, 14"를 Play 10·App Store Connect 14로 해석; 정확한 확인 시각은 미확인이라 배포 세션 확인 시각 기재) / 2026-11-15T17:25:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 10 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.6.1 | 0.6.1 |
| 실제 빌드 번호 | 15 | 11 |
| 빌드 소스 SHA | 2db2b19443fcdbfa312cdfa69da3d36957ab263f | 2db2b19443fcdbfa312cdfa69da3d36957ab263f |
| 후보 태그·실제 생성 여부 | app-ios-v0.6.1-b15 (2026-11-15 생성·푸시, annotated) | app-android-v0.6.1-b11 (2026-11-15 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 업로드·실기기 확인 전 | 미결정 — 업로드·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.6.1-ios-b15/Runner.xcarchive`(생성 2026-11-15 17:26 KST), IPA `frontend/build/release-candidates/app-v0.6.1-ios-b15/ipa/clipback_frontend.ipa` 42,383,009바이트, SHA-256 `e818f8edcf765619d8962ea0d3debae02bc9381fc56cb811eb01af99c74e6dd4` — 본앱 `com.huturu.app` 0.6.1(15), 공유 확장 `com.huturu.app.ShareExtension` 0.6.1(15), 팀 `8X6N747PQM`, 권한 설명 3종 존재. 업로드 대상 후보(업로드 금지 아님) | Release AAB 성공. `frontend/build/release-candidates/app-v0.6.1-android-b11/app-release.aab`, 74,595,707바이트, SHA-256 `0f283d535c4566c9c93d493f4d15d4dd53668fc4455db2fae0fc5a8c2034a4da`. versionName 0.6.1·versionCode 11 확인. 업로드 대상 후보(업로드 금지 아님) |
| 업로드·처리 상태 | 후보 아카이브 `app-v0.6.1-ios-b15/Runner.xcarchive`를 `xcodebuild -exportArchive`(destination upload)로 App Store Connect에 업로드 성공(2026-11-15 17:50 KST). 업로드 직후 상태 "Uploaded package is processing". App Store Connect 처리 완료 여부 미확인 | 배포 세션이 Play Developer API로 후보 AAB(`app-v0.6.1-android-b11/app-release.aab`, SHA-256 같음)를 업로드(2026-11-15 17:48 KST, `UPLOAD result=UPLOADED`), versionCode 11. Play 처리 결과 미확인 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미확인 — TestFlight '테스트할 내용' 입력·테스터 그룹 제공은 사용자 단계 | 내부 테스트(internal) 트랙에 초안(draft) 릴리스 "0.6.1 (11)". `check.py` 트랙 조회(17:48 KST): `internal: 0.6.1 (11)[draft]; 10 (0.6.0)[completed]`, `alpha: 0.6.0 (10)[completed]`. 내부 테스트 출시(출시 노트 입력)·Alpha 승급은 사용자가 Play Console에서 함, 미확인 |
| 심사 상태 | 미확인 — 외부 베타 심사 여부는 사용자 단계 | 미확인 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. 같은 시기 서버 변경은 [backend-2026-11-15-1](backend-2026-11-15-1.md) 사후 기록(#361, #362), 그 전 서버 변경은 [backend-2026-11-14-1](backend-2026-11-14-1.md) |
| 서버 소스 SHA·산출물 식별자 | 운영 중 2baefa077ae2658a3896ca09933ba42e07b7db99 / Railway deployment `58c16039-1240-4e5a-8139-5eb49e6c205b`(SUCCESS, 2026-11-15 14:40 KST 생성). 앱 빌드 소스 `2db2b19`와 `backend/`가 같음(`2baefa0..2db2b19`는 앱만 바꿈). `2db2b19` 배포는 17:23 KST 조회에서 WAITING |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `84ff8b0..2db2b19`에 `backend/alembic/versions/` 변경 없음. head `202611060022` 그대로 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 이번 앱 변경은 새 서버 동작에 의존하지 않음. #364는 서버의 기존 404 응답을, #380의 지원 형식 안내는 서버의 기존 형식 거절을, #376은 기존 요약 상태 값을 앱에서 다르게 보여 줌(PR #371·#392·#385). 서버 변경 #361·#362는 이미 운영에 반영됨([backend-2026-11-15-1](backend-2026-11-15-1.md)) |
| 기존 앱과의 호환성 | `/api/v1` 유지. 이번 앱 변경은 요청·응답 형식을 바꾸지 않음. #379는 주간 추천 요청을 앱 실행·계정마다 한 번으로 줄여, 추천 요청·노출 수 집계 기준이 이전 앱과 다름(CHANGELOG 항목). #363은 Android 백업 규칙만 바꿈. 이 산출물과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱, 새 revision 없음) |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-15 17:23 KST): `2baefa0` 네 서비스 SUCCESS, `2db2b19` 네 서비스 WAITING. `/api/v1/health/ready` 200(2026-11-15 17:23 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.6.0(14)·Android 0.6.0(10) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 backend-2026-11-15-1과 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 테스터 안내

앱 후보는 [테스터 안내 양식](TESTER-NOTES.md)으로 쓴 초안과 사용자가 승인한 최종 문구를 남깁니다. 서버 단독 기록은 두 칸 모두 `해당 없음`입니다.

사용자 승인 문구입니다(2026-11-15, 조율 전달 원문 "진행해줘"). 배포 세션이 쓴 초안에서 사용자가 오픈채팅방 공지 두 군데만 고쳤고, 스토어 짧은 안내는 초안 그대로 승인했습니다. 원본은 CHANGELOG `## 앱 0.6.1` 절의 `수정` 16개입니다. 공지 날짜는 실제로 공지하는 날로 바꿉니다.

- 오픈채팅방 공지: 아래 승인 문구. 열여섯 항목을 모두 넣고 비슷한 두 글꼴 항목(#391, #354)을 한 줄로 묶었습니다. 시트 줄이 있는 제보 항목이 있어 "제보 감사합니다"를 둡니다. 초안에서 사용자가 고친 곳: (a) 백업·기기 이전 줄 맨 앞에 "[Android] ", (b) "📲 업데이트 방법"에 iOS 줄 추가([테스터 안내 양식](TESTER-NOTES.md)에 iOS 문구가 없어 지시된 "iOS: TestFlight 앱에서 허투루 → 업데이트"를 씀). 양식의 "줄 끝에 플랫폼 표시를 붙이지 않음"·"Android 줄만 둠"과 다르지만 사용자 결정대로 적용했습니다. 실제 게시 여부·날짜는 사용자 보고 전이라 미확인

```text
[허투루 0.6.1 업데이트 안내] 2026-11-15

🔧 고친 것
- 홈 '최근 저장한 콘텐츠' 카드를 넘기면 두 장이 반씩 걸친 채 멈추던 문제를 고쳤어요. 이제 가장 가까운 카드가 가운데에 맞춰 멈춰요.
- 홈 '이번주 허투루 픽'이 늦게 나타나 아래 내용이 밀리던 문제를 고쳤어요. 이제 앱을 열면 픽까지 한 번에 보여요.
- 홈 '이번주 허투루 픽' 제목을 누르면 아카이브 카테고리로 넘어가던 문제를 고쳤어요. 픽 카드를 누르면 지금처럼 그 카테고리로 가요.
- 저장 화면에서 HEIC 형식 사진을 첨부하면 저장이 안 되고 영어 알림이 뜨던 문제를 고쳤어요.
- 이미 지워진 콘텐츠를 다시 삭제하면 영어 실패 안내가 뜨고 목록에 남던 문제를 고쳤어요.
- YouTube·Instagram 요약을 만드는 중이거나 만들지 못했을 때 '요약'에 저장할 때 넣은 글이 보이던 문제를 고쳤어요. 이제 만드는 중·실패 안내가 보여요.
- 알림 화면에 실제 알림이 아닌 예시 알림이 늘 보이던 문제를 고쳤어요. 알림이 없으면 '아직 받은 알림이 없어요'가 보여요.
- 카테고리 콘텐츠 목록의 '랜덤 보기' 버튼이 목록 위에 떠 있도록 바뀌었어요.
- 분류되지 않은 콘텐츠의 카테고리 이름이 '미분류'로 통일됐어요.
- 화면 아래 안내를 여러 번 띄우면 줄줄이 이어 뜨던 문제를 고쳤어요. 이제 마지막 안내 하나만 보여요.
- 화면 아래 안내, 정렬 메뉴, 버튼 등 일부 글자가 기기 기본 글꼴로 보이던 문제를 고쳤어요. 이제 앱 글꼴로 보여요.
- 로그인 화면이 위로 붙고 아래가 비어 보이던 문제를 고쳤어요.
- 마이의 '알림 설정'·'앱 권한' 줄이 실제와 상관없는 값을 보여 주던 문제로, 기능이 생길 때까지 두 줄을 숨겼어요.
- 글자 크기를 크게 키우면 콘텐츠를 불러오기 전 홈의 빈 안내가 넘치던 문제를 고쳤어요.
- [Android] 백업을 복원하거나 새 기기로 옮기면 로그인 상태까지 옮겨지던 문제를 고쳤어요. 새 기기에서는 다시 로그인해 주세요. 게스트로 쓰던 콘텐츠는 옮겨지지 않아요.
제보 감사합니다 🙏

📲 업데이트 방법
- Android: Play 스토어에서 허투루 → 업데이트
- iOS: TestFlight 앱에서 허투루 → 업데이트
- 아직 안 보이면 몇 시간 뒤에 다시 확인해 주세요.

💬 사용하면서 불편한 점이나 좋았던 점이 있으면 이 방에 편하게 남겨 주세요!
```

- 스토어 짧은 안내: 아래 승인 문구(초안 그대로). Play 출시 노트·TestFlight '테스트할 내용' 입력은 사용자가 하며 입력 여부는 미확인. TestFlight '테스트할 내용'과 Play 출시 노트에 같은 문구를 씁니다. Android에만 해당하는 백업·기기 이전 항목(#363)은 넣지 않아 두 스토어 문구가 같습니다.

```text
0.6.1 업데이트
- 홈 '최근 저장한 콘텐츠' 카드가 가운데에 맞춰 멈추고, '이번주 허투루 픽'이 처음부터 함께 보여요
- HEIC 사진 저장 실패와 지운 콘텐츠를 다시 삭제할 때의 영어 안내 문제를 고쳤어요
- 요약 만드는 중·실패 안내, 알림 빈 안내, '미분류' 이름 통일 등 여러 화면을 고쳤어요
```

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 앱 소스의 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.6.1(15)·공유 확장 0.6.1(15). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | 빌드 뒤 단독 `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.6.1(11)·minSdk 24·targetSdk 36. `jar verified.` 업로드 인증서 SHA-256 `B0:76:98:8A…87:E5:9A:D0`, 빌드 10 AAB의 인증서와 같음. `.so` 12개 중 64비트 8개 모두 16KB 이상 정렬. bundletool 검사는 미실행(미설치) |
| 원격 CI | `2db2b19`의 App Validation (push)·Backend Validation (push) | 모두 success(Backend의 operator-recovery·deployment job은 skipped) | [App Validation run 43694057719](https://github.com/clip-back/clipback/actions/runs/43694057719), [Backend Validation run 43694057793](https://github.com/clip-back/clipback/actions/runs/43694057793). 빌드 시작(17:24 KST) 때는 진행 중이었고 17:28 KST 무렵 확인에서 완료. 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 업로드·테스터 제공 전 |
| 운영 서버 | Railway production 배포 목록, `/api/v1/health/ready` (2026-11-15 17:23 KST) | `2baefa0` SUCCESS, health 200 | 이 앱 후보와 운영 API의 연동은 미실행 |
| 실기기 | 미실행 | 미실행 | 실기기 iPhone에는 설치하지 않음(사용자가 TestFlight로 설치 예정, 조율 지시). Android 실기기도 미실행 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-15 17:23 | 버전·번호 확인 | 지시된 0.6.1·iOS 15·Android 11을 [버전 결정](../release-process.md#버전-결정)·[후보 식별](../release-process.md#후보-식별과-소스-고정)과 대조: 포함 앱 항목이 모두 `수정`이라 PATCH, 로컬·origin 앱 태그 최대 iOS 14·Android 10, 기존 후보 기록과 겹치지 않음 | 멈추지 않고 진행. 작업 브랜치 `chore/app-release-0.6.1-ios-b15-android-b11` |
| 2026-11-15 17:23 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 14, Play 10, 2026-11-15 사용자 답, 시각 미기재라 배포 세션 확인 시각 17:25 KST 기재)로 iOS 0.6.1(15)·Android 0.6.1(11) 예약. 소스 main `2db2b19` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-15 17:24–17:26 | iOS 아카이브·IPA 내보내기 | 빌드 차례 확인(비어 있음) 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter pub get --enforce-lockfile` 뒤 `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.6.1 --build-number=15`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `2db2b19`, 변경은 CHANGELOG·배포 기록뿐 | 147초 성공(pub get 포함), 0.6.1(15) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치, 아카이브 `diff -r` 같음). 업로드 미실행 |
| 2026-11-15 17:27–17:28 | Android AAB | iOS 빌드 종료 후 차례 확인 뒤 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.6.1 --build-number=11`, 운영 API·공개 SDK 설정 지정. 빌드 뒤 단독 `:app:validateReleaseSigning` 통과 | 110초 성공, 0.6.1(11) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 정지. 업로드 미실행 |
| 2026-11-15 17:47 | 태그 생성·푸시 | 사용자 승인(2026-11-15, 조율 전달 원문 "진행해줘": 태그 생성·push, iOS 15 업로드, Android 11 internal 업로드, 테스터 안내 승인(오픈채팅방 공지 두 군데 수정), 기록 브랜치 push·PR). 만들기 전 로컬·origin에 같은 태그 없음, `2db2b19`이 origin/main에 있음을 확인. annotated 태그 `app-ios-v0.6.1-b15`·`app-android-v0.6.1-b11`을 `2db2b19443fcdbfa312cdfa69da3d36957ab263f`에 만들어 origin에 푸시 | origin `ls-remote`로 두 태그가 `2db2b19`을 가리킴을 확인 |
| 2026-11-15 17:47–17:48 | Android 업로드 | 같은 승인. `~/.heoturu-agents/play/upload.py`(`.venv-play`)로 보존 AAB `app-v0.6.1-android-b11/app-release.aab`를 먼저 dry-run(Play 최대 versionCode 10, 11은 새 번호) 뒤 `--release-name "0.6.1 (11)" --confirm-upload`. 트랙은 도구 기본값 internal, 상태는 기본값 draft. 출시 노트는 도구가 지원하지 않아 넣지 않음 | `UPLOAD result=UPLOADED`, AAB SHA-256 `0f283d53…2034a4da` 일치, edit 커밋. `check.py` 트랙 조회(17:48 KST): `internal: 0.6.1 (11)[draft]; 10 (0.6.0)[completed]`, `alpha: 0.6.0 (10)[completed]`. 테스터 제공은 안 됨 — Play Console에서 출시해야 함 |
| 2026-11-15 17:48–17:50 | iOS 업로드 | 같은 승인. 빌드 차례 확인(비어 있음) 뒤 실행. 올리기 전 보존 아카이브가 빌드 직후 아카이브와 같음(`diff -r`)을, 본앱·공유 확장 모두 0.6.1(15)임을 확인. 새로 빌드하지 않고 보존 아카이브를 `xcodebuild -exportArchive -allowProvisioningUpdates`로 업로드. 내보내기 설정은 IPA 내보내기 설정에서 destination만 upload로, 빌드 번호 자동 변경(`manageAppVersionAndBuildNumber`)은 끔. Xcode에 로그인된 계정 사용 | 130초, `Upload succeeded`(17:50:45 KST)·`EXPORT SUCCEEDED`, 한 번 시도. 로그에 Xcode에 등록된 다른 계정 하나의 자격 증명 로드 실패 경고가 있었으나(0.6.0 때와 같음) 업로드에 영향 없음. App Store Connect 처리·TestFlight 제공은 미확인 |
