# A03 진행과 A04 SDK 취소

- 최초 기록일: 2026-10-19
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-d8a1d1dd9f8d6593"></a>

최근 `43b1ee9` 기준 **A03 일반 로그인 진행·A04 실제 SDK 취소**의1배율 표현을 맞췄습니다. 집중 실제 테스트103/전체1617·분석0, 양 플랫폼 각10동작/전체true·프레임워크 오류0, 새 비교4쌍·영상2개를 확인했습니다. 실제 OAuth·운영 서버·실기기 검증과 구분합니다.

<a id="b-d76a1a3db770838c"></a>

### A03·A04 프리뷰와 실제 검증 — 2026-10-19

<a id="b-30b5900dfec62830"></a>

일반 소셜 인증 대기와 SDK 취소만 새 화면을 사용합니다. 인증 진행의 기존 busy 잠금, 오류 A05·계정 연결/전환·보안/세션 복구, B01 확인 유지와 게스트 진입은 보존합니다. 새 확대 맞춤·인증 API·AppRoute·최소 대기는 추가하지 않습니다.

<a id="b-96c997178a047ff2"></a>

```bash
flutter run --no-pub -t test/support/login_status_preview.dart --dart-define=LOGIN_STATUS_PHASE=after
```

<a id="b-cb06770301c6957c"></a>

- `/scene?kind=progress|cancelled`: 실제 A02/B01·제어 가능한 메모리 SDK로 각 상태를 구성합니다. BEFORE 전용 빌드는 `LOGIN_STATUS_PHASE=before`이며 당시 제품의 A02 스피너/취소 후 A02를 촬영했습니다.
- `/run`: 같은 SDK 요청의 취소·진행 중 헤더/OS 잠금·중복 방지·방법 선택·동일 방문 확인 유지·헤더/OS 복귀·기존 게스트 온보딩을 검사합니다. `/status`와 임시 `report.json`에 실제 RenderParagraph/경계/도형/에셋 판정을 남깁니다.
- 기기: iPhone16/iOS18.6과 Android13/API33 제스처. 각10동작·최종 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0. 비교4쌍을 직접 검토하고 영상2개는 원본 PTS·전체 디코딩을 확인했습니다. 영상의 두 장면은 별도 대역 루트이며, 전체 동작 검사는 별도로 실행했습니다.
- 실제 테스트103/전체1617 통과·skip0·분석0·번들128건, 원본 에셋5건 바이트 일치와 실제 Bold 등록을 확인했습니다. 114개의 준비 단계 포함 로그 이벤트와 실제103테스트를 구분합니다. 메모리 대역·공유 격리는 실제 공급자나 운영 기능의 성공을 뜻하지 않습니다.
- 기기·포워딩·임시 포트·ADB 정리를 확인했습니다. 상세 원문 시트의 기존 SVG 문제와 기존 보류 정책은 별도입니다.

<a id="b-b5b4ca0dd948f2db"></a>

[비교4쌍](/private/tmp/clipback-auth-status-alignment-20261019/comparison-document.html) · [실제 검사](/private/tmp/clipback-auth-status-alignment-20261019/verification-summary.json) · [iOS 영상](/private/tmp/clipback-auth-status-alignment-20261019/ios/after/interaction.mp4) · [Android 영상](/private/tmp/clipback-auth-status-alignment-20261019/android-gesture/after/interaction.mp4)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-7a49207e481e478d"></a>

### 2026-10-19 — A03 로그인 진행·A04 SDK 취소

<a id="b-cba9c21b2b1f78ba"></a>

