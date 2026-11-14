# 저장 화면에서 첨부한 HEIC 사진을 JPEG로 바꿔 저장하고 형식 거절 안내를 한국어로 (#380)

2026-11-14–15, 브랜치 `fix/heic-to-jpeg`. 시작 커밋 `6e2681f`, 구현 커밋 `9db9e3d`(최종 전체 검증 기준). 이후 커밋은 이 문서만 바꾼다.
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
- 안내 글꼴: 앱 테마 병합에서 `SaveErrorToast` 문구는 Pretendard가 아니라 플랫폼 글꼴을 받는다. 위젯 테스트 하네스(`_withApp`)는 바깥을 Pretendard 테마로 감싸므로, 병합 테마 기준 넘침 시험을 따로 두었다(테스트에 플랫폼 글꼴이 없어 네모 테스트 글꼴로 잼).

## 검증

- 최종 전체 검증(`9db9e3d`, tracked clean): `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 테스트 3698건 통과. 백엔드 pytest 2661 passed, 49 skipped. skip은 `tests/deployment` 48건(`RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are …` 외 6종)과 `tests/integration` 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…`)이다. 백엔드는 바꾸지 않았다.
- 부분 검사: Android `compileDebugJavaWithJavac`, iOS 시뮬레이터 debug 빌드 성공.
- 참고(기기 결과 아님): iOS 변환 함수와 같은 코드를 macOS ImageIO로 실기기 HEIC 두 장(1200만 화소, 세로 촬영, 위치 정보 있음)에 돌린 결과 3.28MiB·3.80MiB, JPEG 3024×4032로 세워짐, 방향 태그 없음, 위치 정보 없음, 해상도 유지였다.
- 변경 전 화면(`6e2681f`, iOS 18.6 iPhone 16, 로컬 대역, 실제 사진 선택기): HEIC는 원본 그대로 전송돼 415 영어 안내, PNG는 원본 해시 그대로 저장, 강제 415는 배율 1.0·1.3에서 영어 안내. Android 16 `Medium_Phone`은 설치·해시 확인 뒤 System UI 응답 없음과 에뮬레이터 종료로 촬영하지 못했다(기준 커밋 촬영 실패, 승인 예외로 기록).
- 촬영 관측 도구 보완: 리뷰에서 안내 줄 수 계측이 문구가 아니라 앞의 오류 아이콘을 재는 것이 드러나 고쳤다. 그래서 변경 전 iOS 촬영 기록의 안내 줄 수·잘림 값은 쓰지 않는다(문구·위치·겹침 값은 유효).

## 미검증

- 변경 후 iOS Simulator·Android Emulator 화면과 네이티브 변환 결과(크기·방향·GPS·해상도), 실기기 iPhone 13(iOS 26.1) 사람 확인은 아직 하지 않았다. 감독이 이후 단계에서 진행한다.
- Android 8 이하(API 24–27)는 자동 테스트의 변환 실패 대역으로만 확인하며 기기 실행은 하지 않는다(사용자 결정).
- Android 변환의 방향 반영은 플랫폼 디코더에 맡겼으므로 기기에서 확인해야 한다.
