# 공유 저장 처리 중 표시 (#245)

## 범위와 기준

2026-11-06 기록. 첫 구현 커밋은 `bcf9bf2`, 첫 main 반영은 `e847f27`이다. 게시 직전 main의
#248·#249를 `1f6b7b3`으로 추가 병합하고 전체 검증을 다시 통과했다. 추가 병합은 네이티브 공유 코드·
공유 대역·촬영 진입 파일을 바꾸지 않았으며, 아래 촬영 빌드와 해당 코드는 같다.

Figma `348:3390`(2026-11-06 조회)을 iOS Share Extension·Android ShareActivity의 저장 버튼 탭 이후에 적용했다.
처리 중에는 회색 버튼, `전송 중 ...`, 원본 20pt/dp 종이비행기와 10pt/dp 간격,
`저장하고 있어요... 잠시만 기다려주세요 !`를 표시한다. 준비 단계는 기존 버튼 잠금만 유지하고,
실패 알림·동일 키 재시도·닫기·완료 토스트 정책은 유지했다. 저장 완료는 자동 요약 완료를 뜻하지 않는다.
스피너·새 애니메이션·최소 표시 시간·실패 전용 화면은 추가하지 않았다.

## 진단과 리뷰 반영

iOS에서는 요청한 제목 프레임과 UIKit 배치 후 실제 프레임이 달라 제목과 아이콘이 5pt 겹쳤다.
사용자 승인에 따라 `layoutSubviews` 뒤 처리 중 제목·이미지를 직접 배치했고,
실제 프레임의 제목 끝 197pt·아이콘 시작 207pt·아이콘 20×20pt를 두 입력 경로에서 확인했다.
이는 관찰한 배치 차이이며 UIKit 내부 구현 원인까지 증명한 것은 아니다.
높이 제약만 옮기는 앞 실험은 실패하여 채택하지 않았다. 별도 행 구조로 바꾸는 대안은 필요하지 않았다.

기존 복귀 테스트는 시트 소멸 직후 송신 앱이 즉시 입력 가능하다고 가정했다.
500 오류 닫기에서 입력 불가가 약 0.366초 뒤 가능으로 바뀌는 것을 계측했다.
시트 소멸 대기 후 입력 복귀도 최대 5초 기다리도록 하고 기존 최종 단언을 유지했다.
각 대기가 최대 5초이며 helper 전체가 최대 5초라는 뜻은 아니다. 아이콘 matcher·golden·허용치는 변경하지 않았다.

티켓 리뷰는 Standards 중간 1건(S1), Spec 0건이었다. S1은 제품 코드가 아닌 로컬 촬영 도구의
before 경로·커밋 고정 및 기존 산출물 덮어쓰기 가능성이었다. 수정 전 외부 I/O mock으로 쓰기 시도와
원본 불변 단언 실패를 재현했고, phase/출력/빌드 근거/serial을 명시하며 이름·녹화 세션을 배타적으로 예약하도록 고쳤다.
수정 후 mock 9개가 정상 새 출력, 기존 출력 불변, 중복 shot/start/stop, 잘못된 phase/세션,
빌드 근거 변경·APK 불일치 거부를 통과했다. 로컬 `.utmp` 도구·안내는 커밋 대상이 아니며 실제 기기 기능 검증이 아니다.

낮은 확신 항목 판단:

- fixture의 truthiness 해석으로 문자열 `"false"`가 release를 실행하는 것은 mock으로 확인했다.
  현재 caller는 JSON bool을 보내는 내부 시험이고 손상 제어 입력은 계약 밖이므로 이번 제품 범위를 넓혀 수정하지 않았다.
- 전역 release는 순차 대역 시험용이며 병행 요청별 독립 release를 보장하지 않는다. 병행 사용 검증으로 확대하지 않았다.
- staging 부작용이 있는 `check-first-commit.py`는 이번 단계에서 실행하지 않았다.
- matcher 원본 본문과 golden 해시의 동일성은 별도 읽기 전용 비교로 확인했다.
  이전 source 해시와 다른 두 문서(화면 맞춤 계획·frontend README)는 main 반영으로 바뀐 것이며 제품 불일치가 아니다.

## 검증 결과

### 게시 직전 전체 검증 (최종)

clean `1f6b7b3`에서 공용 점유 해소 후 실행했다. 셸 실행 제한은 600초였다.
병합한 Flutter 상태 문구와 소비 테스트를 먼저 대조하고 `flutter analyze --no-pub`가 통과한 뒤 실행했다.

```bash
~/.heoturu-agents/busy.sh --wait
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-245/prepublish
```

```text
VERIFY result=PASS scope=all checks=11 failed=0
backend pytest: 2048 passed, 46 skipped, 3 warnings
Flutter: 3058 passed
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
```

결과 파일과 실제 pytest/Flutter 로그를 대조했다. skip 46건은 통과에 포함하지 않았다.
로그 디렉터리: `.utmp/ticket-245/prepublish/20261106T151042-5c4899f5df7a`.
명령·셸 결과: `.utmp/ticket-245/prepublish/console.log`. 앞 전체 검증 `e847f27`의 로그는
`.utmp/ticket-245/final/20261106T135720-7ab8685a1fc6`에 별도로 보존했다. 최종 결과와 합산하지 않는다.

