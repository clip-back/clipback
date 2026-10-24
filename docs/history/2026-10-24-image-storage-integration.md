# 이미지 보관 전체 통합 검증 (#74)

2026-10-24 KST. 부모 명세 #64와 #65–#73 통합 후 #74를 검증했다.
메인 기준은 `5671e79a6c3451068cf053d185a9334fd9f3144c`, 작업 브랜치는
`feature/image-storage-validation-74`다. 사용자 승인을 받은 경계인 인증 API, 앱 HTTP·캐시,
실제 격리 복원을 사용했다. 운영 Railway·실제 OAuth·실기기·배포·운영 이관을 실행하지 않았다.

## 소스와 검증 경계

- `6b02629`: 실제 HTTP·영구 세션·네이티브 채널을 사용하는 테스트 진입점과 통합 Docker 경로.
- `7d2fe31`: 테스트 진입점의 binding과 runApp을 같은 HTTP 관찰 zone에 배치하고 실제 화면 이동을 보완.
- `f5618c9`: 여러 계정이 있는 복원에서 살아 있는 표본을 유지하고, 삭제 후 대체 표본을 인증 계정의
  원본으로 제한. 타인의 원본만 남으면 인증·삭제 404를 확인하고 이미지 GET 생략을 명시.
- `80ec220`: 공식 PostgreSQL 이미지의 Unix 전용 임시 서버와 최종 TCP 서버를 구분해 준비 대기.
- API 이미지 `clipback-integration74-api:check`의 revision은 전체 `6b026290f312aa763df99339f8b75d9261597570`.
  이후 API 제품 소스는 바뀌지 않았다. 최종 운영자 이미지 `clipback-integration74-operator-final:check`는
  변경된 복원 스크립트를 포함하며 revision은 전체 `80ec2200d81b548e9691e553eb2b49d26715f6b0`다.

모바일 진입점은 실제 `ClipbackApp`, 기본 SharedPreferences 세션, path_provider 파일 캐시,
정상 Flutter binding과 실제 App Group/Keychain·Android Keystore 공유 채널을 사용했다.
HTTP 관찰은 IOClient에 요청·응답을 그대로 전달한다. MockClient나 네이티브 채널 대역을 쓰지 않았다.
원본 Bucket 요청에 Authorization/Cookie가 없음을 관찰했다. 본앱 사진 선택만 저장소 PNG를 반환하는
picker 대역이고, 서버의 OCR·메타데이터·소셜 공급자와 앱의 소셜 SDK는 명시적 대역이다.

일반 사진은 저장소의 `saved-photo-preview.png` 478,337바이트,
SHA-256 `0f0a8eb398ca1b3b3ee6564da8c72ddc53727b215ced115abc77b310b7780a82`다.
iOS 송신 앱은 별도 400×300 PNG 31,517바이트,
SHA `5accfc31e4aa2c6f51a3f5081181fc0a1976a2deec2d8408304dd1ce26e06d5e`를 생성했다.
Android 송신 provider는 640×480 PNG 9,453바이트,
SHA `270a15f8e5d4a01601df5377f9a1c524e2ef70ae543c82c675aaf379f63089af`를 생성했다.
각 송신 파일과 실제 PostgreSQL 자산 메타데이터·실제 HTTP S3 객체 바이트를 독립 대조했다.

## 전체 자동 검사

공유 Python venv와 작업 트리의 `PYTHONPATH`, disposable PostgreSQL 17의 `clipback_image_74`를 사용했다.
기본 `DATABASE_URL`은 의도적으로 접근 불가능한 localhost 1 포트로 지정하고,
`TEST_DATABASE_URL`만 실제 격리 DB로 연결해 개발 DB 의존이 없는지도 확인했다.

