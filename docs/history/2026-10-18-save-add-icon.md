# 공통 저장 버튼 아이콘

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-502c15cad5a2dd69"></a>

직전 `d29f7db` 기준 작업은 **공통 하단 저장 버튼의1배율 더하기 원본 맞춤**입니다. NavAddButton의38.5px SVG만 전용 원본으로 바꾸며 기존72px 버튼·테두리·상단 돌출22px·색상·탭 동작·하단 안전 영역을 유지합니다. 일반 plus와 FloatingAddButton·네 탭 아이콘은 바꾸지 않습니다. **집중/관련117·전체1452·분석0, 양 플랫폼 각13기록의 전체true/오류0·새2쌍/영상2개·배치240/번들282·환경 정리**를 확인했습니다. Figma 재조회 실패/정확한 보관 원본 사용과 당시 검사·비교/영상은 아래 독립 기록을 따릅니다.

<a id="b-33bc65009db890d6"></a>

### 공통 하단 저장 버튼의 1배율 아이콘 맞춤 — 2026-10-18 작업

<a id="b-1e9891c613369d65"></a>

### 기준과 적용 경계

<a id="b-8911da95ee1f8c01"></a>

- 기준 제품은 `d29f7db`·`feature/figma-ui-alignment`이며 Page 1 >261007의 C01 하단 `111:3680`/`TAP_FAB` 더하기 원본을 사용한다. E01 하단 `111:4132`·I01 하단 `111:4093`·J01 하단 `111:4764`에서 확보한 원본도 같은 bytes다. 이전 네 탭 작업에서 제외했던 plus를 이번 독립 범위로 적용하며 당시 제외/검증 기록은 보존한다. 구현 직전 C01 `get_design_context`1회는 **2026-10-18 21:21:03 KST /12:21:03 UTC에 관측한 MCP HTTP transport 오류**로 실패했다. 원격 성공0회·별도 screenshot/metadata0회이며 시작 시각은 미확보·도구 응답의 소요 시간30초와 구분한다. 이 실패를 요금제/호출 한도 문제로 확정하지 않는다([조회 명세](/private/tmp/clipback-navigation-plus-alignment-20261018/figma/reference-manifest.json)).
- 승인된 fallback으로 같은 파일의 **2026-10-18 19:55:59~19:56:05 KST** 컨텍스트/정확한 하단 원본4개를 재사용한다. 더하기 SVG4개의 bytes와 SHA256 `22d4c9f1…3b759b594`는 동일하다([원본 대조](/private/tmp/clipback-navigation-plus-alignment-20261018/figma/asset-source-audit.json)). C01 전체 프레임은 같은 파일의16:05:27 KST 보관 원본이며 새 조회 성공이나 대체 디자인으로 보고하지 않는다.
- 정적 계산에서 기존 공용 plus는32px viewBox/선3px를38.5px 슬롯으로 확대해 약3.609375px 선이 된다. 새 원본은38.5×38.5px/선3px이며 원본 SVG의 bytes·비율·끝 모양을 보존한다. 이 계산을 새 기기 실측으로 보고하지 않는다.
- 제품 변경은 하단 전용 `nav-add-plus.svg`·`Assets.navAddPlus`와 `NavAddButton`의 참조 한 곳이다. 공용 `Assets.plus`/기존 SVG와 별도 `FloatingAddButton`은 유지하며 공유 `SvgIcon`·전역 테마·폰트·공개 생성자/콜백·API/모델을 바꾸지 않는다.
- 저장 버튼72×72px·흰 테두리4px·노란 배경·중앙 아이콘38.5px/기존 검정 tint·상단 돌출22px과 중심/하단 탭 영역을 유지한다. 네 탭의 상태별 SVG/원본 계층·라벨·바 높이 `64 + 기존 라벨 확대 증가분 + 실제 viewPadding.bottom`과 저장/닫기 정책을 유지한다.

<a id="b-1161d2560d27f081"></a>

### 실제 검사와 증거

<a id="b-2b8f7baea8a57c37"></a>