### 앞 단계 네이티브 검증

아래는 main 합치기 전 구현 코드의 실행 근거이며 이번 전체 VERIFY가 네이티브 UI를 다시 실행한 것은 아니다.

| 환경·범위 | 결과 | `.utmp/ticket-245/` 로그 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6, 신규 처리 중 UI | 3개 통과 | `partial-ios-layout-ready-progress.log` |
| 같은 Simulator, 기존 공유 UI | 15개 통과 | `partial-ios-layout-ready-regression.log` |
| 같은 Simulator, RunnerTests | 25개 통과 | `partial-ios-layout-final-runner.log` |
| Android Medium_Phone / API 36, 신규 처리 중 | 4개 통과 | `partial-android-green-progress.log` |
| 같은 Emulator, 네이티브 3개 클래스 | 69개 통과 | `partial-android-green-regression.log` |

모두 로컬 HTTP 대역 검증이다. 초기 red와 실패한 실험·회귀 로그도 보존했다.
진단은 `.utmp/ticket-245/diagnosis.md`, S1 수정 전·후 mock은 `.utmp/ticket-245/review-fix/`에 있다.

## 첫 전체 검증 뒤 최종 촬영

2026-11-06 감독이 `7f980ec` 빌드를 촬영했다. 제품 코드는 전체 VERIFY 기준 `e847f27`과 같다.
설치된 iOS 확장 binary와 Android APK를 빌드 산출물 해시로 대조했다. 각 플랫폼 블록에서
`device-lock.sh acquire 감독-245 --wait`로 잠금을 잡고, 자체 자원 종료 뒤 해제했다.

| 환경 | 이번 결과 | 원본·실행 근거 (`.utmp/ticket-245/` 아래) |
| --- | --- | --- |
| iPhone16/iOS18.6, 실제 송신 앱·OS 공유 메뉴·Share Extension | 기본 3입력, 재시도 4분류, 빠른 로컬 성공, 닫기/준비/보관복구와 큰 글자 선택검사 총 10개 통과 | `after/ios/README.md`, 각 `attachments/manifest.json`·`flow.mp4`, `partial-ios-final-*.log` |
| Medium_Phone/Android16 API36, native instrumentation | 기본 3입력·재생성·실패/재시도·닫기·계정 변경, 배율/크기 선택검사 총 10개 통과 | `after/android/test-condition-proof.json`, 각 `test.log`·`captures/` |
| 같은 Emulator, 실제 송신 앱·OS 공유 메뉴 | YouTube·Instagram·이미지 추가 탭 뒤 각각 요청 1회/최종 저장 1건, 응답 해제 뒤 복귀 | `after/android/os/request-count-proof.json`, `OS-*-held.mp4`, AX JSON |
| 같은 Emulator, 실제 OS 메뉴 추가 흐름 | 지연 제어 없는 빠른 성공 후 복귀, 뒤로가기 후 늦은 응답에도 시트 재표시 없음 | `after/android/os/OS-fast-return-proof.json`, `OS-close-late-proof.json`·영상 |

이는 main을 합친 빌드의 추가 촬영 검사이며 앞 단계 전체 네이티브 회귀를 모두 다시 실행했다는 뜻은 아니다.
`save_requests`와 `saved`는 로컬 HTTP 대역 수치다. 대역은 저장 건을 등록한 뒤 **응답만 보류**하므로
처리 중에도 서버의 `saved`는 증가할 수 있다. 감독의 임시 보고 검사에서 이를 불변으로 가정한 오류를
fixture 코드와 원본 수치로 확인해 바로잡았으며 제품·네이티브 테스트 기대값을 바꾸지 않았다.

감독은 원본 기반 화면에서 회색 버튼·문구·20pt/dp 아이콘·안내 표시와 실패/재시도 복귀를 확인했다.
Android 일반 1.0/1.1/1.2/1.3 및 짧은 1080×1600의 1.0/1.3에서 세 입력의 문구·아이콘·안내 잘림이
보이지 않았다. iOS는 `large`, `extra-extra-large`, `extra-extra-extra-large` 단계에서 세 입력을 확인했다.
이 iOS OS 단계는 정확한 수치 배율 1.1/1.2/1.3 측정값이 아니다. 뒤 사용자 결정에 따라 이 한계를 기록하고 OS 단계 결과로 대신한다.

변경 전/후/Figma 3열과 영상은 `.utmp/ticket-245-screens/`에 있다.

- `compare-ios.png`, `compare-android-final.png`, `compare-android-short13.png`와 각 `-preview.png`·JSON.
- `compare-ios-flow.mp4`, `compare-android-os-flow.mp4`: 원본 끝 프레임 검사 통과, 감독이 전환·끝 장면 확인.
  탭 시각을 맞춘 속도 비교가 아니며, 보류 응답 영상과 빠른 로컬 응답 영상은 별도로 보존했다.