| 검사 | 실제 결과와 해석 |
| --- | --- |
| 최초 전체 backend | 1,103 passed, 17 skipped, 62.32초. 당시 Docker 16개와 실제 HTTP CLI 1개는 별도 옵션이었다. |
| 실제 HTTP 운영 CLI | 로컬 moto 55465 옵션으로 별도 1 passed, 2.73초. 자기 UUID 버킷만 생성·정리했다. |
| 복원 수정 후 전체 backend | 1,104 passed, 17 skipped, 99.41초. 실제 HTTP CLI를 포함했고 skip 17개는 Docker 사례 전부다. CLI를 중복 합산하지 않는다. |
| TCP 준비 수정 후 최종 전체 backend | 1,104 passed, 19 skipped, 76.20초. 실제 HTTP CLI를 포함하며 skip 19개만 별도 실제 Docker 검증이다. |
| 전체 Flutter | 1,808 passed, 181초. 정적 분석 No issues found. 복원 수정은 Flutter 제품을 변경하지 않았다. |
| Alembic | 빈 DB → head, 기존 메인 `202610120014` → `202610230018`, `alembic check` No new upgrade operations detected. |
| Ruff·diff | 전체 backend Ruff와 `git diff --check` 확인. |
| 실제 Docker, 최초 수정 후 | 기존 16 passed, 240.91초. PostgreSQL 16·18 v1, v2 혼합 원본·삭제 기록·보존·운영 중단·이관을 포함했다. |
| 다중 계정 실제 Docker | RED 1 failed, 44.64초 → GREEN 1 passed, 122.89초. 같은 백업으로 살아 있는 표본·삭제 후 같은 소유자의 대체 표본·타인 원본만 남은 경우를 실제로 세 번 복원했다. |
| PostgreSQL 준비 경계 | 느린 초기화의 실제 TCP 검사 RED 1 failed, 16.03초 → PG16·18 GREEN 2 passed, 55.21초. |
| 최종 복원 스크립트·운영자 이미지 | TCP 준비 수정 후 최종 운영자 이미지로 실제 Docker 19 passed, 394.82초. v1 PG16·18, v2·보존·이관·다중 계정·지연 초기화 전체를 같은 실행에서 확인했다. |

pytest는 기존 Starlette/httpx 사용 중단 경고 한 건을 냈다. Flutter 테스트는 기존 SVG filter 진단을
출력했으며 테스트 실패는 없었다. Android 빌드는 기존 Kotlin 버전의 향후 지원 경고를 냈다.
이를 이유로 무관한 의존성·SDK 설정을 바꾸지 않았다.

실행 명령은 backend에서 `python -m pytest -q`, `python -m ruff check .`,
`python -m alembic upgrade head`, `python -m alembic check`, frontend에서
`flutter test`, `flutter analyze`를 사용했다. 실제 CLI는
`CLIPBACK_IMAGE_TEST_S3_ENDPOINT=http://127.0.0.1:55465`를 추가했다. Docker는
`RUN_DOCKER_RECOVERY_TESTS=1`, 위 API·운영자 이미지 변수와 함께
`test_backup_restore_docker.py`, `test_image_backup_docker.py`, `test_image_migration_docker.py`,
`test_multiuser_image_restore_docker.py`, `test_postgres_restore_ready_docker.py`를 실행했다.

다중 계정 수정 후 17개 묶음은 16 passed·PG18 정상 복원 1 failed, 363.09초였다. 실패는
`docker_command_failed` 3.325초였고 단독 재실행은 1 passed, 23.46초였다. 단순 재시도 성공으로
해결 처리하지 않았다. 로컬 공식 postgres:18의 `/usr/local/bin/docker-entrypoint.sh`를 읽어
임시 서버가 `listen_addresses=''`로 Unix만 열고 초기화 뒤 중지됨을 확인했다. 초기화 SQL을
5초 지연시킨 실제 검사에서 준비 대기가 TCP 연결 전에 반환하는 오류를 16.03초에 재현했다.
제품 복원과 두 원본 Docker fixture를 최종 TCP 대기로 바꾸고 PG16·18의 실제 복원이 통과했다.
앞선 PG18 실패가 오직 이 원인이었다고 단정하지 않으며, 재현한 잘못된 준비 경계와 수정 결과를 남긴다.

## 실제 모바일 실행

| 플랫폼 | 실행 환경 |
| --- | --- |
| iOS | iPhone 16 Pro, iOS 18.6, UDID `47066462-C5C3-4C7D-AE37-80A2C60A2BFE`, 1206×2622, DPR 3, 논리 402×874, safe top/bottom 62/34 |
| Android | AVD `Clipback_Share_API_33`, Android 13/API 33 arm64, emulator-5554, 1080×2220, DPR 2.75, safe top/bottom 24/0, host GPU |

제품 API·Flutter base URL은 양 플랫폼과 네이티브 공유 모두 localhost 18766을 가리켰다.
Android API는 10.0.2.2, S3 서명 URL은 adb reverse 55465로 연결했다. iOS 본앱과 확장의
실제 빌드 plist가 모두 같은 API base URL을 갖는지도 확인했다.
공통 서버는 실제 FastAPI + PostgreSQL 17 `clipback_image_74_native` + 별도 원본·독립 기록·백업
합성 S3 버킷을 사용했다. API 환경에는 백업 자격증명이 없었다.

