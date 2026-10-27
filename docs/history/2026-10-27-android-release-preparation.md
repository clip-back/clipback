# Android 개발자 계정과 배포 준비

## 확인 상태

- 2026-10-27 KST 사용자 확인: Google Play 개발자 계정 등록 완료, 승인 대기.
- Play Console의 승인 결과·계정 유형·추가 인증 완료 여부는 직접 확인하지 않았다.
- Android 배포 후보·빌드 번호는 미확정이다. 이 대화의 배포 작업에서는 Android 배포용 AAB 생성·업로드·테스트 배포를 실행하지 않았다.
- iOS `0.2.0 (6)`의 TestFlight 상태와 구분하며, Android 변경 이력은 [미배포](../../CHANGELOG.md#미배포)에 유지한다.

## 승인 후 진행 순서

1. Play Console 승인 결과와 추가 신원·기기 인증 요구사항을 확인한다.
2. 앱 등록 여부, 패키지명 `com.clipback.frontend`, 기존 업로드 이력과 Android 서명 설정을 확인한다.
3. 포함할 기능 범위에 맞춰 앱 버전·소스 SHA·미사용 Android 빌드 번호를 확정하고 별도 후보 기록을 만든다.
   iOS 빌드 번호 6을 Android에 그대로 적용하지 않는다.
4. Android 검증과 배포용 AAB 생성을 진행하고 실제 버전·서명을 확인한다.
5. 업로드 요청 후 Google Play 내부 테스트에 제출하고, 테스터 참여·설치를 각각 확인한다.

내부 테스트와 정식 출시는 별개다. 새 개인 계정의 정식 출시에는 비공개 테스트 등 별도 요구사항이 있으며,
계정 유형·최신 Play Console 안내에 맞춰 확인한다. 승인 대기 중 자동 업로드·배포 예약은 설정하지 않았다.

## 확인 근거

- 이 대화의 사용자 진술: 계정 등록 완료, 승인 대기.
- [Google Play Console 가입 안내](https://support.google.com/googleplay/android-developer/answer/6112435?hl=ko).
- [신규 개인 개발자 계정 테스트 요구사항](https://support.google.com/googleplay/android-developer/answer/14151465?hl=ko).
- 문서 갱신 작업으로 앱 코드·서명·계정 설정은 변경하지 않았다.