- 기준 제품의 [목표20건](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/before-target.log)은 **4통과/저장 아이콘 source 차이16실패**로 기존 plus 참조를 재현했다. 원본 미등록으로 컴파일/촬영이 막힌 실패와 구분한다. [준비 도구3개 분석](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/before-tools-analysis.log)은 문제0/5.7초다. 준비 단계의 [포맷](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/before-format.log)은 fixture1파일을 정리했으며 제품 수정 전 촬영 도구 동결과 구분한다.
- [기준 제품의 기존 확대·안전 영역97/97](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/before-regression.log)은17초/통과다. 관련 두 검사 파일을 이번 작업에서 다시 실행한 결과이며 이전 네 탭 커밋의 결과를 재사용하지 않는다.
- 실제 재귀 import4파일은 **2026-10-18 21:25:05 KST**에 [이번 작업 v1로 동결](/private/tmp/clipback-navigation-plus-alignment-20261018/preview-source-freeze.json)했다. native core 구현은 기존 v3 bytes를 그대로 유지하며 새 fixture의 addIcon 판정만 확장했다. 이번 동결 버전1과 이전 작업에서 검증한 core 구현 버전3을 구분하고 이전 촬영을 새 BEFORE로 재사용하지 않는다.
- 새 [iOS BEFORE](/private/tmp/clipback-navigation-plus-alignment-20261018/ios/before/report.json)·[Android BEFORE](/private/tmp/clipback-navigation-plus-alignment-20261018/android/before/report.json)는 각각13동작의 기존 스타일/레이아웃/동작true·프레임워크 오류0이며 더하기 원본 source 차이만 에셋false다. 홈 원본2장을 **iOS21:28:31~21:28:33 KST·Android21:28:49~21:28:50 KST**에 새로 확보했다. [동결 직전 포맷](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/before-format-final.log)은1파일/변경0/0.02초다.
- 제품 변경 전의 실제 소스·새 BEFORE2장과 동작을 검사한 **21:29:13 KST [게이트280/280](/private/tmp/clipback-navigation-plus-alignment-20261018/product-edit-gate.json)** 뒤 **21:29:55 KST**에 [제품3파일](/private/tmp/clipback-navigation-plus-alignment-20261018/applied-product-source.json)을 적용했다. [원본 SVG 대조](/private/tmp/clipback-navigation-plus-alignment-20261018/figma/asset-source-audit.json)의 registered=true·원본 bytes 동일과 공용 plus/다른 사용처 미변경을 확인한다.
- [AFTER 집중/관련117/117](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/after-target-related.log)·[실행 명세](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/after-target-related.json)는 실제13.61초/exit0이며 reporter의7초와 구분한다. [전체 정적 분석](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/flutter-analyze-final.log)·[명세](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/flutter-analyze-final.json)는 문제0/실제7.43초(analyzer5.6초)/exit0이다. [읽기 전용 포맷](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/dart-format-final.log)·[명세](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/dart-format-final.json)는3파일/변경0/실제0.61초(formatter0.04초)/exit0이며 검사 중 소스 변경은0이다.
- [수정 후 실제 빌드](/private/tmp/clipback-navigation-plus-alignment-20261018/after-build.json)는 Android19.16초·iOS66.19초로 모두exit0이며 이번 빌드 실패는0이다. [디스크 공간 예방 조치](/private/tmp/clipback-navigation-plus-alignment-20261018/disk-space-safeguard.json)는 완료한 Android의 재생성 가능한 Git 제외 merged native 중간8개(논리크기약1.374GB)만 정리했다. 최종 APK의 전후SHA·제품3/동결 도구4와 기존 원본/로그/SDK는 보존했다. 이전 커밋에서 발생한 빌드 실패나 미완료 검사를 이번에 발생한 것으로 재사용하지 않는다.
- 새 [전체 Flutter1452/1452](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/flutter-test-final.log)·[실행 명세](/private/tmp/clipback-navigation-plus-alignment-20261018/tests/flutter-test-final.json)는 **실제139.88초(reporter2분15초)/exit0·실패/skip0**으로 완료했다. `--concurrency=2`의 전체 실행이며 검사 중 제품3/fixture1의 SHA는 불변이다. 이전 네 탭 커밋과 같은 검사 수라도 이번에 새로 실행한 로그·시각/소스 해시를 사용한다.
- 최종 [iOS AFTER](/private/tmp/clipback-navigation-plus-alignment-20261018/ios/after/report.json)·[Android AFTER](/private/tmp/clipback-navigation-plus-alignment-20261018/android/after/report.json)는 각각13기록의 **스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0**이다. 실제 `addIconSvgs`의 원본 source·`#1A1A1A` tint·38.5×38.5px와 버튼 중앙 일치를 판정했다. 네 탭 순환·아카이브 drag/왕복·상세의 아카이브 선택/복귀·저장 진입/추가 저장 없는 닫기를 확인했으며 AFTER idle offset은 iOS569.716007px·Android362.594713px로 플랫폼별 왕복 전후 각각 동일하다.
- 새 AFTER 홈 원본은 **iOS21:36:11~21:36:13 KST·Android21:36:37~21:36:38 KST**에 촬영했다. [대표 홈의 전후 배치240/240](/private/tmp/clipback-navigation-plus-alignment-20261018/geometry-comparison.json)은 창/OS 여백·바/저장 버튼·네 탭 슬롯/라벨 경계와 글자 보존을 확인한다. 실제 iOS393×852px/DPR3/상하 안전59·34px/바375×98px, Android392.727×783.273px/DPR2.75/상하 안전24·0px/바375×64px이며 Figma 고정96px와 실제 OS 여백의 차이를 보정하지 않는다.
- [변경 전→후→Figma2쌍](/private/tmp/clipback-navigation-plus-alignment-20261018/comparison-document.html)·[명세](/private/tmp/clipback-navigation-plus-alignment-20261018/comparison-manifest.json)는 같은 데이터/1배율/IME0/scroll0의 새 홈 BEFORE2/AFTER2 원본과 정확한 보관 C01을 사용한다([iOS](/private/tmp/clipback-navigation-plus-alignment-20261018/comparisons/ios-home.png), [Android](/private/tmp/clipback-navigation-plus-alignment-20261018/comparisons/android-home.png)). [원본/3열 시각 검토](/private/tmp/clipback-navigation-plus-alignment-20261018/root-static-visual-review.json)는 OS 원본4장·Figma 하단 원본1장·3열2장을 실제 열어 plus 표현/경계와 의도하지 않은 겹침 없음을 확인했다. 임의 대체 디자인·원본 크롭/OS 여백 보정은 하지 않는다.
- [실제 iOS/APK 번들282/282](/private/tmp/clipback-navigation-plus-alignment-20261018/bundleverification.json)는 원본 SVG bytes·폰트·실제 런타임 source/tint/경계와 보호 소스를 확인한다. [최종 native 근거](/private/tmp/clipback-navigation-plus-alignment-20261018/native-evidence-summary.json)는 이번 BEFORE/AFTER와 현재 제품/도구가 일치하고 동결 import4개 drift0·도구 교정0·전체true임을 기록한다. Figma 최신 재조회 성공은false이며 정확한 보관 원본 사용과 실제 새 기기 결과를 구분한다.
- AFTER 원본 영상 [iOS12.696667초](/private/tmp/clipback-navigation-plus-alignment-20261018/ios/after/actions.mp4)·[Android15.967456초](/private/tmp/clipback-navigation-plus-alignment-20261018/android/after/actions.mp4)의 [전체 디코딩/녹화 검증](/private/tmp/clipback-navigation-plus-alignment-20261018/media-verification.json)은 모두exit0/true다. [표시용960px/30fps 재생본](/private/tmp/clipback-navigation-plus-alignment-20261018/chat-preview-manifest.json)은 원본을 보존한다([iOS](/private/tmp/clipback-navigation-plus-alignment-20261018/ios/after/actions-preview.mp4), [Android](/private/tmp/clipback-navigation-plus-alignment-20261018/android/after/actions-preview.mp4)).
- [시작/중간/끝·2초 간격 시각 검토](/private/tmp/clipback-navigation-plus-alignment-20261018/docs-agent-video-visual-review.json)는 실제 contact sheet4장을 열어 수행했다. iOS10초 샘플에는 저장 모달이 보이며, Android의 상세/저장 모달은 선택 샘플에 없어 실제13동작 판정과 구분한다. 양 영상 초기 `_fresh`의 독립 메모리 root 생성은 A01을 거치며 일반 탭 왕복의 스플래시 재표시로 보고하지 않는다. 모든 영상 프레임을 육안 확인했다고 보고하지 않는다.
- [환경 정리](/private/tmp/clipback-navigation-plus-alignment-20261018/cleanup-verification.json)는 실제passed=true다. 소유 앱·iPhone16/API33·포워딩·태스크 시작 ADB·driver 포트를 종료하고 기존 탐색 모드2를 유지했다. 사용자 데이터/설정 삭제·관련 없는 서비스 중단은 하지 않았다. 현재 소스·검사·원본/기기/미디어와 문서/변경 범위는 [최종 검증 집계](/private/tmp/clipback-navigation-plus-alignment-20261018/validation-summary.json)에서 함께 판정한다.
- 실제 루트 앱·메모리 회원 세션/API·최초 실행부터의 네이티브 공유 격리를 재사용한다. 기존 native core v3를 유지하고 새 fixture에서 저장 아이콘의 실제 source/tint/38.5px 경계를 검사한다. 홈 대표 화면의 정적 비교2쌍과 실제 네 탭·아카이브 스크롤/상세/저장 진입·추가 저장 없는 닫기 동작을 구분한다.
- 기기 조건은 iPhone16/iOS18.6·Android13/API33 제스처·1배율·키보드 숨김·scroll0이며 OS 원본을 자르거나 안전 여백을 보정하지 않는다. 기존 확대/안전 영역/키보드 자동 회귀를 유지하고 새 배율별·3버튼 촬영은 추가하지 않는다.
- 로컬 대역/시뮬레이터/에뮬레이터를 운영 서버·실제 OAuth·실기기·원격CI 성공으로 보고하지 않는다. 화면 증거·빌드 생성물·`AGENTS.md`는 Git 밖에 두며 소유 기기·포워딩/ADB·임시 서버를 정리하고 푸시/PR은 하지 않는다.