| 시나리오 | iOS | Android |
| --- | --- | --- |
| 일반 저장·실제 공유 이미지 저장 | 사용자 2에 실제 두 원본 509,854바이트와 공유 receipt 1개 | 사용자 4에 실제 두 원본 487,790바이트와 공유 receipt 1개 |
| 첫 원본 열기 | access 1 / Bucket GET 1, 실제 원본 표시 | access 1 / Bucket GET 1, 실제 원본 표시 |
| 상세 재진입 | access 2 / Bucket GET 1 | access 2 / Bucket GET 1 |
| 실제 프로세스 종료·재실행 | 같은 사용자 2, 새 프로세스 access 1 / Bucket GET 0, 캐시 478,337바이트 | 같은 사용자 4, 새 프로세스 access 1 / Bucket GET 0, 캐시 478,337바이트 |
| 운영 중단 | 본앱·실제 공유 확장에 서버 409 문구, OCR 증가 없음 | 본앱·실제 공유 Activity에 서버 409 문구, OCR 증가 없음, 재개 후 저장 성공 |
| 계정 한도 | 사용자 2의 실제 파일 합계 30MiB 준비 후 본앱·확장 서버 409 문구 | 공유 사용자 4·최종 본앱 사용자 8 각각 실제 파일 합계 30MiB에서 서버 409 문구 |
| 로그아웃·새 계정 | 사용자 2 → 5, 캐시 0, 이전 자산 access 404 | 사용자 4 → 8에서 캐시 0·이전 자산 access 404. 최종 오류 캡처 후 8 → 9에서도 캐시 0·이전 자산 404 |

한도 준비는 별도의 합성 DB 행과 실제 S3 PNG 파일로 구성했다. PNG에 보존한 padding까지 실제
크기·SHA를 갖추었으며 1개당 10MiB 이하로 나눴다. 기기에서 30MiB를 직접 여러 번 올린 것으로
보고하지 않는다. 그 상태의 실제 API 권한·합계·유료 처리 전 거절은 제품 코드가 수행했다.
게스트 승격·300MiB·동시 저장·완료 공유 재전송은 기존 인증 API 통합 테스트가 주 검증 경계다.
실제 소셜 공급자의 재로그인·앱 재설치·기기 교체를 실행했다고 주장하지 않는다.

기존 에뮬레이터 프로세스가 사라져 같은 AVD를 host GPU로 다시 실행했으며 데이터를 지우지 않았다.
기존 검증 캐시는 실제 로그아웃으로 비운 뒤 새 계정으로 최종 캐시 시나리오를 실행했다.
초기 캡처 중 비동기 요청 완료 전 홈·처리 중 프레임은 오류 증거에서 제외하고, 실제 문구가
렌더링된 뒤 캡처한 최종 프레임을 선정했다. 이들은 숨기거나 이미지 보정으로 바꾸지 않았다.

## 같은 저장 환경의 백업·이관·삭제 복원

API 쓰기를 실제로 중지한 뒤 모바일 원본을 포함한 자산 10개와 별도 운영자 계정의 기존 로컬
원본을 PostgreSQL 17의 실제 pg_dump로 함께 백업했다. 로컬 원본은 합성 준비이며 새 업로드로
위장하지 않았다. `native74-before-migration`의 manifest SHA는
`cd42a776c03e3a9fb36410e410422155fa388343499c9619c405054193d963d5`다.

최초 실제 복원은 여러 계정 중 첫 자산을 선택해 검증 계정의 권한과 달라 실패했다.
새 Docker 회귀도 같은 실패를 재현했다. 표본 선택을 수정한 뒤 같은 입력·자격을 그대로 복원해
`passed`, `authentication_passed`, `image_bytes_passed`, `cleanup_passed`,
`live_deletion_ledger_verified`, `deletions_applied`가 모두 true이고 자산 10개임을 확인했다.
성공 보고서를 사용한 제한 1개 이관은 `migrated: 1`, 새 프로세스 재개는 `migrated: 0`이었다.
기존 인증 GET과 새 직접 접근에서 같은 478,337바이트·SHA를 확인했고, 이 시점에는 이전 로컬 사본도
유지됐다. 실제 DELETE 204 후 콘텐츠·기존 원본 GET·새 access가 모두 404였으며 이전 로컬 사본과
실제 주 Bucket 객체도 제거됐다. API를 다시 실제 중지한 뒤 같은 오래된 지점을 최신 독립 기록으로 복원했다.
`passed`, `authentication_passed`, `cleanup_passed`, `live_deletion_ledger_verified`가 true,
`deleted_content_count: 1`, 남은 자산 9개였다. 시험 계정에는 원본이 없고 타인의 모바일 원본만
남았으므로 `image_get_skipped: true`, `image_bytes_passed: false`를 정확히 기록했다.