- `43b1ee9` 기준 Page 1 >261007의 원본 A03/A04를 적용했다. 새 진행 상태는 공유 사전 보안 성공 뒤 일반 인증의 세션 발급 전까지만 표시한다. 취소는 실제 SDK `null`에 한정하고, SDK/HTTP 오류 A05·연결/전환·발급 후 복구와 기존 인증/세션 정책을 유지한다.
- 요청/계정 세대 소유권으로 현재 취소만 소비한다. 진행 중 busy와 헤더/OS 잠금, 같은 방문 B01 확인·게스트/방법 선택과 오래된 콜백 차단을 유지했다. 기존 A02/B01 테스트·프리뷰는 실제 A04 복귀로 갱신했으며 검사를 우회하지 않았다.
- 새 BEFORE16목표 중2통과/14실패를 재현했다. AFTER 집중 실제103·전체1617 통과/skip0·분석0을 확인했다. 앞선 단계의 오래된 A02/B01 예상3건은 새 전환을 검사하도록 교정하고 전체를 다시 통과시켰다. 첫 촬영 도구의 첫 프레임 전 조회 실패는 제품 수정 없이 교정하고 양 플랫폼 BEFORE를 재동결했다.
- iPhone16/iOS18.6·Android13/API33 제스처에서 새 BEFORE4/AFTER4·3열4쌍과 각10동작/전체true·프레임워크 오류0, 영상2개와 실제 PTS/전체 디코딩을 확인했다. 영상은 상태별 새 메모리 루트이며 전체10동작은 녹화 전 별도 검사했다. 원본5건/번들128건·실제 Bold와 소유 기기/포트/ADB 정리를 확인했다.
- 실제 OAuth·운영 서버·실기기/원격 CI는 미검증이며, 후기 Android 런타임 로그는 정리 뒤여서 확보하지 못했다. 전역 비동기 오류0이나 인증 전체 완료로 보고하지 않는다. 상세 원문 시트 SVG 등 기존 보류 기록도 유지한다.

<a id="b-7e9c2eaaba2242b2"></a>

[3열 비교4쌍](/private/tmp/clipback-auth-status-alignment-20261019/comparison-document.html) · [실제 결과](/private/tmp/clipback-auth-status-alignment-20261019/verification-summary.json) · [iOS 영상](/private/tmp/clipback-auth-status-alignment-20261019/ios/after/interaction.mp4) · [Android 영상](/private/tmp/clipback-auth-status-alignment-20261019/android-gesture/after/interaction.mp4)

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-9cda3e44563d9bd0"></a>

- A03·A04 작업 기준: `43b1ee9`. 일반 소셜 인증의 실제 대기와 SDK 취소에 원본1배율 표현을 적용했다. 기존 busy 잠금·SDK/HTTP 오류 A05·계정 연결/세션 보안을 유지한다. 집중103/전체1617·분석0, iOS/Android 각10동작·전체true·프레임워크 오류0·새4쌍/영상2개·번들128건을 확인했다. 아래 독립 기록은 실제 OAuth/운영 서버/실기기 검증과 구분한다.

<a id="b-7026a83bda919036"></a>

### A03·A04 일반 로그인 진행·취소 1배율 적용 — 2026-10-19

<a id="b-2ef8149bcc4cef61"></a>

