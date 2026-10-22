# 상단 안전 영역과 헤더

- 최초 기록일: 2026-10-12
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-64938884f7b7471c"></a>

일반 화면의 헤더 높이는 `shared/theme/layout.dart`의 `appHeaderHeight`(64 논리 픽셀)를
사용합니다. 시스템 상태바·노치 높이는 이 64px에 포함하지 않습니다. 각 `Scaffold.body`에서
상단 `SafeArea`를 한 번 적용하며, `PhoneFrame`이나 헤더 안에서 중복 적용하지 않습니다.
공통 하단 내비게이션 높이는 위 공통 바의 OS 안전 영역 기준을 따릅니다. 저장 버튼은 별도 저장 창 정책의 `32 + max(viewInsets.bottom, viewPadding.bottom)`을 적용하며 검색 화면의 기존 하단 SafeArea는 유지합니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-6a7c26fb8b13a831"></a>

### 2026-10-12 — 상단 안전 영역·헤더 여백 통일

<a id="b-1cb022bef9600748"></a>

- 브랜치: `fix/frontend-top-safe-area`, 기준 `9690a9e`(`main`).
- 일반 화면의 헤더는 시스템 상단 inset을 제외한 64 논리 픽셀(`appHeaderHeight`)로 맞췄다.
  각 화면 본문에서 SafeArea를 한 번 적용하며, 기존 북마크·검색의 보호를 중복하지 않는다.
  저장 창은 별도 route에서 보호하고, 모든 하단 시트 진입에 `useSafeArea: true`를 적용했다.
- 홈은 헤더도 함께 스크롤하는 기존 동작과 본문 간격을 유지한다. 랜덤은 단일 Stack에서 헤더·본문·
  카드 승격 좌표를 함께 보정하고 ClipRect로 드래그 중 상태바 영역 침범을 막는다.
  인증 화면 배치, 하단 내비게이션·저장 CTA, 버튼 hitSize, 화면 최대 너비는 유지한다.
  API·ViewModel·Repository·네이티브 설정·의존성·AGENTS.md는 변경하지 않았다.
- 변경 전 기준: `flutter analyze --no-pub` 무오류, `flutter test --no-pub` **497 passed**.
  새 상단 inset 재현 테스트 5개가 수정 전 실패하는 것을 확인했다. 이후 테스트를 보강했다.
- 신규 회귀 25개: 5가지 inset(0/20/44/59/62) × 2개 화면 크기의 헤더·버튼 탭 10개,
  홈 스크롤·랜덤 드래그의 상태바 픽셀 보호 1개, 인증 배치·동작 9개,
  저장 실패 후 링크·선택 사진 및 검색어 보존 2개, 높은 시트·원본 이미지 요청 공유 3개.
  기존 테스트의 assertion·시나리오를 축소하거나 skip하지 않았다.
- 최종 로컬 검사: `flutter analyze --no-pub` 무오류, `flutter test --no-pub` **522 passed**,
  `flutter build web --no-pub`, `flutter build ios --debug --no-codesign --no-pub` 성공.
  웹 빌드는 CupertinoIcons 폰트 탐색 경고를 출력했으며 실패는 없었다.
- 기기 검증 도구: `test/support/safe_area_preview.dart`는 실제 앱에 메모리 세션·인증 및 HTTP 대역을
  연결하고, `safe_area_device_check.dart`는 화면 콜백·합성 포인터로 기기 좌표·PNG·결과 JSON을 남긴다.
  운영 서버로 전달하는 fallback이 없으며 실제 저장 세션·공급자 SDK를 사용하지 않는다.
- 실기기: 연결된 **iPhone 15 / iOS 26.7.1**, 393×852 논리 픽셀·DPR 3·상단 inset 59px에서
  테스트 전용 앱 설치·실행 및 자동 화면 순회를 완료했다. 11개 헤더가 모두 top 59px·높이 64px였다.
  홈 헤더 동반 스크롤, 원본 이미지 디코딩·시트(top 157.4px), 키보드 308px가 열린 카테고리 시트
  (top 116px), 랜덤 카드 합성 드래그(offset 변경·다음 카드 전환), 전체 화면 저장 창을 확인했다.
  `report.json`은 passed=true·frameworkErrors=[]이며 PNG 17장을 확보해 화면 배치도 확인했다.
- 실기기 증거는 로컬 `/private/tmp/clipback-safe-area-iphone15-final/`에 보존한다. PNG는 Flutter
  렌더링 캡처로 OS 상태바·키보드 자체의 픽셀을 포함하지 않으며, 기기가 제공한 실제 inset을 함께
  측정했다. 실제 기기에 대역 데이터를 표시하고 화면 콜백·프로그램 포인터를 사용한 검증이다.
  사람의 수동 사용·실제 OAuth·운영 서버 쓰기·외부 AI·원격 CI·출시 검증은 수행하지 않았다.
- 첫 무선 실행은 연결이 끊겼으나 재시도 후 통과했다. 재시도의 Flutter 터미널에 앱 로그가 전달되지
  않아 기기 앱 임시 폴더의 결과 JSON과 PNG를 직접 읽어 검증했다. 기기 디버깅 심볼 준비 지연은
  앱 코드 오류와 구분했다. 검증 앱을 종료했으며 실제 사용자 세션 저장소에는 쓰지 않았다.
- 검증 후 `lib/main.dart`로 서명된 Debug 앱을 다시 빌드·설치해 iPhone의 다음 실행에 테스트 fixture가
  남지 않도록 복원했다. 복원 앱은 실행하지 않았으며 기존 앱 데이터·실제 세션을 삭제하지 않았다.
- 최종 `git diff --check` 통과. 커밋 범위는 상단 안전 영역 수정, 회귀 테스트, 기기 검증 도구와
  관련 문서이며, 로컬 기기 캡처·빌드 생성물·AGENTS.md는 포함하지 않는다.
