# D04 링크 저장 처리 중

- 최초 기록일: 2026-10-19
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-4ef42405a49321b4"></a>

최근 `75b04b3` 기준 **D04 링크 저장 처리 중**의1배율 스켈레톤·비활성 닫기를 적용했습니다. 집중226/전체1625·분석0, 양 플랫폼 각11동작·전체true·프레임워크 오류0·새 비교2쌍/영상2개를 확인했습니다. 기존 입력/탭·저장 정책과 실제 서버 검증의 경계를 유지합니다.

<a id="b-360238b6f8ebba42"></a>

### D04 링크 처리 중 프리뷰 — 2026-10-19

<a id="b-6ad9386886e930a0"></a>

```bash
flutter run --no-pub -t test/support/link_pending_preview.dart --dart-define=LINK_PENDING_PHASE=after
```

<a id="b-65022a888b7e5a8b"></a>

- 실제 ClipbackApp·메모리 회원 세션/API·최초 실행부터 공유 격리를 사용합니다. `/scene`은 실제 하단 저장 진입·링크 입력/검증·POST 대기를 구성하고, `/complete`는 같은 요청을 완료합니다. `/run`은 입력/탭 변경·중복 차단·완료 탭·실패/재시도·종료 후 응답 등11동작을 검사합니다. `/status`와 임시 `report.json`에 실제 스타일/도형/경계를 기록합니다.
- 원본에 있는 입력과 일치하는 링크 대기에만 D04를 적용합니다. 기존 콜백의 저장 후 조회도 포함하며 별도 추출 단계/진행률 API를 추가한 것이 아닙니다. 다른 입력/탭·오류·사진과 기존 저장 시점/완료 정책은 유지합니다.
- iOS/Android 테마·320/375px·1배율·812/520px, 집중226/전체1625·분석0과 실제 iPhone16/iOS18.6·Android13/API33 제스처의 각11동작·전체true/프레임워크 오류0을 확인했습니다. 새 비교2쌍·영상2개/실제 PTS·전체 디코딩과 번들111건·소유 기기/포워딩/ADB 정리를 확인했습니다.
- 첫 Android 설치180초 초과는 실패 시도로 보관하고 동일 APK 재설치 후 검증했습니다. 실제 운영/OAuth/실기기/CI 성공으로 확장해 보고하지 않습니다.

<a id="b-b728872af37d7a21"></a>

[비교2쌍](/private/tmp/clipback-save-loading-alignment-20261019/comparison-document.html) · [검사 결과](/private/tmp/clipback-save-loading-alignment-20261019/verification-summary.json) · [iOS 영상](/private/tmp/clipback-save-loading-alignment-20261019/ios/after/interaction.mp4) · [Android 영상](/private/tmp/clipback-save-loading-alignment-20261019/android-gesture/after/interaction.mp4)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-20983d93aee6f682"></a>

### 2026-10-19 — D04 링크 저장 처리 중

<a id="b-c5ce7769fdec3399"></a>

- `75b04b3` 기준 `111:5006` 원본을 적용했다. 현재 입력이 제출한 링크와 일치하는 저장 콜백 대기만 스켈레톤·원본 문구·비활성 닫기로 표시한다. 콜백은 기존 저장 후 조회도 포함하며 새 API나 처리 단계 계약을 만들지 않았다. 입력/탭 변경·오류·사진·저장/완료/재시도·늦은 응답 정책은 보존했다.
- BEFORE 목표4실패 재현, AFTER 실제 폰트/양 테마×320/375×1배율×812/520px의 경계·도형·스크롤을 확인했다. 집중226/전체1625 통과·skip0·분석0이며 기존 확대/저장/공유 검사는 유지했다.
- iPhone16/iOS18.6·Android13/API33 제스처 각11동작/전체true·프레임워크 오류0, 새 BEFORE2/AFTER2·3열2쌍·영상2개/원본 PTS·전체 디코딩·번들111건과 기기/포트/ADB/탐색 설정 정리를 확인했다. Android 최초 설치180초 초과는 실패로 보관하고 동일 소스/APK·재설치6.224초/exit0 후 실행을 통과했다.
- 완료는 해당 D04 표현이며 실제 운영 서버·OAuth·실기기/CI와 저장 전체 디자인 완료를 뜻하지 않는다. 기존 보류 목록과 과거 검증 기록은 유지한다.

<a id="b-096a44893c058f6d"></a>

[비교2쌍](/private/tmp/clipback-save-loading-alignment-20261019/comparison-document.html) · [실제 결과](/private/tmp/clipback-save-loading-alignment-20261019/verification-summary.json) · [iOS 영상](/private/tmp/clipback-save-loading-alignment-20261019/ios/after/interaction.mp4) · [Android 영상](/private/tmp/clipback-save-loading-alignment-20261019/android-gesture/after/interaction.mp4)

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-9a8f2618fc73d43f"></a>

