# Android 플러그인 빌드 호환성

- 최초 기록일: 2026-10-08
- 영역: Android
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-cf5644295fa89881"></a>

2026-10-08 검증 환경은 Flutter 3.44.9 / Dart 3.12.2, AGP 9.0.1 / Gradle 9.1.0입니다.
수정 전 `:file_picker:checkDebugAarMetadata` 실패를 재현하고 수정 후 통과를 확인했습니다.
`flutter build apk --debug --no-pub`, `flutter analyze --no-pub`, `flutter test --no-pub`의
기존 테스트 400개가 통과했습니다. `flutter run --debug --no-pub --no-resident`로
연결된 SM-S938N(Android 16)에 설치·실행하고 홈의 빈 콘텐츠 화면을 확인했습니다.
사진 선택·업로드, 다른 앱에서 공유받기와 Release 빌드는 이번 검증에 포함하지 않습니다.
