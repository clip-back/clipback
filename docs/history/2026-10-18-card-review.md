# 카드 다시보기 표현

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-047c13b965058cfc"></a>

앞선 `8b26385` 기준 작업은 **G02/G11 카드 다시보기의 승인된1배율 상단·카드 스택·진행/소진 표현 맞춤**입니다. 집중17/관련298/전체1282·분석0·별 경계 외부4건을 통과했고 양 플랫폼 각direct14/root7·오류0·새4쌍/영상2개·정리를 확인했습니다. 실제 데이터·기존 무작위 선정/상세 복귀0·콜백/OS 안전 영역을 유지하며 초기 빈 디자인·세션/진행 복원·모션 전체·새 확대는 후속입니다.

<a id="b-5191dd83e902e066"></a>

### 카드 다시보기 화면의 1배율 맞춤 — 2026-10-18 작업

<a id="b-7ce32211e2e275ba"></a>

`8b26385` 기준으로 Page 1 > `261007`의 [G02 카드 다시보기](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-5047) (`111:5047`)·[G11 카드 소진](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-5275) (`111:5275`)에서 **승인된 1배율 상단·카드 스택·진행 표시·소진 표현**을 적용했다. 집중/관련/전체 자동 검사·분석과 양 플랫폼 실행/새 비교를 검증했다. 무작위 세션·복귀 정책이나 카드 다시보기 전체 모션/기능의 완료를 뜻하지 않는다. J01/J02와 이전 OS 안전 영역 작업의 조회·검사·비교는 당시 독립 기록으로 보존한다.

<a id="b-71c210e8a3cf6400"></a>

- **글자·배치:** 전용 Pretendard를 명시하고 나가기16/Medium·안내16/SemiBold·카테고리24/SemiBold·배지12/Medium은 AUTO, 제목22/SemiBold는 행간1.4·최대 두 줄, 본문16/Regular는 행간1.6으로 맞춘다. 실제 카테고리명/색·제목·원문을 표시하고 원문이 비면 기존 요약을 사용한다. 본문은 실제 남은 높이에 들어가는 완전한 줄까지만 말줄임하며 예제 문구를 제품 데이터로 넣지 않는다.
- **카드 스택:** 실제 OS 상·하 안전 영역과 클리핑을 유지한다. 헤더64px·안내/카테고리56px·진행 영역60px·앞 카드 앞16px이며 앞 카드 top은 안전 영역 아래196px이다. 본문 폭375px에서 앞343×496px·뒤311×449px·셋째279×403px, 뒤 카드 top은 안전 영역 아래251/305px이다. 실제 폭은 본문 폭−32/−64/−96px으로 계산하고 기존 PhoneFrame 최대375px을 유지한다. 정지 기울기를 제거하고 흰 배경/R8·앞 blur8/뒤 blur16을 적용한다. 내부24px·헤더/제목/본문 사이8px을 유지한다.
- **배지·탭 영역:** 배지의 기존 Flexible/Spacer 반폭 예산과 자연 배경 폭/긴 이름 말줄임은 `FractionallySizedBox(widthFactor:0.5)`로 유지하고 별은 실제 카드 오른쪽/상단24px에 고정한다. 북마크28×28px·상태 안내/잠금과 콜백은 유지한다. 나가기 hit는 기존 헤더 높이64px·폭48px으로 보존해 최소48×44px을 충족하고 글자는 중앙/우16px에 둔다. 회전된 BEFORE의 변환 후 AABB 경계를 논리 패딩으로 해석하지 않는다.
- **진행·정확한 에셋:** 진행 영역60px 안의 논리 진행16px·트랙8px에 활성 원본20×20px을 논리 슬롯16×16px으로 중앙 배치하고 비활성8×8px을 사용한다. 새 원본SVG는 진행2개뿐이며 폴더/별은 기존 에셋과 도형·칠·선·치수를 대조해 재사용했다([원본 대조](/private/tmp/clipback-card-review-alignment-20261018/figma/asset-audit.json)). 폴더 원본/로컬의 루트 표시 힌트 차이는 byte 일치와 구분한다. 색상필터·전체 화면 구현 에셋은 사용하지 않는다. [원본/번들/실효 에셋 판정](/private/tmp/clipback-card-review-alignment-20261018/static-assets-verification.json)에서 신규2/재사용2 역할의 원본·로컬·양 iOS/APK 번들 bytes, 정적4상태의 실제 폴더/진행 경로·무필터·슬롯과 별 hit28×28px/상·우24px을 확인했다. 별 경로는 보호된 기존 상수/렌더 분기와 실제 미선택 상태로 확인하며 동결 스냅샷에 별도 별 loader 필드가 없다는 한계를 기록했다.
- **소진·기존 계약:** 사용자 확정대로 마지막 카드가 사라지면 진행 표시도 숨기고 기존 나가기·안내·카테고리는 유지한다. 새 완료 문구/버튼은 추가하지 않는다. 처음부터0개인 입력은 기존 별도 EmptyStatePanel/나가기이며 G11로 대체하지 않는다. 드래그 거리72px/속도650·퇴장 이동620px·240ms 전환/mounted 확인, 공개 화면/카드 생성자·콜백과 기존 저장/상세 동작을 보존했다. 공유 CategoryBadge 전체와 progress 기본 표현은 유지하며 CardPagerProgress에만 기본값false의 선택적 reviewStyle을 추가했다. 서버 API·Repository·모델·누적 통계·네이티브 설정은 변경하지 않았다.