- 기준 제품: `43b1ee9`, Page 1 >261007·A03 `111:5870`/A04 `111:5885`. 구현 컨텍스트와375×812 원본은 **2026-10-19 17:14:28~17:14:35 KST**에 새로 확인했다. 기존 로컬 일러스트2종·세 점·뒤로가기 원본5건 대조가 바이트 단위로 일치한다.
- A03은 공유 보안 사전 처리를 통과한 **일반 소셜 인증 요청~세션 발급 전**에만 표시한다. 실제 SDK/API 대기를 표시하며 최소 시간·timeout·자동 재시도·새 인증 API는 없다. 기존 busy 잠금을 유지해 진행 중 ‘처음으로’와 OS 뒤로가기로 인증을 중단하지 않는다.
- 실제 SDK의 `null` 취소만 A04로 표시한다. 현재 요청/계정 세대 소유권이 맞는 취소에서만 처음으로·OS 뒤로·방법 선택·게스트를 처리한다. 같은 로그인 방문의 B01 확인과 기존 게스트 진입을 보존하고 오래된 콜백을 차단한다. HTTP/SDK 오류는 A05, 연결/전환 취소·보안/세션/발급 후 복구는 기존 흐름이다. 새 AppRoute·공개 화면 생성자/콜백·API/모델은 변경하지 않았다.
- 화면은 원본 Pretendard/실제 Bold·64px 헤더·원본 크롭·정적 세 점을 사용한다. 안전 영역은 한 번만 적용한다. A03 그룹은 안전 중앙−27px, A04 본문/하단 버튼은 분리하고 자연 높이·스크롤을 사용한다. 전역 스타일과 A02/연결 화면의 외형은 유지한다.
- BEFORE 재현: 새 목표16건 중2통과·14실패. 이후 실제 폰트·iOS/Android 테마×폭320/375×1배율,812/520px 높이, 대기·취소/오류·소유권/보안 경계와 이전 콜백을 검사했다. **집중 실제 테스트103건·전체1617건 통과/skip0, `flutter analyze --no-pub` 지적0건.** 기존 A02/B01 테스트·프리뷰는 실제 A04 방법 선택을 거치도록 갱신했으며 중복/세션/확인 유지 검사를 생략하지 않았다.
- 네이티브: **iPhone16/iOS18.6**, **Android13/API33/제스처2**에서 실제 루트·메모리 API/SDK/세션과 최초 엔진부터 공유 격리로 새 BEFORE4/AFTER4를 촬영했다. 각10동작·`stylePassed/layoutPassed/assetPassed/behaviorPassed/passed:true`·프레임워크 오류0이다. 실제 OS 창/안전 여백과 Figma 프레임 차이는 원본 그대로 표시한다. Android는 두 촬영 모두 일시적 `-gpu host`를 사용했고 탐색 설정은 변경하지 않았다.
- 4개의3열 비교를 직접 검토했다. 원본을 보정하지 않았으며 비교 표시에만 DPR을 적용하고 Figma의 원래 논리 크기를 유지했다. A03 첫 정적 보고서의 전체 스타일 플래그는 양 상태의 커버리지가 쌓이기 전 false이며, 해당 `sceneJudgments.progress`는 모두 true다. 완료 판정은 최종 전체 보고서로 확인한다.
- 영상은 iOS **7.041667초/147프레임**, Android **8.551544초/74프레임**이다. 별도 대역 루트의 진행·취소 두 장면이며 같은 요청의 취소를 포함한 전체10동작 검사는 녹화 전에 수행했다. 루트 재구성의 중간 프레임은 제품 라우트가 아니다. 원본 PTS·전체 디코딩·녹화 종료를 확인했고 원본을 재인코딩하지 않았다. 처음 null muxer의 DTS 양자화 경고는 source timebase 유지 검사로 구분했다.
- 소스/앱 번들128건·폰트 실제 Bold 등록을 확인하고 기기·포트8767/8768·ADB를 정리했다. 추가 Android 런타임 로그 읽기는 기기 정리 후여서 확보하지 못했으며 전체 앱의 비동기 네이티브 오류0으로 확대 해석하지 않는다. 이전 상세 원문 시트의 별도 SVG 진단은 유지한다. 실제 OAuth·운영 서버·실기기·원격 CI는 이번에 검증하지 않았다.
- 완료는 **승인된 일반 로그인 진행·SDK 취소의1배율 표현과 기존 이동 연결**이다. 기존 보류 목록과 인증 전체 기능 경계는 유지한다.

<a id="b-01e2561fac7cf109"></a>

[3열 비교4쌍](/private/tmp/clipback-auth-status-alignment-20261019/comparison-document.html) · [실제 검사](/private/tmp/clipback-auth-status-alignment-20261019/verification-summary.json) · [원본/비교](/private/tmp/clipback-auth-status-alignment-20261019/comparison-manifest.json) · [iOS 영상](/private/tmp/clipback-auth-status-alignment-20261019/ios/after/interaction.mp4) · [Android 영상](/private/tmp/clipback-auth-status-alignment-20261019/android-gesture/after/interaction.mp4)
