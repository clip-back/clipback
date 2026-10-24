# 실제 로컬 이미지 저장소 검증

`frontend/test/support/image_storage_live_preview.dart`는 제품 `ClipbackApp`과 실제 HTTP,
기본 SharedPreferences 세션, path_provider 캐시, 네이티브 공유 채널을 사용합니다.
소셜 SDK는 공급자가 없는 대역이며, 일반 사진 선택만 저장소의 합성 PNG를 반환합니다.
서버의 OCR·메타데이터·소셜 검증은 대역입니다. 사용자 화면과 저장 API 응답은 대역으로 만들지 않습니다.
실행 결과는 [2026-10-24 통합 검증](../history/2026-10-24-image-storage-integration.md)에 기록합니다.

## 로컬 서버와 앱

`backend/tests/support/share_live_server.py`는 `CLIPBACK_SHARE_TEST_SERVER=1`과 loopback DB를
필수로 요구합니다. 기본 DB는 `clipback_share_preview`이며 이미지 통합 검증에 한해
`CLIPBACK_IMAGE_TEST_SERVER=1`과 별도 `clipback_image_74_native` DB를 허용합니다.
테스트 DB를 새로 준비하고 최신 migration을 적용합니다. S3·삭제 기록 변수는 각기 다른 로컬 합성
버킷을 지정하며 새 삭제 기록만 초기화합니다. 운영 DB·키·사용자 이미지를 사용하지 않습니다.

백엔드에서 다음을 실행합니다. API 실행 환경에는 백업 자격증명이 없습니다.

```bash
python -m uvicorn tests.support.share_live_server:app \
  --host 127.0.0.1 --port 18766 --no-access-log
```

프론트에서 해당 플랫폼을 순서대로 빌드합니다. iOS Simulator와 Android Emulator를 동시에
빌드하지 않습니다. Android의 `JAVA_HOME`은 호환 JDK 21 이상을 가리켜야 합니다.

```bash
flutter build ios --simulator --debug --no-pub \
  --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18766/api/v1 \
  -t test/support/image_storage_live_preview.dart
flutter build apk --debug --no-pub \
  --dart-define=CLIPBACK_API_BASE_URL=http://10.0.2.2:18766/api/v1 \
  -t test/support/image_storage_live_preview.dart
```

새 앱을 설치한 뒤 실제 게스트 시작·온보딩을 진행합니다. 현재 기기 세션을 보존하려면 재시작
검증 사이에 앱을 제거하거나 데이터를 초기화하지 않습니다. 로컬 S3 서명 URL이 127.0.0.1:55465라면
Android에서 `adb reverse tcp:55465 tcp:55465`를 설정합니다. 서명 뒤 URL host를 바꾸면 안 됩니다.

## 동작 관찰

검증 진입점만 기기 loopback 8767에 관찰 서버를 엽니다. Android는
`adb forward tcp:8768 tcp:8767` 후 호스트 8768에서 접근합니다.

| 경로 | 실행하는 실제 동작 |
| --- | --- |
| `/state` | 현재 계정 ID·화면·원본 캐시 수/크기/SHA·요청 집계·토큰 제거된 native state 조회 |
| `/login` | 기존 게스트 시작·온보딩·관심사 완료 콜백 |
| `/save` | 기존 추가 버튼 → 사진 선택 → 저장 버튼 |
| `/home`, `/original`, `/close-sheet` | 기존 홈·상세·원본 모달 이동 |
| `/logout` | 기존 계정 관리 → 로그아웃 확인 → 실제 API 로그아웃 |
| `/old-access` | 현재 실제 세션으로 이전 계정 자산의 access API 요청 |

HTTP 관찰 클라이언트는 IOClient로 요청·응답을 그대로 전달하고 method·route·status·본문 바이트
수만 기록합니다. Bucket 요청의 Authorization/Cookie 부재를 확인하며 로그인 토큰·본문·서명 URL
query를 내보내지 않습니다. 네이티브 요청은 Dart 클라이언트를 통하지 않으므로 서버의 합계와 실제
DB/S3 바이트를 함께 대조합니다. `/__test/state`는 서버 대역의 OCR 호출 수와 API 경로 템플릿별
응답 수만 반환합니다.

원본 첫 조회·재진입마다 access 요청을 확인합니다. 실제 OS 프로세스를 종료·재실행한 뒤 같은
계정 ID가 복원되고 access는 다시 호출되며 Bucket 본문은 캐시에서 재사용되는지 확인합니다.
기존 로그아웃 UI 완료 뒤 캐시 0개, 다음 게스트의 다른 사용자 ID, 이전 자산의 404를 확인합니다.
완전한 오프라인 열람이나 세션을 잃은 게스트의 복구 검증으로 해석하지 않습니다.

iOS 시스템 공유는 [ShareVerification](../../frontend/ios/ShareVerification/README.md)의
`testRealBackendNativeImageWithExistingSession`을 선택합니다. 실제 로그인 완료 뒤 실행하며
18765 fixture 제어를 호출하지 않습니다. Android는 [공유 검증 안내](../../frontend/android/SHARE_TESTING.md)의
테스트 송신 앱에서 실제 이미지 URI를 공유합니다. 이 실제 계정 흐름 사이에 자격증명을 초기화하는
기존 18765 fixture suite를 실행하지 않습니다.

일반 선택 이미지, iOS 송신 PNG, Android 송신 PNG는 서로 다른 자료입니다. 각 원본을 별도로
해시 대조합니다. 화면 PNG·필요한 동영상은 OS 원본 그대로 보관하며 정확한 Figma가 없는 오류·
원본 모달은 비교 자료 누락을 표시합니다. 로컬 실행을 실제 Railway·OAuth·실기기 증거로 보고하지 않습니다.
