# 이미 지워진 콘텐츠의 삭제 404를 삭제 성공으로 처리 (#364)

2026-11-14, 브랜치 `fix/photo-result-mismatch`. 시작 커밋 `d529d00`.
팀 피드백 시트 76("실패해도 저장이된 경우 같은 안 맞는 경우")과 0.5.2 실기기에서 사진 콘텐츠 삭제 때 '삭제 실패'가 두 번 뜬 뒤 실제로는 지워져 있던 사용자 확인 중, 두 번째 실패 안내를 다룬다. 첫 실패 안내와 사진 저장 쪽은 #366(진단)이다.

## 문제

- 서버에서 이미 지워진 콘텐츠를 다시 지우면 서버가 404 `Content not found`를 돌려준다. 앱은 이를 삭제 실패로 처리해 영어 문구를 스낵바로 보이고 항목을 목록·상세에 남겼다.

## 사용자 결정

- 2026-11-14 "모두 추천대로": 범위는 콘텐츠 삭제만이다. 삭제 요청의 404는 서버 `detail` 문구와 관계없이 성공과 같은 결과로 처리한다. 즐겨찾기·카테고리 변경·카테고리 삭제·수정의 404는 범위 밖이다.

## 구현

- `ContentRepository.executeContentMutation`의 삭제 요청에서 `ClipbackApiException.statusCode == 404`만 잡아 성공으로 넘긴다. 그 뒤는 기존 성공 경로 그대로다: 삭제 표시 버전 기록, 모든 목록 페이지·오늘 묶음·즐겨찾기 id·열린 상세에서 제거, `DetailDeletedEffect`(상세면 진입 목록으로), `ContentActions`의 첫 페이지 재조회.
- 사진·링크 콘텐츠와 홈·아카이브·즐겨찾기·검색·상세의 삭제는 모두 같은 `DELETE /contents/{id}` 요청과 이 저장소 경로를 거친다(서버에서 사진은 이미지 삭제 서비스로 넘어가지만 앱 요청은 같다). 그래서 404 처리도 한 곳만 바꿨다.
- 404가 아닌 실패(401·403·409·5xx·연결 실패·응답 파싱 실패)와 즐겨찾기·카테고리 변경의 오류 처리는 바꾸지 않았다. 서버는 바꾸지 않았다.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-364/partial-*.log`, 저장소에 넣지 않음).

- 재현: `content_mutation_test.dart` 'delete <응답> from <detail|archive> ends like a successful delete'. 앱 전체를 띄우고 응답 204·404 `Content not found`·404 다른 문구·404 빈 본문을 상세(더보기 → 삭제 → 확인)와 아카이브에서 확인한다. 스낵바 없음, 상세 닫힘(진입 목록 홈), 항목 제거, 첫 페이지(cursor 없는) 피드 재조회를 본다. 수정 전 404 6건 실패, 204 2건 통과.
- 기존 반복 테스트의 `delete` × `404` 조합만 반복에서 빼고 위 테스트로 옮겼다(이슈 허용 칸). 같은 반복의 즐겨찾기·카테고리 × 404와 삭제 × 다른 실패는 기대값 그대로 통과한다. `category_delete_test.dart`는 바꾸지 않았다.

## 검증

- 부분 검사: `content_mutation_test.dart` 전체 139건, `category_delete_test.dart`·`data/content_repository_test.dart`·`feed_pagination_test.dart`·`view_models/content_view_models_test.dart` 227건 통과, 바꾼 파일 analyze·format 통과.
- 전체 검증과 변경 후 화면 비교는 리뷰 반영 뒤 이 문서에 더한다. 변경 전 화면(iOS 18.6 iPhone 16·Android 16 `Medium_Phone`, 로컬 대역, 배율 1.0)은 `detail-delete-404`·`archive-delete-404`·`archive-delete-503` 세 상태를 찍었다. Figma 기준 없음.