<a id="b-2e5c948d8c88f135"></a>

### 원본 확인과 자동 검사

<a id="b-3791aac8b63229ef"></a>

- 계획 G02/G11 조회 **2026-10-18 02:49:48~02:49:53 KST**, 진행 원본 조회 **02:55:49~02:55:54 KST**와 별도로 구현 직전 **03:02:51~03:02:57 KST / 2026-10-17 18:02:51~18:02:57 UTC**에 G02/G11의 컨텍스트·375×812px 원본을 각각 한 번, `get_design_context` 총2회로 함께 확보했다. 재조회 때 별도 스크린샷/메타데이터/fallback 호출은 추가하지 않았다([조회 기록](/private/tmp/clipback-card-review-alignment-20261018/figma/native-reference-manifest.json)).
- **G11 원본 PNG와 컨텍스트 모두 나가기·안내·카테고리를 유지하고 카드/진행은 없는 상태다.** 원본을 직접 재대조해 이를 확인했으며 AFTER 소진 화면의 구성도 일치한다. 초기 원본 판독을 정정했고 Figma 재호출·원본 보정·대체 디자인·제품 변경은 추가하지 않았다([원본/픽셀 재대조](/private/tmp/clipback-card-review-alignment-20261018/g11-reference-pixel-audit.json)). 처음부터0개·새 완료 문구/버튼의 별도 디자인은 미확정으로 남긴다.
- 제품 수정 전 [집중17건](/private/tmp/clipback-card-review-alignment-20261018/tests/focused-before-summary.json)에서 **3통과/목표 차이14실패**를 재현했다. 글꼴/카드·진행 기하·본문 줄 수·긴 카테고리·소진 진행 표시의 차이와 정상 촬영 가능 여부를 구분했다. 별도 외부 [실제 루트 probe](/private/tmp/clipback-card-review-alignment-20261018/tests/baseline-root-probe.json)는2테스트를 통과했고 iOS BEFORE smoke의 direct14/root7동작은 프레임워크 오류0·behaviorPassed:true이나 기존 외형 목표 실패로 전체passed:false였다([direct](/private/tmp/clipback-card-review-alignment-20261018/ios/before/smoke-flutter/direct-report.json)·[root](/private/tmp/clipback-card-review-alignment-20261018/ios/before/smoke-flutter/root-report.json)).
- 사전 수집 도구 오류 때의 초기4장은 성공 비교에서 제외하고 당시 시도를 따로 보존했다. 최초 오류 수집에 stderr가 없어 상세 원인을 확정할 수 없으며 root 부착 전 context 접근/null은 사후 조사 범위를 넘겨 단정하지 않는다. 도구 보완·재동결 뒤 기준 제품으로 두 플랫폼 BEFORE4장을 새로 확보했다. [BEFORE 게이트](/private/tmp/clipback-card-review-alignment-20261018/before-gate.json)의 원본/동일 조건/71개 검사 소스 SHA와 직접 시각 확인을 거친 뒤 **2026-10-18 03:26:29 KST**에 제품을 적용했다([적용 기록](/private/tmp/clipback-card-review-alignment-20261018/product-applied.json)).
- AFTER 집중 **17/17**, 관련 **298/298** 통과(실패/건너뜀0)다([집중](/private/tmp/clipback-card-review-alignment-20261018/tests/focused-after-summary.json)·[관련](/private/tmp/clipback-card-review-alignment-20261018/tests/related-after-summary.json)). 실제 Pretendard·iOS/Android 테마×폭320/375px×1배율에서 스타일/기하·짧은/긴 제목/본문/카테고리·원문 fallback·실제0/1/5개 입력·스냅백/넘김/콜백/소진/빈 상태와 공유 progress 기본값을 검사했다. 동결 소스 외부의 [별 경계4건](/private/tmp/clipback-card-review-alignment-20261018/tests/boundaries-after-summary.json)도 통과했고 실제28×28px/오른쪽24px/상단24px을 측정했다([실측](/private/tmp/clipback-card-review-alignment-20261018/tests/bookmark-boundaries.json)). 별도 probe는 전체 앱 검사 집계에 합산하지 않는다. 전체 `flutter test --no-pub` **1282/1282** 통과(실패/건너뜀0)·`flutter analyze --no-pub` **문제0/exit0**을 확인했다([전체](/private/tmp/clipback-card-review-alignment-20261018/tests/all-after-summary.json)·[분석](/private/tmp/clipback-card-review-alignment-20261018/tests/analyze-after-summary.json)).
- 첫 AFTER15통과/2실패와 중간 배지 row/기존 상단 안전 영역 회귀 실패를 수정한 뒤 위 최종 집중/관련 검사를 통과했다. 첫 실패의 원본 jsonl/summary 일부는 재실행으로 덮어써 보존하지 못했으며 [도구 출력 추출](/private/tmp/clipback-card-review-alignment-20261018/.attempts/after-expanded-badge/failure-extract.json)을 원본 로그로 표기하지 않는다. 후속 시도의 [집중](/private/tmp/clipback-card-review-alignment-20261018/.attempts/after-nested-badge-row/focused-after-summary.json)·[관련](/private/tmp/clipback-card-review-alignment-20261018/.attempts/after-nested-badge-row/related-after-summary.json) 원본과 당시 소스는 별도 보존했다. 테스트 기대치를 완화하지 않았고 [재동결71개 소스](/private/tmp/clipback-card-review-alignment-20261018/fixture-manifest.json)는 이후 변경하지 않았다. 기존 추적69개와 허용된 기존 제품2개 외 보호267파일 불변·공개 API/상태/콜백/공유 기본값을 확인했다([보호 감사](/private/tmp/clipback-card-review-alignment-20261018/preservation-audit.json)).