- Figma `348:3390`, file `svNWsTFh8Ws1Mpt8XQIcrN`, 조회 시각 `2026-11-06T02:14:52+09:00`.
  Figma 원본은 375×813, iOS 원본은 1178×2556, Android 기본은 1080×2400/density 2.625다.
  Android 실제 systemInsetsPx는 `[0,63,0,63]`이며 전후 동일하다. OS 공유 목록/배경·안전영역 차이를
  화면 보정으로 숨기지 않았다. iOS 안전영역 수치와 정확 글자 배율은 미계측이라 모든 비교 조건의
  엄격한 일치를 주장하지 않는다. 기기·OS category·입력 경로 일치는 별도 metadata로 확인했다.
- 실패·준비·재생성의 별도 원본이 없는 상태는 기존 정책의 회귀로 확인했으며 대체 Figma 디자인을 만들지 않았다.
  사용자의 최종 시각 판정은 남아 있다.

촬영 실패도 보존했다. iOS 첫 기본 촬영은 공유 메뉴가 화면에 보이지만 XCTest AX 선택이 실패했고
새 경로의 재실행은 통과했다. Orca helper 종료와 성공의 인과관계는 확정하지 않는다.
Android 첫 기본 촬영은 `System UI isn't responding` 창이 입력을 가로막았다. 원본/AX로 확인 후
`Wait`로 닫고 새 경로에서 통과했다. 이 과정에서 제품 코드나 테스트 단언을 수정하지 않았다.

## 사용자 결정에 따른 한 번 재시도와 남은 확인

사용자 원문 **“알겠어 추천대로 해줘”**에 따라 짧은 화면·계정 변경은 각각 한 번만 재시도하고,
실패는 미검증으로 기록한 뒤 PR을 진행한다. 수치 배율은 OS 단계로 대신하고 실제 접근성은 다음 실기기 빌드에서 확인한다.

1. **iOS 짧은 화면 — 재시도 통과.** 2026-11-06 15:03–15:09, 감독 잠금 아래 iPhone SE 3 / iOS 18.6을
   한 번 부팅하여 bootstatus·SpringBoard·스크린샷 준비를 확인했다. `large`와 `extra-extra-extra-large`에서
   `testCaptureShareLoadingStates`가 각각 1개 통과했다. 세 입력의 저장 전·중·성공, 추가 탭, 송신 앱 복귀를
   촬영했고 문구·아이콘·안내 잘림이 없음을 원본 기반 화면에서 확인했다. 변경 전과 같은 기기·OS 단계·입력 경로이며
   원본은 750×1334다. 첫 SE3 부팅/연결 실패 로그는 보존했다.
   근거: `after/ios/retry-se3-boot/commands.json`, `retry-short-large/`, `retry-short-xxxl/`,
   `retry-short-environment-comparison.json`. 비교는 `ticket-245-screens/compare-ios-short-large-retry.png`와
   `compare-ios-short-xxxl-retry.png`다.
2. **iOS 계정 변경 실화면 — 재시도 뒤에도 미검증.** 같은 기기에서 본앱의 마이 → 계정 관리 → 계정 연결하기를
   한 번 시도했다. 실제 화면·AX에는 로그인 제공자 없이 ‘게스트로 계속 사용’만 보였고, 대역은 user 7/session 11로
   고정돼 있어 저장 중 다른 계정으로 바꾸는 상황을 만들지 못했다. 제품·대역·테스트 기대값을 수정하거나
   RunnerTests 경계 검사를 화면 확인으로 대신하지 않았다. `after/ios/retry-account/result.json`, `link.png`,
   `link.ax.json`에 원인과 화면을 보존했다.
3. **iOS 확장에서 수치 배율을 지정할 방법이 없어 OS 글자 단계로 대신함(한계).** 정확한 1.1·1.2·1.3배를
   강제하거나 측정한 결과가 아니다. native 안전영역 수치 미계측 한계도 유지한다.
4. **실제 VoiceOver·TalkBack — 다음 앱 빌드 실기기에서 사용자 확인 예정.** 일반 AX와 서비스 활성화를
   실제 제스처·음성 안내의 PASS로 세지 않는다. 앞 TalkBack 시도의 임시 설정/권한은 정리했다.

재시도 뒤 OS 글자 단계를 large로 복원하고 자체 helper·fixture를 종료했으며, Simulator Shutdown·부팅 기기 없음과
잠금 반납을 확인했다. 새 제품 변경 없이 `1f6b7b3`의 전체 검증을 마친 뒤 이력과 PR 본문만 갱신한다.
비교 이미지는 사용자가 PR 화면에서 첨부한다. PR의 **병합 전 남은 확인**에 위 결과를 명시하고 `Closes #245`를 유지하며,
병합과 이슈 종료 여부는 사용자가 판단한다. 미검증 항목을 완료로 바꾸지 않았다.

Docker deployment/operator-recovery와 로컬 S3는 위 skip 사유에 해당한다. 원격 CI·실제 Instagram 앱·운영·실기기 결과는
이번 로컬 검증에 포함하지 않는다. 준비 단계·실패 전용 디자인·애니메이션·최소 표시 시간은 기존 결정대로 유지한다.
