# 상세 하단 페이지 이동

- 최초 기록일: 2026-10-19
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-c2d3a09a33af76cb"></a>

### 상세 페이지 이동의1배율 Figma 맞춤 (2026-10-19)

<a id="b-0ba5f910156f9a6a"></a>

- F02/F04 하단 탭 앞16px·전문/사진 원본 펼침8px과 원본 이전28/다음32px을 적용했다.56px 터치 영역·실제 불러온 개수·경계/비동기 이동 잠금·공통 하단 바/OS 안전 영역은 유지한다. RoundIconButton의 새 선택적 설정은 상세에서만 사용하고 기본값은 기존과 같다.
- 검사: `flutter test --no-pub test/detail_alignment_test.dart test/scaled_navigation_layout_test.dart test/feed_pagination_test.dart`, 전체 `flutter test --no-pub --concurrency=2`, `flutter analyze --no-pub`. 집중113/전체1601·분석0이며 기존 확대 자동 검사를 유지했다.
- 전용 실행은 기존 `flutter run --no-pub -t test/support/detail_preview.dart --dart-define=DETAIL_PREVIEW_PHASE=after`와8767의 `/scene?kind=basic|expanded|empty&scroll=0`, `/run`을 사용한다. 실제 위젯·메모리 콘텐츠/콜백만 사용하며 API 원문/미디어·운영 서버 검증과 구분한다.
- [새 비교8쌍·영상2개](/private/tmp/clipback-detail-footer-alignment-20261019/comparison-document.html)·[실측/검사](/private/tmp/clipback-detail-footer-alignment-20261019/verification-summary.json). iPhone16/iOS18.6·Android13/API33 제스처에서 전후 같은 조건으로 새 촬영했다. 동시 실행 Android OS 대기창과 사진 펼침 검사 도구 교정은 별도 시도로 보존했다.
- 이후 확인된 디자인은 사용자 지시에 따라 반복 승인 없이 진행한다. Figma에 없는 표현·미확정 계약은 임의로 추가하지 않고 전체 작업 종료 시 별도 정리한다. 기존 콘텐츠/저장 정책·1배율 우선·검증/화면 증거·푸시/PR 별도 원칙은 유지한다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-bd9fe45512a0f42b"></a>

### 2026-10-19 상세 하단 페이지 이동1배율 맞춤

<a id="b-695c8801ce51c02f"></a>

- `8e58c4b` 기준 F02/F03/F04의 간격0→기본16/펼침8px·화살표28/32px·카운트 여백을 맞췄다. 실제 이동/비활성·불러온 개수·공통 탭/OS 여백과 데이터 계약은 유지한다.
- 수정 전12실패/4통과·새 양 플랫폼 원본8장, 수정 후 집중113/전체1601·분석0을 확인했다. 최종 양 플랫폼의 실제 위젯/메모리 동작·최종 명세의 기록/프레임워크 오류0·새 비교8쌍·영상2개를 검증했다. 전체 제품 검사는 그대로이며 사진 펼침 판정 도구만 보완해 최종 기기 실행으로 다시 확인했다. 기존 원문 시트의 비동기 SVG 오류는 분리 진단했으며 앱 전체 런타임 오류0을 뜻하지 않는다.
- [비교/영상](/private/tmp/clipback-detail-footer-alignment-20261019/comparison-document.html)·[검사/실측](/private/tmp/clipback-detail-footer-alignment-20261019/verification-summary.json)·[도구 보완](/private/tmp/clipback-detail-footer-alignment-20261019/photo-probe-amendment.json). Android System UI 대기창·집중 검사 경로 오류·도구 수정 전 iOS 시도는 최종 성공과 구분한다. 운영 서버/OAuth/실기기/CI 완료가 아니다.
- 사용자 새 지시로 확인된 화면은 추가 승인 질문 없이 계속 구현한다. 없는 디자인/미정 계약은 별도 기록하며 전체 작업 종료 후 정리한다. 기존 콘텐츠 보존·사진 전체 보기·OS 안전 영역·1배율 우선과 푸시/PR 별도 원칙을 유지한다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-702af839d29c085c"></a>

### 콘텐츠 상세 하단 페이지 이동의1배율 맞춤 — 2026-10-19

<a id="b-a764a93dfebcd9ec"></a>