<a id="b-8307ff71c7bd44d4"></a>

### 양 플랫폼 실행·새 비교와 후속 경계

<a id="b-c329a80827133545"></a>

| 플랫폼 | 실제 논리창 / DPR | OS 상·하 여백 / 본문 viewport | 앞 카드 / 실제 시작점 | AFTER 동작 |
| --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852px /3.0 | 59/34px /759px | 343×496px /top255px | direct14·실제root7·7판정true/오류0 |
| Android13 / API33 제스처 | 392.7×783.3px /2.75 | 24/0px /759.273px | 343×496px /top220px | direct14·실제root7·7판정true/오류0 |

<a id="b-7eb11b183f444ac5"></a>

- [변경 전→후→Figma4쌍](/private/tmp/clipback-card-review-alignment-20261018/comparison-document.html)과 [동일 조건/원본 판정](/private/tmp/clipback-card-review-alignment-20261018/pair-verification.json)에서 첫 카드/실제5회 드래그 후 소진×두 플랫폼의 새 OS 원본8장을 비교했다. 기종·데이터5개·1배율·키보드 숨김·scroll0이 같고 조건 차이0·Figma 누락0·대체 디자인0이다. 실제 OS 창/안전 영역과 Figma375×812px, 기존 PhoneFrame 최대375px을 보정하지 않는다. G11 원본대로 소진 시 상단을 유지하며 카드/진행을 숨기고 OS 여백·예제 데이터 차이를 표시했다. 의도하지 않은 잘림/겹침·팝업·공유 배너0이며 긴 문구 말줄임/드래그 중 안전 영역 밖 클리핑은 오류와 구분한다.
- 개요: [iOS](/private/tmp/clipback-card-review-alignment-20261018/comparisons/ios-comparison-overview.png)·[Android](/private/tmp/clipback-card-review-alignment-20261018/comparisons/android-gesture-comparison-overview.png). AFTER 영상: [iOS](/private/tmp/clipback-card-review-alignment-20261018/ios/after/interaction.mp4)·[Android](/private/tmp/clipback-card-review-alignment-20261018/android-gesture/after/interaction.mp4). [영상 판정](/private/tmp/clipback-card-review-alignment-20261018/media-verification.json)은2원본의 시작/종료·중간 동작·전체 디코딩을 확인했고 편집0·디코딩 실패0이다. 실제 인코딩 길이는 iOS21.46초/Android50.285초이며 녹화 대기시간을 임의 합산하지 않았다.
- **고정 direct와 실제 root를 분리했다.** 정적 촬영은 실제 제품 위젯에 같은 순서5개를 직접 주입한다. direct14기록은 북마크/열기/나가기 콜백·스냅백·5회 넘김·소진·초기0개를 확인한다. 실제 ClipbackApp·메모리 HTTP 대역의 root7기록은 불러온 실제 카테고리 안 최대5개/중복 없는 선정·실제 대상ID 북마크 HTTP 503 오류 후 원복/같은ID 재시도·그때 앞 카드의 상세/복귀·같은 카테고리 나가기/재진입을 검사했다. iOS는 대상603→603, Android는604→604로 재시도했고 양쪽 최종7개 판정이 모두true·프레임워크 오류0이다([실측/시나리오](/private/tmp/clipback-card-review-alignment-20261018/native-validation-summary.json)). AFTER 정적 경계에서 앞/뒤/셋째343×496·311×449·279×403px, 진행 논리16px/영역60px·활성원본20px/비활성8px, 두 줄 제목 아래 본문13개 완전한 줄과 소진 시 카드/진행0을 확인했다. 고정 촬영을 실제 앱의 순서 보존 성공으로 보고하지 않는다.
- iOS 첫 AFTER launch는 준비 완료 전에120초 timeout으로 실패해 촬영/녹화를 시작하지 못했다. 원인은 미확정이며 제품 결함의 증거로 단정하지 않는다. 소유 기기를 정리한 뒤 선택적 stdout/stderr 리다이렉션을 제거한 plain launch로 **같은 최종 빌드/동일 제품·동결 소스**를 다시 실행해 성공했다. 실패 시도를 성공 비교로 사용하지 않으며 Android의 성공 증거는 유지했다([제외/재시도 기록](/private/tmp/clipback-card-review-alignment-20261018/.attempts/ios-after-launch-timeout/excluded-evidence-reason.json)·[환경 검증 기록](/private/tmp/clipback-card-review-alignment-20261018/environment-validation-record.json)).
- [환경 정리](/private/tmp/clipback-card-review-alignment-20261018/cleanup-verification.json)는 소유 앱/시뮬레이터/에뮬레이터·포워딩·ADB 종료와8767/8768 포트 닫힘을 확인했다. 탐색/키보드 설정 변경0·기기 wipe/앱 uninstall0·임시 비교 HTTP서버 없음이며 증거/빌드는 Git 밖에 둔다.
- **기존 한계:** build마다 불러온 목록의 사본을 shuffle 후 최대5개 택하므로 북마크 root 재빌드·상세 복귀 때 재추첨될 수 있고 매번 다른 순서를 보장하지 않는다. 상세 복귀는 review State를 새로 만들어 index0부터 시작한다. 드래그 자체는 root를 재빌드하거나 열람 이벤트를 기록하지 않으며 상세 이전/다음은 기존 전체 아카이브 피드 기준이다. 이 정책과 입력 목록 축소/교체 시 동기화 한계는 변경하지 않았다.
- 초기0개 별도 디자인·새 완료 문구/버튼·세션 고정/순서·진행 복원·입력 동기화·전환 중 새 잠금·G03 이후 모션 전체·실제 누적 열람 정의·새 확대 맞춤은 후속이다. 소진 시 진행 숨김은 이번 사용자 확정/적용 범위다. 기존 확대 구현/자동 검사는 유지하고 새 배율별 촬영은 추가하지 않았다.
- 최초 실행부터 기존 네이티브 공유 큐/실제 자격과 격리한 메모리 세션·소셜 인증 대역·합성 포인터를 사용했다. 기존 큐/자격의 조회·삭제·인증정보 출력은 하지 않는다. 로컬 대역 검증을 실제 OAuth·운영 서버·영속 저장·실기기·원격CI 증거로 확대하지 않는다.