<a id="b-463b6c34c7779ed9"></a>

프리뷰 진입점은 기존 `test/support/navigation_alignment_preview.dart`와 `NAVIGATION_ALIGNMENT_PHASE=before|after`를 그대로 사용한다. `/scene?tab=home`의 대표 홈을 새로 촬영하고 `/run`의13개 실제 루트 동작을 검사하며 `/status`에서 실제 `addIconSvgs` source/tint/크기·경계를 확인한다. BEFORE는 실제 `d29f7db` 제품, AFTER는 수정 제품을 각각 빌드한다.

<a id="b-cb9c91fe2b0ed890"></a>

```bash
# frontend/ — 이번 plus 목표를 포함한 기존 검사와 전체/분석을 별도 실행한다.
flutter test --no-pub test/navigation_figma_test.dart test/scaled_navigation_layout_test.dart test/bottom_safe_area_test.dart
flutter test --no-pub --reporter expanded --concurrency=2
flutter analyze --no-pub
```

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-30f2702b60e64412"></a>

이번 `d29f7db` 기준 작업은 **공통 하단 저장 버튼의1배율 더하기 원본 맞춤**입니다. NavAddButton의38.5px SVG만 전용 원본으로 바꾸며 기존72px 버튼·테두리·상단 돌출22px·색상·탭 동작·하단 안전 영역을 유지합니다. 일반 plus와 FloatingAddButton·네 탭 아이콘은 바꾸지 않습니다. **집중/관련117·전체1452·분석0, 양 플랫폼 각13기록의 전체true/오류0·새2쌍/영상2개·배치240/번들282·환경 정리**를 확인했습니다. Figma 재조회 실패/정확한 보관 원본 사용과 새 검사·비교/영상은 아래 독립 기록을 따릅니다.
