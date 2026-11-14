# 이미 지워진 콘텐츠의 삭제 404를 삭제 성공으로 처리 (#364)

2026-11-14, 브랜치 `fix/photo-result-mismatch`. 시작 커밋 `d529d00`, 구현 커밋 `bdd0a2c`, 리뷰 반영 `9f4112e`, main(#353·#354 스낵바, `de1eb1c`) 병합 `6f82cdd`, main(#355–#358 홈·카테고리, `617aa21`) 병합 `d865dde`(최종 전체 검증 기준). 검증 결과를 채운 커밋은 문서만 바꾼다.
팀 피드백 시트 76("실패해도 저장이된 경우 같은 안 맞는 경우")과 0.5.2 실기기에서 사진 콘텐츠 삭제 때 '삭제 실패'가 두 번 뜬 뒤 실제로는 지워져 있던 사용자 확인 중, 두 번째 실패 안내를 다룬다. 첫 실패 안내와 사진 저장 쪽은 #366(진단)이다.

## 문제

- 서버에서 이미 지워진 콘텐츠를 다시 지우면 서버가 404 `Content not found`를 돌려준다. 앱은 이를 삭제 실패로 처리해 영어 문구를 스낵바로 보이고 항목을 목록·상세에 남겼다.

## 사용자 결정

- 2026-11-14 "모두 추천대로": 범위는 콘텐츠 삭제만이다. 삭제 요청의 404는 서버 `detail` 문구와 관계없이 성공과 같은 결과로 처리한다. 즐겨찾기·카테고리 변경·카테고리 삭제·수정의 404는 범위 밖이다.

## 구현

- `ClipbackApi.deleteContent`가 HTTP 응답 상태를 받은 직후 404면 오류 본문을 해석하지 않고 성공으로 끝낸다. 404가 아닌 응답은 전과 같이 `_throwForError`와 본문 해석(2xx 손상 본문은 실패)을 거친다. 인증 갱신·세션 세대·취소 검사는 공용 `_request` 그대로다. 저장소는 바꾸지 않았고 성공한 삭제 요청으로 보아 기존 성공 경로를 탄다: 삭제 표시 버전 기록, 모든 목록 페이지·오늘 묶음·즐겨찾기 id·열린 상세에서 제거, `DetailDeletedEffect`(상세면 진입 목록으로), `ContentActions`의 첫 페이지 재조회.
- 같은 helper(`_request`·`_throwForError`·`_json`·`_decodeJson`)는 바꾸지 않아 다른 요청(카테고리 삭제 `DELETE /categories/{id}` 포함)의 404·파싱 실패 처리는 그대로다.
- 사진·링크 콘텐츠와 홈·아카이브·즐겨찾기·검색·상세의 삭제는 모두 같은 `DELETE /contents/{id}` 요청과 이 저장소 경로를 거친다(서버에서 사진은 이미지 삭제 서비스로 넘어가지만 앱 요청은 같다). 그래서 404 처리도 한 곳만 바꿨다.
- 404가 아닌 실패(401·403·409·5xx·연결 실패·응답 파싱 실패)와 즐겨찾기·카테고리 변경의 오류 처리는 바꾸지 않았다. 서버는 바꾸지 않았다.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-364/partial-*.log`, 저장소에 넣지 않음).

- 재현: `content_mutation_test.dart` 'delete <응답> from <detail|archive> ends like a successful delete'. 앱 전체를 띄우고 응답 204·404 `Content not found`·404 다른 문구·404 빈 본문을 상세(더보기 → 삭제 → 확인)와 아카이브에서 확인한다. 스낵바 없음, 상세 닫힘(진입 목록 홈), 항목 제거, 첫 페이지(cursor 없는) 피드 재조회를 본다. 수정 전 404 6건 실패, 204 2건 통과.
- 리뷰 반영 재현: 같은 테스트에 404 본문 루트 배열·`null`·숫자, `detail` 목록·맵, 깨진 JSON을 더했다. 첫 구현(저장소에서 `statusCode == 404` 예외만 성공 처리)에서는 루트 배열·`null`·숫자·`detail` 목록이 본문 해석 중 TypeError로 상태 코드를 잃어 실패했다(상세·아카이브 8건).
- 기존 반복 테스트의 `delete` × `404` 조합만 반복에서 빼고 위 테스트로 옮겼다(이슈 허용 칸). 같은 반복의 즐겨찾기·카테고리 × 404와 삭제 × 다른 실패는 기대값 그대로 통과한다. `category_delete_test.dart`는 바꾸지 않았다.

## 검증

- 부분 검사(리뷰 반영 뒤): `content_mutation_test.dart` 전체 151건, `category_delete_test.dart`·`data/content_repository_test.dart`·`feed_pagination_test.dart`·`view_models/content_view_models_test.dart`·`session_refresh_test.dart`·`session_restore_test.dart`·`account_deletion_api_test.dart` 358건 통과, 바꾼 파일 analyze·format 통과. 첫 구현 때는 139건·227건(앞 4개 파일) 통과였다.
- 병합(`6f82cdd`) 뒤 부분 검사: `content_mutation`·`snackbar_font_root`·`snackbar_stack_root`·`contact_form_root`·`my_legal_links_root`·`category_delete` 테스트 242건 통과, `flutter analyze --no-pub` 문제 없음.
- 전체 검증(`6f82cdd`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3541건 통과. 백엔드 pytest 2640 passed, 49 skipped. skip은 `tests/deployment` 48건(`RUN_DOCKER_RECOVERY_TESTS=1`과 라벨 붙은 로컬 이미지 필요 외 6종, CI에서만 실행)과 `tests/integration` 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 필요)이다. 백엔드는 이번에 바꾸지 않았다.
- 두 번째 병합(`d865dde`) 뒤 부분 검사: `content_mutation`·`home_alignment`·`category_content_alignment`·`unclassified_alignment`·`uncategorized_name`·`weekly_root`·`category_delete`·`feed_pagination` 테스트 544건 통과, `flutter analyze --no-pub` 문제 없음.
- 최종 전체 검증(`d865dde`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3621건 통과. 백엔드 pytest 2640 passed, 49 skipped(skip 사유는 위와 같다). 위 `6f82cdd` 결과는 그 커밋의 기록으로 남긴다.
- 변경 전 화면(`d529d00`, iOS 18.6 iPhone 16·Android 16 `Medium_Phone`, 로컬 대역, 배율 1.0): `detail-delete-404`·`archive-delete-404`는 스낵바 `Content not found`와 상세·카드 유지, `archive-delete-503`은 `요청을 처리하지 못했습니다.`와 카드 유지. Figma 기준 없음.
- 변경 후 화면 비교는 아직 하지 않았다(미완료). 병합한 main #354로 스낵바 글꼴이 Pretendard로 바뀌어, 503 안내의 글자 모양 차이는 #364가 아닌 #354 영향이다.

## 검토

검수(Codex, `.utmp/review-364.md`): Standards 0개, Spec 중간 1개.

- 반영: 404 본문이 루트 배열·`null`이거나 `detail`이 잘못된 타입이면 오류 본문 해석이 TypeError로 끝나 404 상태를 잃고 실패로 보였다. 사용자 결정("삭제 요청의 404는 detail과 관계없이 성공")에 맞게 404 판정을 상태 코드를 가진 API 삭제 경계로 옮겼다. 저장소에서 TypeError 전체를 성공으로 보지 않는다. 저장소의 404 catch는 중복이 되어 지웠다.

재검수(Codex, `.utmp/review-364-r2.md`, `9f4112e`): Standards 0개, Spec 0개. 위 지적 해결 확인. 요청 경로·인증 갱신·세션 교체·취소·404가 아닌 실패·2xx 본문·저장소 후처리 계약이 유지됨을 대조했다. `_throwForError` 호출은 기존 7곳이 그대로이고 `deleteContent`의 직접 호출 1곳이 더해져 모두 8곳이다(동작 결함 아님).

병합 검수(Codex, `.utmp/review-364-merged.md`, `6f82cdd`): Standards 0개, Spec 0개. main의 스낵바 교체(clearSnackBars → showSnackBar)·글꼴 변경과 #364 삭제 처리가 충돌하지 않는다. 404 성공은 실패 안내를 만들지 않고, 503은 기존 실패 안내 하나를 보인다.

두 번째 병합 검수(Codex, `.utmp/review-364-merged2.md`, `d865dde`): Standards 0개, Spec 0개. main의 아카이브 목록 배치·하단 여백·미분류 이름 변경이 #364 삭제 경로와 촬영 데이터(601–604, 미분류 없음)를 바꾸지 않음을 확인했다. 위젯 테스트의 화면 크기·안전 영역은 기기와 달라, 기기 화면 조건의 동일성은 변경 후 촬영에서 따로 대조한다.