<a id="b-0a00fdb0fb962807"></a>

카드 전용 프리뷰는 [card_review_alignment_preview.dart](../../frontend/test/support/card_review_alignment_preview.dart)입니다. `/scene?kind=stack&count=5`·`/scene?kind=complete&count=5`는 고정 순서의 실제 제품 위젯/5회 드래그로 정적 상태를 준비합니다. `/run`은 고정 direct 콜백·넘김·소진/초기0개를, `/root-run`은 별도 실제 루트 앱·메모리 API의 실제 대상ID 북마크/상세/나가기를 검사합니다. `/state`·`/status`는 실제 스타일·경계·에셋·오류를 읽습니다. 두 실행의 완료/판정은 분리하며 전체 통과에는 둘 다 필요합니다. 최초 실행부터 기존 native share와 격리하고 Android8768→8767 포워딩은 검증 뒤 정리합니다. BEFORE는 이번 기준 제품의 동결 빌드로만 생성합니다.

<a id="b-7c623ba4b65aa553"></a>

```bash
flutter build ios --debug --no-pub --simulator -t test/support/card_review_alignment_preview.dart --dart-define=CARD_REVIEW_ALIGNMENT_PHASE=after
flutter build apk --debug --no-pub -t test/support/card_review_alignment_preview.dart --dart-define=CARD_REVIEW_ALIGNMENT_PHASE=after
flutter test --no-pub test/card_review_alignment_test.dart
```
