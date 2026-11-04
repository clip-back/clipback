# Weekly 카드 문구·이름 색 결정 (2026-11-04)

관련 이슈: [#231](https://github.com/clip-back/clipback/issues/231). 구현 시작 커밋은 `8202d4fe1bc6226eea7ccf59fc305626daa4d758`이다. 현재 기준은 [Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md#figma-current-11)에서 관리한다.

## 사용자 결정

- “44 : 콘텐츠 -> 카테고리 문구 변경”, “둘 다 바꾸기로 해줘”: `mostSaved`·`rediscovery` 본문을 “[이름] 카테고리를 다시 볼까요?”로 바꾼다. `mostViewed`의 “내가 관심 있던 [이름]”과 세 유형의 상단 라벨을 유지한다.
- “응 진행해줘”: 2026-11-04 디자인 담당의 “카테고리 이름 빨강 강조는 맞지 않고 다른 본문 글씨와 같은 검정이 맞는 디자인” 확인을 반영하여 세 유형의 이름 색을 본문과 같은 `AppColors.text`(`#1A1A1A`)로 통일한다.
- 본문 전체의 기존 Pretendard 16px·굵기 600·행간 1.5·자간 -0.4와 이름에 별도 강조가 없는 상태를 유지한다. 카드 폭 133px·본문 가용 폭 96px·두 줄 말줄임·배율에 따른 rail 높이 증가와 같은 카테고리 ID의 목록 이동도 유지한다.

## Figma 원본과 승인 차이

감독이 C01 `111:3584`(파일 `svNWsTFh8Ws1Mpt8XQIcrN`)을 2026-11-04 20:15 KST에 조회하여 `.utmp/ticket-231/figma-context.txt`와 `figma-c01.png`에 확보했다. 이름은 여전히 빨강이며 본문은 “콘텐츠” 문구·Pretendard SemiBold 17px다. C01에는 `rediscovery` 예제가 없고 세 번째 카드는 과거 공지이므로 이를 재발견 근거로 사용하지 않는다.

이번 사용자 승인은 원본과 다른 문구·이름 색을 적용한다. 원본의 17px와 앱의 기존 16px 차이는 이번 범위에서 바꾸지 않는다. [이전 Weekly 승인 이력](2026-10-21-weekly-frontend.md)의 빨강 유지 기준은 이번 결정으로 대체하며 과거 기록을 소급 수정하지 않는다.

디자인 담당에게 Figma 원본 색 수정 요청을 전달하는 주체는 사용자다. 요청 전달·반영 확인은 아직 없고, 작업자는 원본을 편집하거나 담당자에게 메시지를 보내지 않았다. 자동 테스트 결과와 사용자의 시각 판정은 구분하며 최종 화면 확인 전에는 화면 완료로 간주하지 않는다.

## 자동 검증·검수 (2026-11-04)

제품·테스트 근거 SHA는 `e5bf1df710f2c9559983f2dabbadd1bc9116f91d`다. 검수 대상은 시작 커밋 `8202d4fe1bc6226eea7ccf59fc305626daa4d758`부터 위 SHA까지이며, `.utmp/review-231.md`에서 Standards 높음·중간·낮음 각 0건, Spec 높음·중간·낮음 각 0건을 확인했다. 제품 수정 없이 다음 전체 검증을 한 번 실행했다.

작업 디렉터리는 `/Users/leehyeongyu/orca/workspaces/Clipback/weekly-pick-wording`이다. `busy.sh --wait` 종료 뒤 `busy.sh && 명령`으로 겹침을 방지했고, Python subprocess의 `wait(timeout=600)`과 초과 시 프로세스 그룹 종료로 실제 600초 제한을 적용했다.

```sh
python3 ~/.heoturu-agents/verify.py --log-dir .utmp/weekly-pick-wording-verify
```

전체 검사 10개가 통과했다. 백엔드 ruff·compileall, test/maintenance DB 각각의 Alembic upgrade/check, pytest, 앱 pub get·analyze·전체 test가 포함된다. 최종 결과 원문은 다음과 같다.

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/weekly-pick-wording/.utmp/weekly-pick-wording-verify
2047 passed, 46 skipped, 3 warnings in 188.29s (0:03:08)
03:12 +2340: All tests passed!
```

백엔드 **2047개 통과·46개 skip·경고 3건**, Flutter **2340개 통과**다. 경고 3건은 migration 테스트의 Alembic `path_separator` 설정 관련 DeprecationWarning이다. skip 사유별 수는 `backend-pytest.log`의 `SKIPPED` 요약을 합산했으며 사유 원문은 아래와 같다.

| 건수 | skip 사유 원문 |
| --- | --- |
| 18 | `RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required` |
| 12 | `Requires Docker and a built CLIPBACK_LEDGER_OPERATOR_IMAGE` |
| 2 | `Requires built API/operator images from the same identified revision` |
| 8 | `RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required` |
| 1 | `Opt-in real Docker/PG18 and built images required` |
| 3 | `RUN_DOCKER_RECOVERY_TESTS=1 and built operator image required` |
| 1 | `RUN_DOCKER_RECOVERY_TESTS=1 and labelled local images are required` |
| 1 | `CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local synthetic CLI test` |

Docker deployment 45건과 로컬 synthetic S3 CLI integration 1건은 미검증이다. 통과 개수에 포함하지 않았으며 원격 CI·운영 서버·실기기 검증으로 간주하지 않는다.

### 변경부와 선실패 근거

| 로그 (`.utmp/ticket-231/`) | 실제 결과 |
| --- | --- |
| `red-color-wording.log` | 제품 수정 전 세 유형의 유효 이름 색 3건과 mostSaved·rediscovery 전체 본문 2건이 실패, mostViewed 기존 본문 1건 통과 |
| `green-color-wording.log` | 최소 제품 수정 뒤 동일 색·본문 검사 6건 통과 |
| `partial-changed.log` | `flutter test --no-pub --reporter expanded test/weekly_visibility_test.dart test/weekly_root_test.dart test/home_alignment_test.dart`: 278건 통과 |
| `partial-analyze.log` | `flutter analyze --no-pub`: No issues found |
| `format.log` | `dart format --output=none --set-exit-if-changed lib test`: 281 files, 0 changed |

위 변경부 검사에는 실제 Pretendard Medium·SemiBold, 플랫폼 2 × 폭 2 × 유형 3 × 입력 4 × 배율 3의 144개 독립 배치 검사와 세 유형 실제 카드 탭→같은 카테고리 ID 목록 이동 검사가 포함된다. 검수자는 `.utmp/review-231-layout.log`에서 144개 레이아웃 조합을 별도로 실행해 통과했고, `.utmp/review-231.md`에서 상속 색·본문·굵기·말줄임·목적지와 로그를 대조했다. 검수 지적이 없으므로 반영을 위한 제품 수정은 없다.

전체 근거는 `.utmp/weekly-pick-wording-verify/verify-result.txt`, `backend-pytest.log`, `app-test.log` 및 같은 폴더의 검사별 로그다. 제한·실행 명령과 단계별 출력은 `.utmp/ticket-231/full-verify-console.log`에 보존했다. 이번 후속 커밋은 CHANGELOG와 이 문서만 바꾸므로 제품·테스트는 위 VERIFY PASS SHA와 같다.

## 최종 화면 검증 (2026-11-04)

제품·테스트는 전체 VERIFY PASS 기준 `e5bf1df`와 같다. 문서 커밋 `665166c` 상태에서 촬영했으며, 변경 후 빌드 전 루트 앱 preflight 9건도 통과했다(`.utmp/ticket-231/capture-preflight-after.log`). 변경 전은 시작 커밋 `8202d4f`에서 제품 수정 전에 확보했다. 전체 검증 뒤 20:58–21:09 KST에 iOS·Android를 순서대로 빌드·설치·촬영했고 최종 기기는 모두 종료했다.

| 플랫폼 | 기기·OS | 논리 화면 | OS 안전 영역 위/아래 | 원본 PNG |
| --- | --- | --- | --- | --- |
| iOS | iPhone 16 / iOS 18.6 Simulator | 393×852 | 59 / 34 | 1179×2556 |
| Android | Medium_Phone / Android 16 API 36 Emulator | 411.428571×914.285714 | 24 / 24 | 1080×2400 |

두 플랫폼 모두 유형 3개 × 이름 3개(장소·한글 `가` 40자·영문 `W` 40자) × 배율 1.0·1.15·1.3의 27개 상태와 유형별 목적지 3개를 변경 전·후에 촬영했다. 루트 ClipbackApp의 대역 API/메모리 세션에서 카테고리 ID 101을 사용했고 홈 스크롤은 0이다. 배율은 앱 안 주입이며 OS 글자 설정 변경이 아니다. 상태별 PNG와 JSON은 `.utmp/ticket-231/screens/`에 보존한다.

- `capture_matrix.py`와 `audit_capture.py`: 두 플랫폼의 전후 데이터·유형·이름·배율·스크롤·논리 크기·OS 안전 영역이 일치했다. 각 27개 상태의 전체 본문, 이름 유효색, 공통 굵기600, 두 줄 ellipsis, 40자 이름의 실제 말줄임, 예상 밖 API/Flutter 오류 없음을 확인했다. 결과는 `capture-audit.log`에 있다.
- `audit_pixels.py`: 변경 전 원본 SHA256 보존 및 전후 본문 영역 108곳의 실제 픽셀을 검사했다. 변경 전 모두 빨강이 존재하고 변경 후 모두 빨강이 사라졌다(`pixel-audit.log`). 이 검사는 텍스트 범위의 색 확인이며 전체 화면 시각 승인으로 간주하지 않는다.
- `capture_navigation.py`: 두 플랫폼의 각 세 유형을 실제 Orca 접근성 요소로 찾아 OS 탭했다. 모두 변경 전과 같은 ID 101/장소 목록으로 이동했다. `navigation-ios-after.log`, `navigation-android-after.log`와 상태별 접근성 JSON/목적지 PNG에 남겼다.
- 대표 짧은 이름 1배율의 세 유형과 40자 이름 확대 비교를 이미지로 직접 확인했다. `mostViewed`는 본문을 유지하며 이름색만 바뀌었고, 다른 두 유형은 본문과 이름색이 함께 바뀌었다. 짧은 이름 1배율은 “장소 카테고리 / 를 다시 볼까요?”로 줄이 나뉜다. 이는 승인된 133px 폭·두 줄 정책을 유지한 결과이며 임의로 폭·글꼴·줄 수를 조정하지 않았다.
- iOS kernel SHA1 prefix는 변경 전 `1c71322e58d8`, 후 `9caf46f3d0de`; Android APK SHA256 prefix는 전 `470061fd8a98`, 후 `9760aef5ff37`로 서로 다르다. 공용 설치 스크립트가 설치본과 빌드 산출물의 해시 일치를 확인했다. Android 빌드 뒤 Gradle 데몬 종료를 확인했다. 추적 빌드 부작용은 없었다.
- Android 최종 부팅 직후 `com.android.systemui` 응답 없음 창이 나타나 공용 촬영 스크립트가 Wait 버튼으로 닫았다. 앱 전면·설치본·ready 확인을 통과한 뒤 촬영했으며 제품 변경으로 다루지 않았다.

### 전후·Figma 비교

공용 `compare.py`로 플랫폼별 3열 요약과 유형·이름별 배율 3행 비교를 만들었다. 각 행은 **변경 전 · 변경 후 · Figma C01** 순서이며 조건 불일치 없이 생성됐다. 목록은 `.utmp/ticket-231-screens/README.md`, 대표 이미지는 `compare-ios.png`·`compare-android.png`, 미리보기는 각각 `-preview.png`다. 목적지 비교는 F01 원본을 이번에 조회한 것으로 가장하지 않고 전후 2열로만 남겼다.

Figma C01 원본은 375×936 정적 프레임이고 앱은 위 표의 실제 기기 크기·OS 안전 영역을 사용한다. 이 차이를 이미지에 표기했으며 원본을 잘라 맞추거나 안전 영역을 보정하지 않았다. Figma의 빨강 이름·“콘텐츠”·17px와 구현의 본문색·승인 문구·기존16px 차이를 명시했다. C01에는 재발견 예제가 없으므로 해당 행의 C01은 공통 구조 참고이며 과거 공지 카드를 재발견 기준으로 사용하지 않았다.

자동 검증과 감독의 촬영·동작 확인은 완료했다. **사용자 시각 판정은 대기 중**이며 Figma 원본 색 수정 요청 전달·반영 확인도 미확인(사용자 담당)이다. 이슈는 열어 두고 PR 초안에서 멈춘다. 로컬 대역 API·시뮬레이터·에뮬레이터 결과를 운영 추천 품질·실기기·원격 CI 증거로 간주하지 않는다. 이번 변경의 핵심은 정적 문구·색이므로 비교 영상은 만들지 않았다.