같은 API·DB·버킷을 다시 열어 별도 실제 게스트 사용자 10이 원본을 POST 201로 저장한 뒤 공개
`auth/social/kakao/upgrade`를 호출했다. 소셜 검증은 대역이다. 새 세션에서 같은 사용자 ID 10,
`is_guest: false`, 같은 콘텐츠 12·자산 18·478,337바이트·SHA·원본 접근을 확인했다.
300MiB 정확한 경계는 기존 API 테스트가 검증하며 이 호출을 실제 OAuth로 보고하지 않는다.

## 명세 사용자 시나리오 42개 대조

`API`는 실제 PostgreSQL 인증 통합 테스트, `D`는 실제 Docker 격리 복원,
`M`은 위 두 OS 실제 FastAPI·HTTP S3 실행, `F`는 Flutter HTTP/실제 임시 파일 캐시 경계를 뜻한다.

| 번호 | 요구 | 확인 경계·근거 |
| --- | --- | --- |
| 1 | 원본 보존 | API `test_upload_and_isolation`, M 세 가지 독립 원본 해시 |
| 2 | 게스트 30MiB | API `test_image_quota`, M 정확한 실제 보관량에서 거절 |
| 3 | 로그인 300MiB | API `test_guest_promotion_keeps_images_and_applies_300mib_exact_boundary` |
| 4 | 동일 계정 승격 | 위 API에서 ID·자료·사용량 유지, 동일 모바일 저장 환경에서도 실제 승격 후 동일 ID·자산·바이트 확인. 공급자 검증은 대역 |
| 5 | 파일 형식·10MiB | API 업로드·한도·네이티브 공유 검증, 기존 OS 파일 한도 오류 증거 |
| 6 | OCR·분류 유지 | API `test_upload_and_isolation`, M 실제 업로드→OCR 대역→콘텐츠 |
| 7 | 일반·공유 합계 | API quota·동시 쓰기, M 같은 사용자 ID·asset·receipt·실물 바이트 |
| 8 | 정확한 한도 | API guest/login exact·+1, M 실물 30MiB 초과 거절 |
| 9 | 동시 저장 | API 서로 다른 DB 연결의 main/native 경쟁 |
| 10 | 공유 재전송 | API mobile_share·share_write_concurrency·quota·controls |
| 11 | 한도 안내 | M 본앱 실제 409, 기존 영역과 원본 선택 유지 |
| 12 | 총량·파일 구분 | API 구조화 코드, 양 OS 공유 자체 검사·보존된 화면 |
| 13 | 기존 열람·삭제 | API quota·controls·deletion, M 한도 후 원본 접근 |
| 14 | 원본 자동 만료 없음 | 정책·저장/정리 경로 정적 확인, F 캐시 정리 후 클라우드 유지. 실제 공급자 lifecycle은 미설정·미검증 |
| 15 | 다른 세션의 로그인 복구 | API 인증·승격·소유권, 같은 환경의 승격 후 새 토큰으로 원본 확인, M 영구 세션 재시작. 실제 OAuth/재설치/새 기기 검증은 제외 |
| 16 | 게스트 복구 경계 | 정책·운영 전환 문서, 별도 로그인 유도 UI 추가 없음 |
| 17 | 소유권 | API asset_access·upload_and_isolation, M 새 계정의 이전 자산 404 |
| 18 | 반복 캐시 | F original_image_cache, M 재진입·실제 OS 재시작 GET 수 |
| 19 | 권한 확인 후 캐시 | F 삭제 404·상세 재진입, M 매번 access·새 계정 404 |
| 20 | 손상 캐시 | F 실제 임시 파일 손상·부분 파일 후 재다운로드 |
| 21 | 기기 상한 | F 100MiB·7일 미사용 정리 |
| 22 | 캐시와 원본 분리 | F 정리 후 서버 원본 유지, 정책·저장소 구현 |
| 23 | 계정·늦은 완료 | F 세션 generation·진행 응답 무효화, M logout 캐시 0·계정 변경 |
| 24 | 서명 만료 재시도 | F screenshot_asset_access 1회 재발급·Bucket 오류와 API 인증 구분 |
| 25 | 불완전 응답 | F MIME·크기·SHA·중단·제한 시간 검증 |
| 26 | 삭제 즉시 한도 반환 | API image_deletion·image_quota |
| 27 | 오래된 복원 재노출 방지 | D image_backup·image_migration·multiuser, 동일 모바일 환경 복원 |
| 28 | 백업 삭제 7일 | operator retention 경계·정리 실패·기한 초과와 D 실제 정리 |
| 29 | DB와 실제 원본 복원 | D PG16·18 v1·PG16 v2·동일 모바일 PG17 |
| 30 | 일일 복구 지점 | backup_jobs 일일 ID·중복·실제 operator 이미지 검사. 실제 운영 스케줄 미실행 |
| 31 | 기존 원본 GET | API mixed local/S3·D migration·M 사용한 같은 백엔드 |
| 32 | 기존 자료 연결 | API migration ID·소유권·saved_at·바이트, D 실제 중단·재개 |
| 33 | 기존 초과량 보존 | API quota·migration, 원본 TTL·강제 정리 없음 |
| 34 | 비용 구분 | API controls·실제 HTTP CLI의 논리/실물/백업/관측 전송, 미관측 null |
| 35 | 신규 저장 중단 | API controls와 D migration/control, M 본앱·공유의 실제 중단/재개 |
| 36 | 저장 실패 정리 | API upload/deletion/migration의 PUT·DB 실패와 commit 불확실성 |
| 37 | 삭제 재시도 | API 새 worker·독립 ledger·실제 CLI, D old-point 복원 |
| 38 | 백업 재사용·무결성 | D 원본 해시·중복 지점·손상/누락/미완료·보존 |
| 39 | 백업 권한 분리 | API/운영자 Docker allowlist·설정 분리, 실제 공급자 IAM은 미검증 |
| 40 | 이관 검사·재개 | API migration·실제 D CLI·동일 환경 실제 보고서 기반 이관 |
| 41 | 증거 경계 | 이 문서·원본 manifest·현재 운영 전환 문서 |
| 42 | 장애 보장 한계 | 백업 실패·삭제 기록 누락 fail closed 검사와 문서의 일일 목표·같은 공급자 위험 |