- 기준은 `8e58c4b`·Page 1 >261007의 F02 `111:3842`·F03 `111:3771`·F04 `111:3909`다. 현재 컨텍스트3개와 정확한 F02/F04375×890·F03375×1440 원본을 확보했다. F03 컨텍스트의267×1024 축소본과 별도 원본을 구분하며 다른 파일의 이미지를 사용하지 않았다. 새 기본/연관 없음 하단 간격16px·전문/사진 원본 펼침8px, 정확한 원본 화살표28/32px·터치56px·카운트 좌우16px을 적용했다. 이전/다음의 실제 이동/비활성·불러온 개수 의미·상세 본문·원본 데이터·공통 탭·OS 안전 영역은 유지한다.
- `RoundIconButton`에 기본값이 기존과 같은 선택적 iconSize/backgroundOpacity를 추가하고 상세에서만 원본 크기/투명도를 선택한다. 전역 기본 외형·다른 화면은 바꾸지 않는다. 하단 간격은 실제 펼침 상태에서 계산하며 새 절대 좌표·추가 API/타이머/인증 동작을 추가하지 않는다.
- 제품 수정 전 실제 Pretendard·iOS/Android×폭320/375×1배율 검사에서12목표 실패/4통과를 재현하고 새 양 플랫폼 BEFORE8장을 확보했다. AFTER 집중113·전체1601통과/건너뜀0·분석0이다. 최종 기기는 ios 28기록·android-gesture 33기록·스타일/레이아웃/동작/전체true·프레임워크 오류0이며 기본/전문/연관 없음6쌍과 동일 절대 스크롤 전문2쌍, AFTER 영상2개를 제공한다.
- [비교8쌍·영상2개](/private/tmp/clipback-detail-footer-alignment-20261019/comparison-document.html)·[실측/검증 명세](/private/tmp/clipback-detail-footer-alignment-20261019/verification-summary.json)·[재현/전체 검사](/private/tmp/clipback-detail-footer-alignment-20261019/tests/summary.json)·[수정 전 게이트](/private/tmp/clipback-detail-footer-alignment-20261019/before-gate.json). 새 정적 촬영은 전후 같은 기종/데이터/1배율/키보드0·스크롤0 또는 BEFORE에서 정한 같은1728px대 offset을 사용했다. 예제 콘텐츠·Figma의 전체 프레임 길이·실제 OS 여백 차이는 보정하지 않는다. 원본 문단/미디어와 실제 서버 기능 검증을 뜻하지 않는다.
- 첫 Android 동시 실행의 System UI 응답 대기3회는 실패 시도로 분리했다. 같은 APK·데이터를 iOS 종료 뒤 Android 단독으로 실행하고 검증용 네이티브 준비20초를 둔 BEFORE는 OS 대기창 없이 성공했다. 제품에 대기 시간을 추가하지 않았다. 최초 집중 명령의 존재하지 않는 테스트 경로는 별도 로그로 보존하고 실제 feed_pagination_test.dart를 포함해113건을 다시 통과시켰다.
- 첫 iOS AFTER의 사진 펼침2기록은 실제 간격8px·오류0이나 검사 도구가 텍스트 문단만으로 펼침을 판단해 실패했다. 기존 사진/텍스트 공통 `_expanded` 판정으로 도구만 고쳐 재빌드·양 플랫폼 재실행했다([도구 보완](/private/tmp/clipback-detail-footer-alignment-20261019/photo-probe-amendment.json)). 이 수정은 제품·촬영 데이터·측정값을 바꾸지 않았고 전체1601 테스트가 실행하는 제품 소스도 동일하다. 수정된 도구는 최종 분석과 실제 기기 전체 시나리오로 재검증했다. 경로 오류로 중단한 중복 빌드는 성공 검증으로 사용하지 않는다.
- 실제 DetailScreen·고정 메모리 데이터와 콜백·포인터 입력의 로컬 검증이며 운영 서버·실제 OAuth·실기기·CI와 구분한다. 기존 확대 자동 검사는 유지하고 새 확대/3버튼 촬영은 추가하지 않았다. 완료는 상세 하단의 이번 원본 범위이며 상세 전체 기능 완료를 뜻하지 않는다. 화면 증거·빌드·AGENTS.md는 Git에 넣지 않고 소유 기기/포워딩/ADB/검증 경로를 정리한다. 푸시·PR은 하지 않는다.

<a id="b-42c97c20e04e4319"></a>

- 원문 보기 시트의 기존 instagram.svg는 초기4033b4a부터 잘못 저장된 파일이며 실제 SVG 로더에서 XML 예외가 발생한다([분리 진단](/private/tmp/clipback-detail-footer-alignment-20261019/known-legacy-runtime-errors.json)). 새 화살표6원본은 참조 ID 차이를 제외한 도형/색/치수가 같고 정상 로드된다. 이 기존 비동기 오류를 프레임워크 오류0이나 하단 범위 통과로 숨기지 않으며 앱 전체 런타임 오류0으로 보고하지 않는다. 정확한 원문 시트/원본 로고의 현재 Figma 대응이 없어 임의 아이콘 교체는 하지 않았다.

<a id="b-23631599379c041a"></a>

- Android 전체 동작은 같은 프로세스에서 녹화 없이 먼저 완료하고,180초 OS 녹화 제한 안에서 실제 하단 상태 전환/스크롤을 별도로 촬영했다. 전체 검사를 생략하거나 잘린 영상을 성공으로 사용하지 않았다. 해상도540×1110/2Mbps는 영상 인코딩에만 적용하며 원본 스크린샷/실제 창은 그대로다. 네이티브 창 상태를 먼저 확인해 UI 트리 덤프의 불필요한 idle 의존을 없애고, 모든 최종 원본도 직접 확인했다. 재생성 가능한 Git 제외 빌드 캐시만 정리했고 최종 APK/Runner/커널 SHA는 동일하다.
