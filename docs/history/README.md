# 작업·검증 이력

- [Weekly 카드 문구·이름 색 결정](2026-11-04-weekly-pick-wording.md)

- [운영 원본 접근·백업·격리 복원 통합 검증](2026-10-26-image-operator-readiness.md)

- [2026-10-26 실제 점검을 확인하는 격리 복원](2026-10-26-live-isolated-restore.md)
- [영속 점검 제어 구현](2026-10-26-image-maintenance.md)

현재 안내와 분리한 작업별 계획·구현·검증·실패·한계의 기록입니다.
이관 원본은 `c04a7556cb7cfea0dd273992e411e0ee6537c853` 커밋에서 확인할 수 있습니다. 원작업의 커밋·기준·실행 날짜는 각 원문을 따릅니다.
날짜가 불명확한 기록은 일자를 추정하지 않았으며, 같은 날짜의 다른 작업을 합치지 않았습니다.

## 기록과 확인 방법

- 상세 결과는 작업 파일에 한 번만 추가하고 현재 README·정책·진행 상태가 달라지면 해당 문서를 갱신해 연결합니다.
- 새 파일명은 `YYYY-MM-DD-topic.md`이며 최초 기록일을 사용합니다. 일자 미확인은 `undated-topic.md`로 구분합니다.
- 당시 명령은 원문에 적힌 작업 디렉터리·코드·환경 기준입니다. 과거 검증 수치·승인 예외를 현재 결과나 일반 지침으로 적용하지 않습니다.
- 이관 시 동일 작업의 정확히 같은 원문 블록만 공유했습니다. 유사하지만 다른 수치·문구·실패·재시도·한계는 출처별로 보존합니다.
- [원문 이관 대조표](migration-map.json)는 원본 파일·행 구간·앵커·SHA-256과 새 위치·중복 관계를 기록합니다.
- 기준 파일 전체는 저장소 루트에서 `git show c04a7556cb7cfea0dd273992e411e0ee6537c853:원본경로`로 확인합니다. 이 명령은 과거 원본 조회용이며 재실행 검증이 아닙니다.
- 증거 URL은 그대로 보존했습니다. 고유 로컬 경로 1120개 중 152개는 이관 확인 시 파일이 없었습니다.
  대조표의 `evidence`에서 원래 URL·확인 당시 존재 여부·참조 위치를 확인합니다. 파일의 존재는 검증 결과의 타당성을 증명하지 않습니다.
  누락 파일은 복구한 것으로 표시하지 않았고 미디어를 이동·생성·업로드하지 않았습니다.

## 작업 목차