## 화면 비교와 자료 위치

원본 미디어는 아래 지속 경로의 `integration74/`에 보존했다.

`/Users/leehyeongyu/.codex/visualizations/2026/10/22/01a16370-b415-77f3-a86a-160b5b4f0a56/image-storage-implementation/`

`comparison.html`은 변경 전·후·정확한 Figma 상태의 3열 비교다. 파일은 OS PNG 원본이며 잘라내거나
재도색하지 않았다. 정확한 원본 모달·한도·중단 오류 Figma는 없으므로 세 번째 칸에 누락을 표시했다.
2026-10-23 조회한 F02 `111:3842`, D07 `111:4814`, D09 `111:4865`는 공통 화면 참고이며,
F03 `111:3771`은 기사/YouTube 펼침 화면이어서 원본 이미지 모달의 대체 기준으로 쓰지 않았다.
375×812 Figma와 실제 OS 논리 크기·안전 영역의 차이를 그대로 표시했다.

기존 iOS 오류 비교는 같은 합성 이미지·배율 1·scroll 12px를 유지한 #66/#72 프레임을 사용한다.
Android 변경 전 JSON은 scroll 31.727px지만 실제 OS 원본 위치는 새 scroll 0px 프레임과 맞는다.
원인은 확인되지 않았으며 같은 숫자의 scroll이 같은 실제 프레임이라는 주장을 철회한다.
숫자 일치 프레임과 OS 위치 보조 프레임을 모두 보존하고 이 불일치를 비교 보고서에 명시했다.
이번 실제 API 원본 화면은 계정·제목·자료 상태가 달라 기능 증거이며 픽셀 비교 쌍으로 주장하지 않는다.

선정된 상태 JSON의 계정·GET 수·캐시 0·404·Flutter 오류 부재를 대조했고, 설치 APK·iOS Runner·
kernel과 진입점 소스의 SHA를 `native-build-manifest.json`에 기록했다. 오류·원본·공유·로그아웃
스크린샷과 두 OS 재시작 영상은 `comparison.html`, `comparison-manifest.json`, `evidence-files.json`으로
연결한다. 실제 기기 설정은 Android 1080×2220·440dpi·font_scale null(기본값), iOS content size large였다.

증거를 모두 내보낸 뒤 이번 작업 트리의 `frontend/build` 2.3GiB만 정리했다. 합성 API 서버와
본앱 프로세스는 종료했으며 운영 자원·사용자 자료·전역 SDK/cache를 정리하지 않았다.

실제 운영자 설정·토큰·덤프·원본 archive는 비공개 임시 디렉터리에만 있고 Git이나 화면 보고서에
포함하지 않았다. 실제 Railway·운영 자격·운영 백업/이관/스케줄·배포·원격 CI·실기기·외부 Instagram/
YouTube 앱·TestFlight는 미검증이다. 비용은 실제 청구액을 측정하지 않았다.