- 최근 D04 기준: `75b04b3`. 제출 링크와 현재 입력이 일치하는 저장 콜백 대기에 원본 스켈레톤·처리 문구·비활성 닫기를 적용했다. 입력/탭 변경과 오류는 기존 표현·저장 정책을 보존한다. 집중226/전체1625·분석0, 양 플랫폼 각11동작·전체true·프레임워크 오류0·새2쌍/영상2개·번들111건을 확인했다.

<a id="b-8c8728816a420b16"></a>

### D04 링크 저장 처리 중 1배율 적용 — 2026-10-19

<a id="b-4095d29862a6d9bb"></a>

- 제품 기준 `75b04b3`, Page 1 >261007·D04 `111:5006`. 컨텍스트/375×812 원본은 구현 준비 시 **2026-10-19 17:46:04~17:46:11 KST**에 확인했다. 새 정적 에셋·서버 API·데이터 모델·공개 생성자/콜백은 추가하거나 변경하지 않았다.
- 기존 링크 저장 콜백이 대기 중이고 현재 탭/정리한 URL이 실제 제출 입력과 같으며 기존 오류가 없을 때만 원본 스켈레톤과 문구·회색 비활성 ‘닫기’를 표시한다. 미리보기116px·8px 패딩·164×100px 이미지 자리·139/91px 막대,55px 카테고리/164×24px 막대를 적용한다. 글자는 기존 저장 전용 Pretendard 스타일과 AUTO 행간을 재사용한다.
- 기존 콜백 대기는 **서버 저장 후 후속 조회도 포함**한다. 새 OCR/추출 단계 API·진행률·최소 표시 시간·애니메이션은 없다. 탭/입력 변경·기존 오류 표시 중에는 이전 표현을 유지하며 제출 데이터·실제 저장 시점·완료 입력/탭·중복 차단·재시도·닫기/늦은 응답은 유지한다. 사진 선택/결과 표시 정책도 변경하지 않았다.
- 실제 루트·메모리 회원 세션/API에서 POST를 보류해 BEFORE를 새로 촬영했다. 신규 목표4건을 먼저 재현했고, AFTER 실제 폰트·iOS/Android 테마×320/375px×1배율·812/520px에서 스타일·도형·경계·최대 스크롤/본문 하단24px을 확인했다. **집중226·전체1625 통과/skip0·`flutter analyze --no-pub` 지적0**이다. 기존 확대·사진·저장/공유 회귀를 건너뛰지 않았다.
- iPhone16/iOS18.6·Android13/API33 제스처에서 각11동작·최종 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0, 새 BEFORE2/AFTER2·3열2쌍을 확인했다. 같은 기종/데이터/1배율/키보드 숨김/스크롤0이며 실제 OS 창·여백과 예제 URL 차이는 보정하지 않았다.
- 영상은 iOS **3.933333초/57프레임**, Android **4.6183초/30프레임**이다. 실제 같은 POST의 대기→성공 결과를 촬영했으며 전체11동작은 별도로 확인했다. 초기 장면의 A01/홈은 대역 root 재구성이다. 실제 PTS·원본 전체 디코딩·녹화 완료와 비교2쌍/주요 프레임을 직접 검토했다.
- Android 첫 AFTER는 **앱 설치가180초를 넘겨 실행 검증 전에 중단**됐다. 소스/최종 APK 무변경을 확인한 채 생성 캐시3곳만 정리하고 기존 설치 APK 해시를 확인한 뒤 재설치했다. 재설치는6.224초/exit0이며 최종 실행을 새로 통과했다. 시간 초과를 제품 성공으로 보고하지 않는다.
- 소스/앱 번들111건, 포트8767/8768·ADB·소유 기기 종료와 탐색2 무변경을 확인했다. 실제 OAuth·운영 서버·실기기/원격 CI 검증은 포함하지 않는다. 완료는 **D04의 해당 대기 표현**이며 저장 전체·추출 실패 복구와 기존 보류 항목은 유지한다.

<a id="b-b0851ae20859b060"></a>

[3열 비교2쌍](/private/tmp/clipback-save-loading-alignment-20261019/comparison-document.html) · [검사/한계](/private/tmp/clipback-save-loading-alignment-20261019/verification-summary.json) · [iOS 영상](/private/tmp/clipback-save-loading-alignment-20261019/ios/after/interaction.mp4) · [Android 영상](/private/tmp/clipback-save-loading-alignment-20261019/android-gesture/after/interaction.mp4)
