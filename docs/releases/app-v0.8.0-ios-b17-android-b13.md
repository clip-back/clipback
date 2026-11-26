# app-v0.8.0-ios-b17-android-b13

## 배포 개요

- 배포 식별자: app-v0.8.0-ios-b17-android-b13
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-26T22:33:45+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 공지사항 목록에 서버 최신 공지 표시 (#486, CHANGELOG 앱 0.8.0 추가); [앱] AI 전송 동의 화면 (#477, CHANGELOG 앱 0.8.0 추가); [앱] 마이 → 계정 관리 'AI 전송 동의' 줄 (#479, CHANGELOG 앱 0.8.0 추가); [iOS] [Android] 저장 대기 공유 다시 저장 완료 문구 (#478, CHANGELOG 앱 0.8.0 개선); [앱] 아카이브·즐겨찾기·검색 목록 로딩 스켈레톤 (#472, CHANGELOG 앱 0.8.0 개선); [앱] 홈 최근 저장 목록 로딩 스켈레톤 (#473, CHANGELOG 앱 0.8.0 개선); [앱] 저장 중 회색 막대 밝은 띠 (#471, CHANGELOG 앱 0.8.0 개선); [앱] 월 AI 요약 한도로 건너뛴 요약 이유 표시 (#466, CHANGELOG 앱 0.8.0 개선); [앱] 상세 화면 요약 자동 갱신 (#444, CHANGELOG 앱 0.8.0 개선); [앱] 요약 끝난 콘텐츠 홈·아카이브 카드 반영 (#460, CHANGELOG 앱 0.8.0 개선); [앱] 앱 안 사진 저장 대기 시간 30초 (#459, CHANGELOG 앱 0.8.0 개선)
- 관련 PR·작업 링크: [상세 요약 자동 갱신 #447](https://github.com/clip-back/clipback/pull/447)(#444), [사진 저장 30초 #468](https://github.com/clip-back/clipback/pull/468)(#459), [목록 카드 반영 #470](https://github.com/clip-back/clipback/pull/470)(#460), [월 AI 요약 한도 #481](https://github.com/clip-back/clipback/pull/481)(#462, 앱 부분 #466), [로딩 스켈레톤 #482](https://github.com/clip-back/clipback/pull/482)(#469: #471·#472·#473), [AI 전송 동의 화면 #488](https://github.com/clip-back/clipback/pull/488)(#474: #477·#478·#479), [서버 공지 #487](https://github.com/clip-back/clipback/pull/487)(#486), [Gradle 체크섬·옛 알림 시트 정리 #432](https://github.com/clip-back/clipback/pull/432)(#428·#429, 사용자에게 보이는 변화 없음이라 변경 이력 항목 없음)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.7.0(16)·Android 0.7.0(12)](app-v0.7.0-ios-b16-android-b12.md)
- 후보 준비 상태·미확인 사유: iOS 0.8.0(17) 아카이브·IPA와 Android 0.8.0(13) AAB 빌드 완료(2026-11-26). 두 산출물 모두 업로드 대상 후보이며 업로드 금지로 지정한 산출물은 없음. 사용자 승인(2026-11-26 "모두 진행 (추천)"·"TestFlight 공지 문장만 고치고 승인 (추천)", 조율 전달) 뒤 후보 태그 생성·push, iOS 17은 App Store Connect에 업로드(2026-11-26 22:49 KST, Upload succeeded), Android 13은 Play 내부 테스트(internal) 트랙에 초안으로 업로드(2026-11-26 22:51 KST). App Store Connect 처리 완료·TestFlight '테스트할 내용' 입력·테스터 제공, Play 내부 테스트 출시(출시 노트 입력)·Alpha 승급은 사용자 단계로 미확인. 실기기 확인·심사·정식 공개 미실행

사용자 결정(2026-11-26, 조율 전달): iOS 17·Android 13, 소스 main `e4c2cb4`, 포함 변경은 CHANGELOG `미배포`의 [앱] 항목 전부. 서버 항목은 [backend-2026-11-26-1](backend-2026-11-26-1.md)로 옮겼습니다. 스토어 최대 업로드 번호는 사용자 답 "최대 빌드 번호는 16, 12야"(2026-11-26)를 App Store Connect 16·Play 12로 받음(기존 태그 `app-ios-v0.7.0-b16`·`app-android-v0.7.0-b12`와 맞음). 확인 시각은 날짜만 전달돼 식별자 표의 시각은 기록 시점입니다.
사용자 버전은 처음 0.7.1로 지시됐으나, 포함 변경에 `추가` 3개(#486, #477, #479)가 있어 [버전 결정](../release-process.md#버전-결정)의 0.x.y 규칙(기능 추가는 가운데 숫자)과 어긋나 배포 세션이 멈추고 물었고, 사용자 답 "0.8.0으로 (추천)"(2026-11-26, 조율 전달)으로 0.8.0이 됐습니다. 같은 기록 커밋에서 현재 안내 문서의 0.7.1 언급(`docs/release-process.md` AI 전송 동의 스위치 확인 절 두 곳, `docs/railway-deployment.md` `AI_CONSENT_REQUIRED` 줄)을 0.8.0으로 고쳤고, 작업 기록(`docs/history/`)의 "0.7.1"은 이 버전을 가리키며 고치지 않았습니다. 포함 변경은 `추가` 3개, `개선` 8개입니다.

`app-ios-v0.7.0-b16`(`d39c62b`)..`e4c2cb4`의 `frontend/` 변경은 위 PR 여덟뿐입니다. 그 밖의 커밋은 서버([backend-2026-11-26-1](backend-2026-11-26-1.md)), CI(`b4e1cd8` #427), 문서(`c62ac1e` #425, `643ffaf` #485)입니다.

팀 피드백 시트(“[허투루] 앱 테스트 피드백”)에서 이 빌드에 든 줄(2026-11-26 22:40 KST 무렵 조회, H열 이슈 기준): B열 49 → #469(#471–#473), B열 129 → #428(변경 이력 항목 없음), B열 137 → #444, B열 144 → #460, B열 145 → #459, B열 158 → #474(#477·#478·#479), B열 167 → #486. 일곱 줄 모두 I열 "0.8.0"·J열 "구현 완료". #466(#462 앱 부분)은 시트 줄 없음. #429는 시트 줄 없음. 시트는 고치지 않았습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-26T22:33:45+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-26T22:33:45+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인(조율 전달, 2026-11-26 사용자 답 "최대 빌드 번호는 16, 12야") / 2026-11-26T22:33:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 16 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 versionCode https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인(조율 전달, 2026-11-26 사용자 답 "최대 빌드 번호는 16, 12야") / 2026-11-26T22:33:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 12 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.8.0 | 0.8.0 |
| 실제 빌드 번호 | 17 | 13 |
| 빌드 소스 SHA | e4c2cb4e75bcbedc210de24accffb6597d52d33d | e4c2cb4e75bcbedc210de24accffb6597d52d33d |
| 후보 태그·실제 생성 여부 | app-ios-v0.8.0-b17 (2026-11-26 생성·푸시, annotated) | app-android-v0.8.0-b13 (2026-11-26 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 업로드·실기기 확인 전 | 미결정 — 업로드·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.8.0-ios-b17/Runner.xcarchive`(생성 2026-11-26 22:37 KST), IPA `frontend/build/release-candidates/app-v0.8.0-ios-b17/ipa/허투루.ipa` 42,457,512바이트, SHA-256 `c5294aadbe59466965b9369d186a5ad3ee41d51f54cbf2dc931d45156a6e992e` — 본앱 `com.huturu.app` 0.8.0(17), 공유 확장 `com.huturu.app.ShareExtension` 0.8.0(17). 업로드 대상 후보(업로드 금지 아님) | Release AAB 성공. `frontend/build/release-candidates/app-v0.8.0-android-b13/app-release.aab`, 74,901,630바이트, SHA-256 `020dfc56c6ca728b064e6bde260dbe349f0bbfd3472812c5c8b016f97abae072`. `com.huturu.app` versionName 0.8.0·versionCode 13 확인. 업로드 대상 후보(업로드 금지 아님) |
| 업로드·처리 상태 | 후보 아카이브 `app-v0.8.0-ios-b17/Runner.xcarchive`를 `xcodebuild -exportArchive`(destination upload)로 App Store Connect에 업로드 성공(2026-11-26 22:49 KST). 업로드 직후 상태 "Uploaded package is processing". App Store Connect 처리 완료 여부 미확인(이 세션에 조회 도구 없음) | Play Developer API로 후보 AAB(`app-v0.8.0-android-b13/app-release.aab`)를 업로드(2026-11-26 22:51 KST, `UPLOAD result=UPLOADED`), versionCode 13. Play 처리 결과 미확인 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미확인 — TestFlight '테스트할 내용' 입력·테스터 그룹 제공은 사용자 단계 | 내부 테스트(internal) 트랙에 초안(draft) 릴리스 "0.8.0 (13)". `check.py` 트랙 조회(22:51 KST): `internal: 0.8.0 (13)[draft]; 0.7.0 (12)[completed]`, `alpha: 0.7.0 (12)[completed]`. 내부 테스트 출시(출시 노트 입력)·Alpha 승급은 사용자가 Play Console에서 함, 미확인 |
| 심사 상태 | 미실행 — 심사 제출하지 않음 | 미확인 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. 같은 시기 서버 변경은 [backend-2026-11-26-1](backend-2026-11-26-1.md) 사후 기록 |
| 서버 소스 SHA·산출물 식별자 | 운영 중 e4c2cb4e75bcbedc210de24accffb6597d52d33d / Railway deployment `clipback` `b62d2f2b-fee9-4edb-8a8e-3031956de725`(SUCCESS, 2026-11-26 20:30 KST 생성). 앱 빌드 소스와 같은 커밋 |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 앱은 불필요. 앱이 기대는 서버 마이그레이션 `202611220024`–`202611250027`은 운영 배포에 포함됨(실행 로그는 미확인, [backend-2026-11-26-1](backend-2026-11-26-1.md)) |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 이 앱은 새 서버 동작에 의존함: #486 공지는 `GET /api/v1/notices`(#487), #477·#479 AI 전송 동의는 동의 기록 API(#483), #466 한도 안내는 요약 건너뜀 사유(#481). 세 서버 변경 모두 운영 반영이 앱 후보보다 앞섬(배포 목록 확인). [AI 전송 동의 스위치 확인](../release-process.md#ai-전송-동의-스위치-확인): 지금 M1(`AI_CONSENT_REQUIRED=false`, 조율 전달), 0.8.0을 iOS·Android 양쪽에서 받을 수 있게 된 날 M4(true)로 재배포 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 서버 새 필드는 추가뿐이라 0.7.0 이하 앱은 무시함. 0.7.0 이하 앱에는 동의 화면이 없어 스위치가 꺼진 동안 미결정 계정은 AI 처리됨(M4 전 전환 기간). 이 산출물과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱, 새 revision 없음) |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-26 22:35 KST 무렵): `e4c2cb4` 네 서비스 SUCCESS. ready 200은 조율 전달 |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.7.0(16)·Android 0.7.0(12) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버는 AI 전송 동의 이전으로 되돌리지 않음(backend-2026-11-26-1 참조) |

## 테스터 안내

앱 후보는 [테스터 안내 양식](TESTER-NOTES.md)으로 쓴 초안과 사용자가 승인한 최종 문구를 남깁니다. 서버 단독 기록은 두 칸 모두 `해당 없음`입니다.

사용자 승인 문구입니다(2026-11-26 "TestFlight 공지 문장만 고치고 승인 (추천)", 조율 전달). 오픈채팅방 공지와 스토어 짧은 안내는 배포 세션 초안 그대로이고, TestFlight 안내는 공지 문장 하나만 '인터넷에 연결되지 않으면 마지막으로 받은 공지를 보여 줘요'에서 '서버를 못 읽으면 앱에 들어 있는 공지를 보여 줘요'로 고쳤습니다. 원본은 CHANGELOG `## 앱 0.8.0` 절(추가 3, 개선 8)입니다. 공지 날짜는 실제로 공지하는 날로 바꿉니다.

- 오픈채팅방 공지: 아래 승인 문구(초안 그대로). 0.7.0 실제 게시 공지(2026-11-21) 길이에 맞춰 줄였고, 업데이트 방법은 그 게시 문구처럼 한 줄로 썼습니다. 개선 8개 중 넷을 비슷한 것끼리 묶었고, 저장 대기 공유 완료 문구(#478)는 길이 때문에 뺐습니다. 시트 줄이 있는 제보 항목(49, 137, 144, 145)이 있어 "제보 감사합니다"를 둡니다. 실제 게시 여부는 미확인.

```text
[허투루 0.8.0 업데이트 안내] 2026-11-26

🆕 새로 생긴 것
- AI 전송 동의 화면이 생겼어요(처음 들어올 때 한 번, 마이 → 계정 관리에서 언제든 변경).
- '공지사항'에서 최신 공지를 바로 볼 수 있어요.

🔧 고친 것
- 목록·홈을 불러올 때와 저장하는 동안 회색 카드 모양으로 진행 중임을 보여 줘요.
- 요약이 끝나면 상세 화면과 홈·아카이브 카드가 저절로 바뀌어요.
- 사진 저장이 오래 걸리면 저장됐는데도 실패로 뜨던 문제를 고쳤어요.
- 이번 달 AI 요약을 다 쓰면 상세 화면에 그 이유와 다시 요약되는 때를 알려 줘요.
제보 감사합니다 🙏

📲 Play 스토어에서 허투루 → 업데이트 (안 보이면 몇 시간 뒤에 다시)
💬 불편한 점이나 좋았던 점은 이 방에 편하게 남겨 주세요!
```

- 스토어 짧은 안내(Play 출시 노트): 아래 승인 문구(초안 그대로). Play 출시 노트 입력은 사용자가 하며(업로드 도구는 출시 노트를 넣지 않음) 입력 여부는 미확인.

```text
0.8.0 업데이트
- AI 전송 동의 화면이 생겼어요. 마이 → 계정 관리에서 언제든 바꿀 수 있어요
- 불러오는 중·저장하는 중 화면이 회색 카드 모양으로 바뀌었어요
- 요약이 끝나면 상세·목록 카드가 저절로 바뀌고, 사진 저장이 실패로 잘못 뜨던 문제를 고쳤어요
```

- TestFlight 안내: 아래 승인 최종 문구(공지 문장 하나 수정). `check_testflight_text.py --section "TestFlight 안내"` 결과는 진행 기록에 적습니다. TestFlight '테스트할 내용' 입력은 사용자가 하며 입력 여부는 미확인.

```text
허투루 0.8.0 업데이트

[새로 생긴 것]
- AI 전송 동의 화면이 생겼어요. 아직 정하지 않았다면 앱에 들어올 때 보이고, 보내는 정보와 받는 업체를 확인한 뒤 동의하거나 동의하지 않을 수 있어요. '자세히 보기'에서 업체별 안내를 읽을 수 있어요.
- 마이 → 계정 관리에 'AI 전송 동의' 줄이 생겼어요. 지금 상태를 보고, 누르면 언제든 동의하거나 철회할 수 있어요.
- '공지사항'에서 최신 공지를 볼 수 있어요. 서버를 못 읽으면 앱에 들어 있는 공지를 보여 줘요.

[아이폰에서 달라진 것]
- 저장을 기다리던 공유를 앱에서 다시 저장하면 '저장 완료!'만 짧게 보여 줘요.

[고친 것]
- 아카이브·즐겨찾기·검색 목록과 홈 최근 저장 목록을 불러올 때 스피너 대신 카드 모양의 회색 막대가 보여요.
- 링크나 사진을 저장하는 동안 회색 막대 위로 밝은 띠가 지나가요. '동작 줄이기'를 켜면 멈춰요.
- 링크를 저장한 뒤 상세 화면을 열어 두면 요약이 끝나는 대로 요약과 카테고리가 저절로 바뀌어요.
- 요약이 끝난 콘텐츠가 홈·아카이브 목록 카드에도 바로 반영돼요.
- 앱 안에서 사진을 저장할 때 시간이 오래 걸리면 저장됐는데도 실패로 뜨던 문제를 고쳤어요.
- 이번 달 AI 요약을 모두 쓰면 상세 화면 요약 자리에 그 이유와 다시 요약되는 때를 알려 줘요.

불편한 점이나 좋았던 점은 TestFlight 피드백으로 편하게 보내 주세요!
```

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 앱 소스의 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS) | 아카이브 본앱·공유 확장 `Info.plist`, `codesign --verify --deep --strict` | 통과 | 0.8.0(17)·공유 확장 0.8.0(17), 서명 검증 통과. profile·entitlements·privacy manifest는 이번에 다시 보지 않음. `git diff d39c62b e4c2cb4 -- frontend/ios`는 공유 확장 문구 코드(#478)·공유 UI 테스트·README 세 파일뿐이라 Info.plist·entitlements·서명 설정 변경 없음 |
| 산출물 정적 검사(Android AAB) | 빌드 뒤 단독 `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문 | 통과 | `com.huturu.app`·0.8.0(13)·minSdk 24·targetSdk 36. `jar verified.` 업로드 인증서 SHA-256 `B0:76:98:8A…87:E5:9A:D0`, 빌드 12 AAB의 인증서와 같음. `.so` 16KB 정렬·bundletool 검사는 미실행 |
| 원격 CI | `e4c2cb4`과 트리가 같은 PR #487 head `6bd63ef`의 App Validation·Backend Validation (pull_request), `e4c2cb4`의 Backend Validation (push) | 모두 success | [App Validation run 45799795917](https://github.com/clip-back/clipback/actions/runs/45799795917), [Backend Validation run 45799795899](https://github.com/clip-back/clipback/actions/runs/45799795899), [Backend Validation push run 45811192206](https://github.com/clip-back/clipback/actions/runs/45811192206). main push의 App Validation은 #426 뒤로 돌지 않음. `git diff 6bd63ef e4c2cb4` 빈 결과. job별 skip 여부는 보지 않음. 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 업로드·테스터 제공 전 |
| 운영 서버 | Railway production 배포 목록 (2026-11-26 22:35 KST 무렵) | `e4c2cb4` SUCCESS | 이 앱 후보와 운영 API의 연동(공지 내려받기, 동의 저장·철회) 미실행 |
| 실기기 | 미실행 | 미실행 | 업로드 전. 작업 기록에 남은 실기기 확인 대기 항목(#474 동의·철회·재동의, 미결정 계정 저장)은 "0.8.0 후보·스위치 적용일"(작업 기록에는 0.7.1로 적힘)에 확인 대상 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-26 22:2x | 버전·번호 확인 | 지시된 0.7.1·iOS 17·Android 13을 [버전 결정](../release-process.md#버전-결정)·[후보 식별](../release-process.md#후보-식별과-소스-고정)과 대조: 포함 변경에 `추가` 3개가 있어 0.x.y 규칙상 MINOR(0.8.0)라 멈추고 조율에 물음. 빌드 번호는 로컬·origin 앱 태그 최대 iOS 16·Android 12, 기존 후보 기록과 겹치지 않음. origin/main = HEAD = `e4c2cb4` | 사용자 답 "0.8.0으로 (추천)"(조율 전달)로 0.8.0. 작업 브랜치 이름을 `chore/app-release-0.8.0-ios-b17-android-b13`로 바꿈 |
| 2026-11-26 22:33 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 16, Play 12)로 iOS 0.8.0(17)·Android 0.8.0(13) 예약. 소스 main `e4c2cb4` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-26 22:35–22:38 | iOS 아카이브·IPA 내보내기 | 빌드 차례 확인(비어 있음) 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter pub get --enforce-lockfile` 뒤 `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.8.0 --build-number=17`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `e4c2cb4`, 변경은 CHANGELOG·문서뿐 | 약 2분 36초 성공, 0.8.0(17) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치, 아카이브 `diff -r` 같음). 업로드 미실행 |
| 2026-11-26 22:39 | 디스크 정리 | Android 빌드 전 빌드 차례 확인이 디스크 부족(9.6GiB < 기준 10GiB)으로 멈춤. 사용자 결정 "배포 것 + 끝난 작업 DerivedData (추천)"(조율 전달): 배포 세션은 이 워크트리의 `frontend/build/ios`(본체 복사·해시 일치 확인 뒤)와 이 워크트리의 Xcode DerivedData만 지움. 끝난 작업의 DerivedData는 조율이 지움 | 남은 공간 12GiB, 빌드 차례 확인 통과 |
| 2026-11-26 22:40–22:42 | Android AAB | 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.8.0 --build-number=13`, 운영 API·공개 SDK 설정 지정. 빌드 뒤 단독 `:app:validateReleaseSigning` 통과 | `bundleRelease` 113초 성공, 0.8.0(13) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 정지. 빌드 뒤 남은 공간 8.3GiB(기준 아래). 업로드 미실행 |
| 2026-11-26 22:45 | 테스터 안내 승인 | 사용자 결정 "TestFlight 공지 문장만 고치고 승인 (추천)"(조율 전달): TestFlight 안내의 공지 문장만 고치고 세 안내를 승인 문구로 기록 | `check_testflight_text.py --section "TestFlight 안내"` 종료 코드 0(문제 글자 없음) |
| 2026-11-26 22:46 | 태그 생성·푸시 | 사용자 승인 "모두 진행 (추천)"(조율 전달: 태그 2개 push, iOS TestFlight·Android Play internal 업로드, 기록 PR). 만들기 전 로컬·origin에 같은 태그 없음, `e4c2cb4`이 origin/main에 있음을 확인. annotated 태그 `app-ios-v0.8.0-b17`·`app-android-v0.8.0-b13`을 `e4c2cb4e75bcbedc210de24accffb6597d52d33d`에 만들어 origin에 푸시 | origin `ls-remote`로 두 태그가 `e4c2cb4`을 가리킴을 확인 |
| 2026-11-26 22:47–22:49 | iOS 업로드 | 같은 승인. 빌드 차례 확인이 디스크 기준(남은 8.4GiB < 10GiB)으로 막혀 조율에 물었고, 새 빌드가 아닌 두 업로드에 한해 진행하도록 답을 받음(남은 공간 2GiB 아래면 멈춤). 올리기 전 보존 아카이브의 본앱·공유 확장 모두 0.8.0(17)임을 확인. 새로 빌드하지 않고 보존 아카이브를 `xcodebuild -exportArchive -allowProvisioningUpdates`로 업로드. 내보내기 설정은 IPA 내보내기 설정에서 destination만 upload로, 빌드 번호 자동 변경(`manageAppVersionAndBuildNumber`)은 끔. Xcode에 로그인된 계정 사용. 심사 제출은 하지 않음 | 약 2분 18초, `Upload succeeded`(22:49:38 KST)·`EXPORT SUCCEEDED`, 한 번 시도. 로그에 Xcode에 등록된 다른 계정 하나의 자격 증명 로드 실패 경고(0.7.0 때와 같음), 업로드에 영향 없음. 남은 공간 업로드 전 9.4GiB·후 9.4GiB. App Store Connect 처리·TestFlight 제공은 미확인 |
| 2026-11-26 22:50–22:51 | Android 업로드 | 같은 승인. `~/.heoturu-agents/play/upload.py`(`.venv-play`)로 보존 AAB `app-v0.8.0-android-b13/app-release.aab`를 먼저 dry-run(Play 최대 versionCode 12, 13은 새 번호) 뒤 `--release-name "0.8.0 (13)" --confirm-upload`. 트랙은 도구 기본값 internal, 상태는 기본값 draft. 출시 노트는 도구가 지원하지 않아 넣지 않음(사용자가 Play Console에서 승인 문구 입력) | `UPLOAD result=UPLOADED`, edit 커밋. `check.py` 트랙 조회(22:51 KST): `internal: 0.8.0 (13)[draft]; 0.7.0 (12)[completed]`, `alpha: 0.7.0 (12)[completed]`. 남은 공간 9.4GiB. 테스터 제공은 안 됨 — Play Console에서 출시해야 함 |
