# 저장 화면에서 첨부한 HEIC 사진을 JPEG로 바꿔 저장하고 형식 거절 안내를 한국어로 (#380)

2026-11-14–15, 브랜치 `fix/heic-to-jpeg`. 시작 커밋 `6e2681f`, 구현 커밋 `9db9e3d`, 이력 `bc5d7bd`, main(#390, `af2fb2b`) 병합 `53ab539`(최종 전체 검증 기준). 이후 `5ea3a31`은 이 문서만 바꿨으며 최종 안내 재촬영·실기기 실행의 기준이다.
팀 피드백 시트 100("iPhone 카메라 기본 형식(HEIC) 사진을 저장 화면에서 첨부하면 저장이 거절되고 영어 알림이 뜸")을 다룬다.

## 문제

- 저장 화면의 사진 첨부는 파일 선택기가 준 바이트를 그대로 보냈다. iPhone 카메라 기본('고효율') 사진은 HEIC이고, 서버는 PNG·JPEG·WebP만 받아 415(`Unsupported or invalid screenshot image`)로 거절했다. 앱은 이 영어 문구를 그대로 띄웠다.

## 사용자 결정

- 2026-11-14 "추천대로"(이슈 #380 Solution): HEIC/HEIF만 앱이 JPEG로 바꿔 보낸다(해상도 유지, 품질 90, 방향 반영, GPS 제거, 이름 `.jpg`). PNG·JPEG·WebP는 바이트 그대로. 변환하지 못하면 원본을 보내고 사진 저장의 415에만 "PNG, JPEG, WebP 이미지만 지원합니다."를 보인다. 서버 변경 없음, 0.6.1 대상.

## 구현

- `frontend/lib/data/services/photo_converter.dart`(새): 머리 바이트(ISO BMFF `ftyp`의 major·compatible brand, AVIF 제외)로 HEIF를 판정하고, HEIF만 네이티브 채널 `com.huturu.app/image`의 `heicToJpeg {bytes, quality: 90}`을 부른다. 결과가 없거나 JPEG가 아니거나 채널이 없거나 오류면 원본 바이트·이름을 그대로 쓴다.
- `save_content_screen.dart`: 사진을 고를 때 한 번 변환해 미리보기·저장·같은 화면 재시도(같은 제출 키)에 같은 바이트를 쓴다. 변환 중 다시 고르면 앞 선택이 늦게 덮지 않는다.
- `clipback_api.dart` `uploadScreenshot`: 415만 위 한국어 안내로 바꾼다. 다른 상태 코드와 링크 저장 문구는 그대로다.
- iOS `AppDelegate.swift` `HeicJpegConverter`: ImageIO에서 원본 최대 변 크기의 변환(`CreateThumbnailWithTransform`)으로 방향을 픽셀에 반영하고 해상도를 유지하며, 새 JPEG에는 품질만 써서 원본 메타데이터(GPS 포함)를 남기지 않는다.
- Android `image/HeicJpegConverter.java`(+ `MainActivity` 등록): API 28 미만은 null(원본 전송), 그 밖은 `ImageDecoder` → `Bitmap.compress(JPEG, 90)`(EXIF 없음).
- 새 패키지는 없다(라이선스·앱 크기 영향 없음). 문서: 이미지 보관 정책의 보관본 예외, `frontend/README.md`, `docs/frontend/behavior.md` 사진 형식, `CHANGELOG.md` 미배포.

## 테스트

- 새 `frontend/test/heic_photo_test.dart`: HEIF 판정 11건, `.jpg` 이름 5건, 변환 요청·실패 4종·PNG/JPEG/WebP 미변환, 415·413·5xx·링크 415 문구, 앱 테마 병합 기준 안내 넘침(320pt, 1.0·1.3배 각각).
- `frontend/test/screenshot_auth_test.dart`(이슈 허용 칸: 가짜 선택기에 HEIC 선택지 추가, 새 테스트 추가): HEIC가 `.jpg` JPEG로 한 번 변환되고 503 뒤 재시도가 같은 바이트·제출 키를 보냄, 변환기 null·미지원·오류 때 원본 HEIC 전송과 한국어 415 안내, 415 안내 320pt 1.0·1.3배. 기존 PNG 단언과 다른 가짜 선택기 파일은 바꾸지 않았다.
- 재현: `6e2681f` 코드에서 위젯 테스트 5건이 HEIC 원본 전송·영어 안내로 실패했고, 구현 뒤 통과했다.
- 저장 실패 안내의 글꼴은 이 작업 전부터 Pretendard가 아닌 플랫폼 글꼴이며, 별도 이슈로 조사한다.

## 검증

- 최종 전체 검증(main 병합 `53ab539`, tracked clean): `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 테스트 3698건 통과. 백엔드 pytest 2667 passed, 49 skipped. skip은 `tests/deployment` 48건(`RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are …` 외 6종)과 `tests/integration` 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…`)이다. 이 작업은 백엔드를 바꾸지 않았고, 병합으로 들어온 main의 백업 seed 검사가 pytest 수에 더해졌다.
- 병합 전 `9db9e3d`의 전체 검증(앱 3698건, pytest 2661 passed·49 skipped, 같은 skip)은 그 커밋의 기록으로 남긴다.
- 부분 검사: Android `compileDebugJavaWithJavac`, iOS 시뮬레이터 debug 빌드 성공.
- 참고(기기 결과 아님): iOS 변환 함수와 같은 코드를 macOS ImageIO로 실기기 HEIC 두 장(1200만 화소, 세로 촬영, 위치 정보 있음)에 돌린 결과 3.28MiB·3.80MiB, JPEG 3024×4032로 세워짐, 방향 태그 없음, 위치 정보 없음, 해상도 유지였다.
- 변경 전 화면(`6e2681f`, iOS 18.6 iPhone 16, 로컬 대역, 실제 사진 선택기): HEIC는 원본 그대로 전송돼 415 영어 안내, PNG는 원본 해시 그대로 저장, 강제 415는 배율 1.0·1.3에서 영어 안내. Android 16 `Medium_Phone`은 설치·해시 확인 뒤 System UI 응답 없음과 에뮬레이터 종료로 촬영하지 못했다(기준 커밋 촬영 실패, 승인 예외로 기록).
- 촬영 관측 도구 보완: 리뷰에서 안내 줄 수 계측이 문구가 아니라 앞의 오류 아이콘을 재는 것이 드러나 고쳤다. 이어 라틴·한글 글꼴이 섞이면 줄 수를 더 세는 문제도 고쳤다. 그래서 이전 촬영 기록의 안내 줄 수·잘림 값은 쓰지 않는다(문구·위치·겹침 값은 유효).

### 변경 후 양 플랫폼 실행

- iPhone 16 / iOS 18.6 Simulator, `Medium_Phone` / Android 16(API 36) Emulator에서 실제 사진 선택기로 같은 HEIC 두 장과 PNG를 첨부·저장했다(로컬 대역). HEIC는 각각 네이티브 변환 1회 뒤 JPEG 저장 성공, PNG는 변환 호출 없이 선택·미리보기·전송 해시가 같고 저장 성공이었다.
- JPEG 두 장은 양쪽 모두 3024×4032, GPS 없음, EXIF 방향 태그 없음이었다. 원본 4032×3024의 해상도를 유지하며 세로 방향을 픽셀에 반영했고 화면에서도 글자가 바로 섰다.
- iOS·Android 변환 실패 대역에서는 실제 선택한 HEIC를 그대로 전송하고 415 한국어 안내를 확인했다. 1.0·1.3배 안내를 계측 수정 뒤 다시 촬영해 각각 1줄·2줄이며 잘림·저장 버튼 겹침이 없었다. 이전 계측값을 수정한 것이 아니라 새 기록으로 확인했다.
- 비교 조건: iOS 논리 393×852, OS 안전 영역 위 59·아래 34; Android 논리 411.43×914.29, 위·아래 24, 두 플랫폼 스크롤 0. 해당 오류 상태의 Figma 기준 화면이 없어 확정된 문구와 줄 수·잘림·겹침을 확인했으며 Figma 일치는 판정하지 않았다.

| 실행 환경 | IMG_0004 JPEG | IMG_0005 JPEG |
| --- | ---: | ---: |
| iOS Simulator | 3,690,257바이트 (3.52MiB) | 4,266,901바이트 (4.07MiB) |
| Android Emulator | 2,254,847바이트 (2.15MiB) | 2,616,036바이트 (2.49MiB) |
| iPhone 13 실기기 | 3,438,747바이트 (3.28MiB) | 3,986,295바이트 (3.80MiB) |

### 실기기(사용자 확인)

- 2026-11-15, iPhone 13에서 `5ea3a31`의 개발 빌드와 Mac 로컬 대역으로 실행했다. 실제 기기 조회 OS는 **iOS 27.2(24B119)**이며 최초 계획의 iOS 26.1과 구분한다. 개발 빌드 기본 표시는 0.1.0(1), 0.6.1 배포 빌드의 검증은 아니다.
- 사용자가 IMG_0004·IMG_0005·스크린샷 PNG를 차례로 첨부·저장한 뒤 **“모두 성공, 정상”**이라고 확인했다. 기록은 **세 장 모두 성공·정상**이며 항목별로 따로 답한 것으로 확대하지 않는다.
- 수신 검사: 선택기의 HEIC 두 파일은 지정 원본과 바이트·해시가 같았다. 수신 파일은 각각 JPEG 머리 `FF D8 FF`, `.jpg` 이름, GPS 없음, 3024×4032로 방향 반영·해상도 유지였다. 크기는 위 표와 같다.
- PNG는 기기 선택기의 보관 파일과 수신 파일을 직접 대조해 4,076,630바이트·SHA-256이 일치했다(1170×2532, PNG). 형식 확인만으로 원본 보존을 추정하지 않았다.
- 최초 설치는 기기 잠금으로 실패했고, 사용자의 잠금 해제 뒤 같은 빌드로 설치·실행했다. 앱·대역 서버를 종료하고 TestFlight 재설치가 필요하다고 안내를 전달했다. 재설치 완료 여부는 아직 확인받지 않았다.

### 증거 위치와 공개 범위

- 플랫폼별 안내 비교 한 장씩: `.utmp/ticket-380/recheck-max/compare-ios.png`, `.utmp/ticket-380/recheck-max/compare-android.png`. Android 변경 전은 승인된 촬영 실패 사유를 표시하고 변경 후 원본만 넣었으며 이전 화면을 만들어 대신하지 않았다. Figma 기준이 없는 사실도 표시했다.
- 상태별 원본·계측: `.utmp/ticket-380/screens/`, 수정 후 안내·Android 변환 실패: `.utmp/ticket-380/recheck-max/screens/`. 시뮬레이터·에뮬레이터 수신 검사: `.utmp/ticket-380/uploads/`.
- 실기기 수신 검사·선택 원본 대조·사용자 확인: `.utmp/ticket-380/physical/result.json`, `inspect-001.json`, `inspect-002.json`, `inspect-003.json`, `heic-input-comparison.json`, `png-byte-comparison.json`.
- 사진이 포함된 화면과 수신 파일은 로컬 증거로만 보관하며 저장소·PR·이슈에 올리지 않는다. PR에는 합성 PNG로 확인한 안내 비교 이미지 두 장만 첨부한다. 별도 동영상은 촬영하지 않았다.

## 미검증·한계

- Android 8 이하(API 24–27)는 자동 테스트의 변환 실패 대역으로만 확인했으며 에뮬레이터 실행은 미검증이다(사용자 결정).
- Android 기준 커밋의 화면은 촬영 실패로 미확보이며 변경 전·후 시각 비교는 불가능하다. 해당 오류 상태의 Figma 기준도 없다.
- 운영 서버·실제 모델·배포 빌드 검증은 하지 않았다. 원격 CI는 push·PR 승인 후 확인한다. 위 전체 검사에서 건너뛴 deployment·S3 통합 검사도 로컬 미검증으로 남긴다.