| 최초 기록일 | 작업 | 영역 |
| --- | --- | --- |
| 2026-11-06 | [운영자 계정 삭제 명령 (#255)](2026-11-06-account-deletion-operator-command.md) | 백엔드 |
| 2026-11-06 | [탈퇴 때 Apple 토큰 철회·카카오 연결 끊기 (#254)](2026-11-06-account-deletion-provider-revocation.md) | 백엔드 |
| 2026-11-06 | [`DELETE /users/me`와 앱의 탈퇴 요청 (#253)](2026-11-06-account-deletion-request.md) | 서버·앱 |
| 2026-11-06 | [격리 복원 검증의 계정 탈퇴 판정 (#252)](2026-11-06-account-deletion-restore-probe.md) | 백엔드 |
| 2026-11-06 | [계정 탈퇴 장부 기록과 계정 재삭제 (#251)](2026-11-06-account-deletion-ledger.md) | 백엔드 |
| 2026-11-06 | [콘텐츠 삭제 전 확인 창 (#238)](2026-11-06-content-delete-confirm.md) | 앱 |
| 2026-11-05 | [마이 메뉴 Figma 목록·버전 팝업 제거 (#239)](2026-11-05-my-page-figma-list.md) | 앱 |
| 2026-11-05 | [사진 저장 응답 지연 뒤 수동 재시도 (#235)](2026-11-05-photo-save-retry.md) | 앱 |
| 2026-11-05 | [모바일 전체 폭 구현·검증·전후 화면 비교](2026-11-05-mobile-full-width.md) | 앱 |
| 2026-11-04 | [홈 흰 패널 하단 배경 연결 (#232)](2026-11-04-home-panel-bottom.md) | 앱 |
| 2026-11-03 | [목록 전체 개수·서버 정렬 최종 검증](2026-11-03-feed-count-final.md) | 서버·앱 |
| 2026-11-03 | [즐겨찾기 우선 서버 정렬](2026-11-03-feed-server-sort.md) | 서버·앱 |
| 2026-11-03 | [목록 전체 개수 표시](2026-11-03-feed-total-count.md) | 서버·앱 |
| 2026-11-03 | [HTTP 응답 보류 테스트 도우미](2026-11-03-http-response-hold-helper.md) | 앱 테스트 |
| 2026-11-03 | [Dart 전체 포맷 정리와 앱 CI 포맷 검사](2026-11-03-dart-format-check.md) | 앱·CI |
| 2026-11-03 | [자동 요약을 핵심 한 줄과 요점 목록으로 바꾸기](2026-11-03-summary-headline-points.md) | 백엔드 |
| 2026-11-03 | [홈 상단의 옛 "저장한 정보가 없어요." 영역 삭제와 직전 상단 유지](2026-11-03-home-hero-fallback.md) | 앱 |
| 2026-11-03 | [CHANGELOG·이력 목차의 동시 추가 충돌을 merge=union으로 자동 해결](2026-11-03-merge-union-changelog.md) | 문서 |
| 2026-11-03 | [홈 칩 전환 때 최근 콘텐츠 영역 높이 고정](2026-11-03-home-chip-switch-height.md) | 앱 |
| 2026-11-03 | [앱 pub get·analyze·test 원격 검사 워크플로 추가](2026-11-03-app-validation-ci.md) | CI |
| 2026-11-03 | [frontend 바로 아래의 쓰지 않는 디자인 SVG 7개 삭제](2026-11-03-remove-unused-design-svgs.md) | 앱 |
| 2026-11-03 | [Flutter 3.47.9 업그레이드](2026-11-03-flutter-3-47-upgrade.md) | 앱 |
| 2026-11-03 | [화면 문구의 "북마크"를 "즐겨찾기"로 통일](2026-11-03-bookmark-to-favorite-wording.md) | 앱 |
| 2026-11-03 | [홈에서 Figma에 없는 "최근 카테고리" 영역 제거](2026-11-03-home-remove-recent-categories.md) | 앱 |
| 2026-11-03 | [홈 미분류 칩의 빈 화면 문구에서 "콘텐츠" 중복 제거](2026-11-03-home-unclassified-empty-text.md) | 앱 |
| 2026-11-03 | [회원 탈퇴를 여러 번 누르면 알림이 이어서 뜨던 문제 수정](2026-11-03-withdraw-notice-repeat.md) | 앱 |
| 2026-11-02 | [복구 지점 계약 2차: 읽기 전용 점검 모듈, `storage_key` 규칙, 객체 오류 코드](2026-11-02-recovery-point-contract-2.md) | 백업·복원 |
| 2026-11-02 | [앱 아이콘·시작 화면 로고를 글자 기준 가운데로 맞춤](2026-11-02-app-icon-center.md) | 앱 |
| 2026-11-02 | [복구 지점 manifest 검증 기준 통일](2026-11-02-recovery-point-manifest-contract.md) | 백업·복원 |
| 2026-11-01 | [앱 아이콘을 허투루 아이콘으로 교체](2026-11-01-app-icon.md) | 앱 |
| 2026-11-01 | [완료 지점 목록의 manifest 키 판정 수정](2026-11-01-completed-point-pattern.md) | 백업·복원 |
| 2026-11-01 | [복구 지점 manifest 동작 고정과 module 이전](2026-11-01-recovery-point-manifest.md) | 백업·복원 |
| 2026-11-01 | [자동 요약 종류별 처리 모으기와 요약 결과 이름 정리](2026-11-01-summary-kind-refactor.md) | 백엔드 |
| 2026-11-01 | [백엔드 CI의 백업·복구 Docker 검사를 관련 변경과 야간 실행으로 한정](2026-11-01-backend-ci-paths.md) | CI |
| 2026-10-31 | [요약 작업과 메타데이터 요청의 예상 밖 오류 처리](2026-10-31-summary-error-handling.md) | 백엔드 |
| 2026-10-31 | [인스타그램 요약 백엔드 구현과 리뷰 수정](2026-10-31-instagram-summary-backend.md) | 백엔드 |
| 2026-10-31 | [저장 결과 처리 중 문구를 링크 정보로 통일](2026-10-31-link-pending-message.md) | UI |
| 2026-10-31 | [공유 저장 시트와 완료 토스트 구현·검증](2026-10-31-share-save-sheet.md) | 공유 |
| 2026-10-30 | [마이 앱 버전 표시 구현·검증](2026-10-30-app-version-display.md) | UI |
| 2026-10-28 | [Android 내부 테스트 배포 구현·검증](2026-10-28-android-internal-test-implementation.md) | 앱 내부 배포 |
| 2026-10-28 | [Android 내부 테스트 배포 구현 티켓 발행](2026-10-28-android-internal-test-tickets.md) | 티켓 |
| 2026-10-28 | [Android 내부 테스트 배포 명세 발행](2026-10-28-android-internal-test-spec.md) | 명세 |
| 2026-10-28 | [Android 배포 준비 설계 인터뷰](2026-10-28-android-release-design.md) | 설계 |
| 2026-10-28 | [Android 앱 식별자를 iOS와 통일](2026-10-28-android-app-id.md) | 앱 배포 준비 |
| 2026-10-27 | [Android 개발자 계정 승인 대기와 배포 준비](2026-10-27-android-release-preparation.md) | 앱 배포 준비 |
| 2026-10-27 | [iOS 0.2.0 빌드 6 TestFlight 업로드](2026-10-27-ios-b6-testflight.md) | 앱 업로드 |
| 2026-10-27 | [iOS 0.2.0 빌드 6 검증·배포용 빌드](2026-10-27-ios-b6-build.md) | 앱 빌드 |
| 2026-10-27 | [iOS 0.2.0 빌드 6 후보 준비](2026-10-27-ios-release-candidate.md) | 앱 배포 준비 |
| 2026-10-27 | [버전 관리와 배포 후보 준비 구현](2026-10-27-release-management.md) | 배포 도구 |
| 2026-10-26 | [이미지 운영 도구 사용성·검증 개선](2026-10-26-image-operator-usability.md) | 운영 도구 |
| 2026-10-26 | [실제 원본 백업·혼합 복원과 일일 백업 실행](2026-10-26-image-operator-production.md) | 운영 |
| 2026-10-26 | [이미지 운영자 통합 리뷰 보완](2026-10-26-image-operator-review.md) | 백업·복원 |
| 2026-10-26 | [비공개 Volume 원본 읽기와 원격 백업 검증](2026-10-26-private-source-backup.md) | 백엔드 |
| 2026-09-21 | [당시 Railway 배포 보고와 확인 범위](2026-09-21-railway-status.md) | 운영 |
| 2026-09-22 | [피드 복합 커서 수정](2026-09-22-feed-cursor.md) | 백엔드 |
| 2026-09-22 | [메타데이터 DNS 리바인딩 수정](2026-09-22-metadata-dns.md) | 백엔드 |
| 2026-09-22 | [태그 동시 교체 수정](2026-09-22-tag-concurrency.md) | 백엔드 |
| 2026-09-22 | [URL 길이 검증](2026-09-22-url-length.md) | 백엔드 |
| 2026-09-24 | [추천 DB 준비와 마이그레이션](2026-09-24-recommendation-db.md) | 추천 |
| 2026-09-24 | [저장·열람 이벤트 확장](2026-09-24-recommendation-events.md) | 추천 |
| 2026-09-24 | [콘텐츠·카테고리 노출 기록](2026-09-24-recommendation-exposures.md) | 추천 |
| 2026-09-24 | [재발견 추천 계획과 당시 단계 상태](2026-09-24-recommendation-planning.md) | 추천 |
| 2026-09-24 | [Today 선정과 일별 배치](2026-09-24-today-backend.md) | 추천 |
| 2026-09-25 | [Weekly 집계와 조회](2026-09-25-weekly-backend.md) | 추천 |
| 2026-10-02 | [카테고리 조합 검증](2026-10-02-category-validation.md) | 백엔드 |
| 2026-10-02 | [FE 초기 리뷰](2026-10-02-fe-review.md) | 프론트 |
| 2026-10-05 | [FE 통합 계획과 당시 진행 규칙](2026-10-05-fe-integration-plan.md) | 계획 |
| 2026-10-05 | [갱신 토큰 영속 저장](2026-10-05-refresh-persistence.md) | 인증 |
| 2026-10-05 | [일시 조회 실패와 세션 보존](2026-10-05-session-restore.md) | 인증 |
| 2026-10-06 | [저장 시 자동 분류 연결](2026-10-06-auto-category.md) | 저장 |
| 2026-10-06 | [카테고리 삭제와 콘텐츠 보존](2026-10-06-category-delete.md) | 분류 |
| 2026-10-06 | [콘텐츠 변경 상태 동기화](2026-10-06-content-state-sync.md) | 상태 |
| 2026-10-06 | [main과 FE 동기화](2026-10-06-fe-main-sync.md) | 통합 |
| 2026-10-06 | [피드 커서와 추가 조회 연결](2026-10-06-feed-pagination.md) | 조회 |
| 2026-10-06 | [동시 인증 갱신 중복 방지](2026-10-06-refresh-single-flight.md) | 인증 |
| 2026-10-06 | [스크린샷 인증 갱신과 재시도](2026-10-06-screenshot-auth.md) | 저장 |
| 2026-10-06 | [스크린샷 원본 조회](2026-10-06-screenshot-original.md) | 조회 |
| 2026-10-08 | [Android 플러그인 빌드 호환성](2026-10-08-android-build.md) | Android |
| 2026-10-08 | [iOS 권한 설명·빌드와 재업로드 준비](2026-10-08-ios-permissions.md) | iOS |
| 2026-10-09 | [프로젝트 개발 현황 스냅샷](2026-10-09-project-status.md) | 현황 |
| 2026-10-11 | [모바일 소셜 인증과 게스트 전환](2026-10-11-social-auth.md) | 인증 |
| 2026-10-12 | [프론트 1차 파일 분리](2026-10-12-frontend-file-split.md) | 구조 |
| 2026-10-12 | [프론트 상태·데이터 계층 분리와 회귀 수정](2026-10-12-frontend-layers.md) | 구조 |
| 2026-10-12 | [iOS 식별자와 서명 설정](2026-10-12-ios-signing.md) | iOS |
| 2026-10-12 | [모바일 공유 수신과 로컬 서버 검증](2026-10-12-mobile-share.md) | 공유 |
| 2026-10-12 | [상단 안전 영역과 헤더](2026-10-12-top-safe-area.md) | UI |
| 2026-10-13 | [공통 글자와 버튼 스타일](2026-10-13-figma-common.md) | UI |
| 2026-10-13 | [Figma 맞춤 계획과 당시 상태 표](2026-10-13-figma-planning.md) | 디자인 |
| 2026-10-13 | [홈의 확정 영역 첫 적용](2026-10-13-home-initial.md) | UI |
| 2026-10-13 | [확대 하단 탭과 최근 카테고리](2026-10-13-scaled-navigation.md) | UI |
| 2026-10-14 | [OS 하단 안전 영역과 인디케이터](2026-10-14-bottom-safe-area.md) | UI |
| 2026-10-14 | [이전 Figma 기준 전환](2026-10-14-figma-reference-switch.md) | 디자인 |
| 2026-10-15 | [붙여넣기 버튼 원본 스타일](2026-10-15-paste-button.md) | UI |
| 2026-10-15 | [붙여넣기 입력행 확대](2026-10-15-paste-input.md) | UI |
| 2026-10-15 | [저장 버튼과 키보드·안전 영역](2026-10-15-save-keyboard.md) | UI |
| 2026-10-15 | [저장 결과 문구와 제출 입력](2026-10-15-save-submitted-input.md) | 저장 |
| 2026-10-15 | [저장 화면 확대 글자 높이](2026-10-15-save-text-scale.md) | UI |
| 2026-10-15 | [저장 화면 기본 글자와 상단](2026-10-15-save-typography.md) | UI |
| 2026-10-16 | [저장 결과 카테고리 글자](2026-10-16-save-category-text.md) | UI |
| 2026-10-16 | [저장 결과 미리보기 글자](2026-10-16-save-preview-text.md) | UI |
| 2026-10-17 | [아카이브 전체보기 표현](2026-10-17-archive-layout.md) | UI |
| 2026-10-17 | [즐겨찾기 표현](2026-10-17-bookmark-layout.md) | UI |
| 2026-10-17 | [카테고리 시트와 삭제 팝업](2026-10-17-category-dialogs.md) | UI |
| 2026-10-17 | [카테고리 목록 표현](2026-10-17-category-list.md) | UI |
| 2026-10-17 | [카테고리 관리 표현](2026-10-17-category-management.md) | UI |
| 2026-10-17 | [상세 화면 표현](2026-10-17-detail-layout.md) | UI |
| 2026-10-17 | [Figma Page 1 기준 복원](2026-10-17-figma-page1-switch.md) | 디자인 |
| 2026-10-17 | [사진 선택 프레임 치수](2026-10-17-photo-frame.md) | UI |
| 2026-10-17 | [저장 결과 카테고리 간격](2026-10-17-save-category-gap.md) | UI |
| 2026-10-17 | [저장 결과 미리보기 시작 간격](2026-10-17-save-preview-gap.md) | UI |
| 2026-10-17 | [저장 결과 화면 표현](2026-10-17-save-result-layout.md) | UI |
| 2026-10-17 | [저장 결과 제목·출처 간격](2026-10-17-save-source-gap.md) | UI |
| 2026-10-17 | [저장 결과 제목 폭](2026-10-17-save-title-width.md) | UI |
| 2026-10-17 | [저장 결과 상단 여백](2026-10-17-save-top-gap.md) | UI |
| 2026-10-17 | [미분류와 확인된 빈 상태](2026-10-17-unclassified-layout.md) | UI |
| 2026-10-18 | [계정 관리 표현](2026-10-18-account-layout.md) | UI |
| 2026-10-18 | [카드 다시보기 표현](2026-10-18-card-review.md) | UI |
| 2026-10-18 | [홈 기본·빈 표현 마무리](2026-10-18-home-layout.md) | UI |
| 2026-10-18 | [홈 최초 조회 로딩](2026-10-18-initial-loading.md) | UI |
| 2026-10-18 | [관심사 선택 표현](2026-10-18-interest-layout.md) | UI |
| 2026-10-18 | [로그인 선택 표현](2026-10-18-login-layout.md) | UI |
| 2026-10-18 | [로그아웃 확인 표현](2026-10-18-logout-layout.md) | UI |
| 2026-10-18 | [마이페이지 표현](2026-10-18-my-layout.md) | UI |
| 2026-10-18 | [공지 목록 표현과 복귀](2026-10-18-notice-list.md) | UI |
| 2026-10-18 | [알림 목록과 빈 위젯](2026-10-18-notification-list.md) | UI |
| 2026-10-18 | [로그인 권한 안내](2026-10-18-permission-guide.md) | UI |
| 2026-10-18 | [사진 원본 비율과 전체 보기](2026-10-18-photo-contain.md) | UI |
| 2026-10-18 | [공통 저장 버튼 아이콘](2026-10-18-save-add-icon.md) | UI |
| 2026-10-18 | [검색 화면 표현](2026-10-18-search-layout.md) | UI |
| 2026-10-18 | [스플래시와 시작 흐름](2026-10-18-splash-layout.md) | UI |
| 2026-10-18 | [공통 하단 탭 아이콘](2026-10-18-tab-icons.md) | UI |
| 2026-10-19 | [게스트 연결 충돌 안내](2026-10-19-account-conflict.md) | UI |
| 2026-10-19 | [F01 카테고리별 콘텐츠 목록](2026-10-19-category-content.md) | UI |
| 2026-10-19 | [상세 하단 페이지 이동](2026-10-19-detail-paging.md) | UI |
| 2026-10-19 | [확정 디자인 구현 마감과 남은 경계](2026-10-19-figma-closure.md) | 디자인 |
| 2026-10-19 | [D04 링크 저장 처리 중](2026-10-19-link-pending.md) | UI |
| 2026-10-19 | [일반 로그인 실패 표현](2026-10-19-login-failure.md) | UI |
| 2026-10-19 | [A03 진행과 A04 SDK 취소](2026-10-19-login-progress.md) | UI |
| 2026-10-19 | [D08 사진 저장 처리 중](2026-10-19-photo-pending.md) | UI |
| 2026-10-21 | [원문 링크 외부 열기](2026-10-21-original-link.md) | 기능 |
| 2026-10-21 | [Today 버튼과 상세 탐색 연결](2026-10-21-today-frontend.md) | 추천 |
| 2026-10-21 | [Weekly 표시·이동·실제 노출 연결](2026-10-21-weekly-frontend.md) | 추천 |
| 2026-10-22 | [최근 검색어 저장과 삭제](2026-10-22-search-history.md) | 기능 |
| 2026-10-22 | [시스템 뒤로가기와 종료 확인](2026-10-22-system-back.md) | 기능 |
| 2026-10-22 | [운영 데이터 영속성과 백업·격리 복원 검증](2026-10-22-production-recovery.md) | 운영 |
| 2026-10-22 | [일반 문서 README·상세 기준 정리와 보존 검증](2026-10-22-general-docs-structure.md) | 문서 |
| 2026-10-23 | [에이전트 스킬 저장소 설정과 GitHub 라벨 확인](2026-10-23-agent-skills-setup.md) | 문서 |
| 2026-10-23 | [이미지 보관 정책 설계 인터뷰·명세 발행](2026-10-23-image-storage-design.md) | 설계 |
| 2026-10-23 | [이미지 보관 명세 통합 구현](2026-10-23-image-storage-implementation.md) | 통합 |
| 2026-10-23 | [비공개 Bucket 원본 보관과 기존 API 호환](2026-10-23-image-storage-bucket.md) | 저장 |
| 2026-10-23 | [계정별 이미지 한도와 양쪽 모바일 오류 안내](2026-10-23-image-storage-quota.md) | 저장 |
| 2026-10-23 | [원본 접근 확인과 직접 다운로드](2026-10-23-image-direct-download.md) | 조회 |
| 2026-10-23 | [계정별 기기 캐시와 양쪽 모바일 재시작 검증](2026-10-23-image-original-cache.md) | 조회 |
| 2026-10-23 | [원본 삭제 내구성과 정리 재시도](2026-10-23-image-deletion.md) | 저장 |
| 2026-10-23 | [DB·원본 Bucket 백업과 격리 복원](2026-10-23-image-storage-backup.md) | 운영 |
| 2026-10-23 | [일일 백업·7일 보존과 최신 삭제 상태 복원](2026-10-23-image-backup-retention.md) | 운영 |
| 2026-10-23 | [이미지 사용량과 저장 중단·재개 및 모바일 안내](2026-10-23-image-storage-controls.md) | 운영 |
| 2026-10-23 | [기존 원본 이관과 실제 CLI·이전 백업 복원 검증](2026-10-23-image-storage-migration.md) | 운영 |
| 2026-10-24 | [이미지 보관 전체 회귀·실제 모바일·다중 계정 복원 검증](2026-10-24-image-storage-integration.md) | 통합 |
| 2026-10-24 | [이미지 보관 두 축 리뷰와 최종 수정 검증](2026-10-24-image-storage-review.md) | 리뷰 |
| 2026-10-24 | [홈 최초 불러오기 복구 설계 인터뷰](2026-10-24-home-loading-recovery-design.md) | 설계 |
| 2026-10-24 | [홈 최초 불러오기 복구 구현](2026-10-24-home-loading-recovery-implementation.md) | 프론트 |
| 2026-10-24 | [마이 통계 조회 상태·복구 설계 인터뷰](2026-10-24-account-stats-recovery-design.md) | 설계 |
| 2026-10-24 | [마이 통계 조회 상태·복구 구현 명세 작성](2026-10-24-account-stats-recovery-spec.md) | 명세 |
| 2026-10-24 | [마이 통계 조회 상태·복구 구현 티켓 분할](2026-10-24-account-stats-recovery-tickets.md) | 티켓 |
| 2026-10-25 | [마이 통계 조회 상태·복구 구현](2026-10-25-account-stats-recovery-implementation.md) | 프론트 |
| 2026-10-25 | [카테고리 생성·수정 입력 보존과 실패 복구 설계](2026-10-25-category-save-recovery-design.md) | 설계 |
| 2026-10-25 | [카테고리 생성·수정 입력 보존과 실패 복구 구현 명세 작성](2026-10-25-category-save-recovery-spec.md) | 명세 |
| 2026-10-25 | [카테고리 생성·수정 입력 보존과 실패 복구 구현 티켓 분할](2026-10-25-category-save-recovery-tickets.md) | 티켓 |
| 2026-10-25 | [카테고리 입력 보존과 실패 복구 구현](2026-10-25-category-save-recovery-implementation.md) | 기능 |
| 미확인 | [과거 백엔드·운영 현황 설명](undated-backend-status.md) | 현황 |
| 미확인 | [과거 프론트 연동 상태 설명](undated-frontend-integration-baseline.md) | 현황 |
| 2026-10-26 | [삭제·보존 정리 없는 수동 백업](2026-10-26-manual-backup-command.md) | 백업 |

## 현재 안내와 배포 기록

- [프로젝트 안내](../../README.md) · [프론트 안내](../../frontend/README.md) · [백엔드 안내](../../backend/README.md)
- [MVP 현황](../backend-mvp-plan.md) · [추천 정책](../content-recommendation-plan.md) · [디자인 기준·확인 필요](../figma-ui-alignment-plan.md)
- [사용자 업데이트 내역](../../CHANGELOG.md) · [실제 배포 기록 절차](../release-process.md)

작업 이력, 사용자 업데이트 안내, 실제 공개·배포 기록은 서로 다른 사실을 기록합니다.
