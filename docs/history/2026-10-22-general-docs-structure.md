# 일반 문서 구조 정리와 보존 검증

최초 기록일: 2026-10-22 (KST). README 진입 안내와 상세 설명의 기준 위치를 정리한 문서 작업입니다.

## 기준과 변경 범위

- 기준 커밋: `5d5d33154dea06791aba047aec7e2062016ca969`. 원본은 저장소 루트에서 `git show 5d5d33154dea06791aba047aec7e2062016ca969:원본경로`로 확인합니다.
- 프론트·백엔드 README를 준비 → 실행 → 기본 검증 → 구조 → 상세 안내 순서로 정리했습니다.
- 프론트 동작·개발 검증, 백엔드 API·테스트의 네 문서를 추가했습니다. MVP·추천의 상세 API와 클라이언트 설명은 담당 문서로 옮겼습니다.
- 원문 영어·명령·JSON·수치·오류·재시도·검증 한계를 보존했습니다. 문서 참조의 표시명·상대 경로와 원문의 모호한 안내는 아래 대조표에 따라 갱신했습니다.
- 이 작업의 사용자 변경 이력은 제외합니다. 사용자 동작·공개 API·앱 코드·설정·버전·CI 변경이 없는 문서 구조 정리입니다.
- 기존 작업 이력과 이전 `migration-map.json`, 로컬 AGENTS 및 편집기 임시 파일을 유지했습니다. 미디어 이동·증거 생성·외부 업로드는 하지 않았습니다.

## 절별 이동·유지 대조표

행 범위는 위 기준 커밋의 원본입니다. 고유 본문과 코드 블록은 별도 임시 검사로 대조하며, 동일·유사 설명을 의미만으로 합치지 않았습니다. 아래 SHA-256은 원본 구간의 양끝 개행을 제외한 UTF-8 해시입니다.

| 원본 파일·행 | 처리 | 현재 위치 | 원문 SHA-256 |
| --- | --- | --- | --- |
| `frontend/README.md:50–90` | 이동 | [docs/frontend/behavior.md](../frontend/behavior.md#초기-세션-복원과-재시도) | `12a2270621f561efa4d017836a88190146dab2164a662149fdfe135066258c1c` |
| `frontend/README.md:167–288` | 이동 | [docs/frontend/behavior.md](../frontend/behavior.md#갱신-토큰-저장) | `fba8c03ca7acae42a3b7f4706cf8fe209f34ccecd22b16f9a1061d852f7d7288` |
| `frontend/README.md:323–335` | 이동 | [docs/frontend/behavior.md](../frontend/behavior.md#상단-안전-영역과-헤더) | `aea7afcfc581b0253651f85b997a45d478868e8fca7aac6ded1dd66938033dc0` |
| `frontend/README.md:454–503` | 이동 | [docs/frontend/behavior.md](../frontend/behavior.md#backend-integration-boundaries) | `dfc0ac0c0b0ca45db9d42740b6e8c6ca520f6a73a5d96db6cff40d0fbcd0da83` |
| `docs/content-recommendation-plan.md:312–320` | 이동 | [docs/frontend/behavior.md](../frontend/behavior.md#추천-프론트-연결-계약) | `11705739c208b0ffbb68f3c328b0413da17b7ce0efe349533fc672acc4d41d87` |
| `frontend/README.md:91–166` | 이동 | [docs/frontend/development.md](../frontend/development.md#공개-앱-설정) | `eae982514bc386d4fad517eb7cd9e10bf4be86ed9c526f336877f9c39b75b5e5` |
| `frontend/README.md:309–322` | 이동 | [docs/frontend/development.md](../frontend/development.md#실행과-검증) | `ae9fa333746f207580261bce843316edd074fc1073d8ae45ed7264ea37d7e08b` |
| `frontend/README.md:336–453` | 이동 | [docs/frontend/development.md](../frontend/development.md#안전-영역-검증-도구) | `45a37b93a5a86442697699070b0c72a6cd5a809a5a1cdab94f6aab4b2b2f646f` |
| `frontend/README.md:504–554` | 이동 | [docs/frontend/development.md](../frontend/development.md#플랫폼-설정) | `f266a349cc923345d3b346e0792bf7aae86bfd69e1e23139d16ee678ea2c1012` |
| `backend/README.md:12–26` | 이동 | [docs/backend/api-contracts.md](../backend/api-contracts.md#mvp-scope) | `c34025b49c81a652b2786db49c055d0865c9e95615ae1bd9ddcb18e3dfefde5b` |
| `docs/backend-mvp-plan.md:58–96` | 이동 | [docs/backend/api-contracts.md](../backend/api-contracts.md#4-api-구현-목록) | `79ce358400c3eb03c860cfdf7bdeedf274770be6a727b50be5ef406f65b4c7a6` |
| `backend/README.md:95–731` | 이동 | [docs/backend/api-contracts.md](../backend/api-contracts.md#guest-authentication) | `ad4267151a480183279747778e9379b37ee09a02cdc33623645b9e6fb64b0059` |
| `docs/content-recommendation-plan.md:260–311` | 이동 | [docs/backend/api-contracts.md](../backend/api-contracts.md#9-api프론트-연결-계약) | `182ba1273c9e27b1455fe40d520d1b73b09de3729eb757c6b7b3fc0fc0e3afba` |
| `backend/README.md:69–94` | 이동 | [docs/backend/testing.md](../backend/testing.md#validation) | `64d7d1360e6884450fcaa70cd5986482fb6a6ef4bf58ad90aca0228434c05157` |
| `backend/README.md:747–814` | 이동 | [docs/backend/testing.md](../backend/testing.md#mvp-api-integration-tests) | `7207536ffae0f660d3a7bbd76de9513d68af44e7f044690d825160c8beeebc9c` |
| `frontend/README.md:291–308` | 유지·실행/검증 분리 | [frontend/README.md](../../frontend/README.md#빠른-실행) | `3cf9b3971869ce6b80c1a09b7396658af13ab4d5db81256084a9818b976b0ba0` |
| `frontend/README.md:1–7` | 유지 | [frontend/README.md](../../frontend/README.md#clipback-frontend) | `26404f3c02d2a31d9f7496273e3a3ab0295de3228443d93314112fa9a626486d` |
| `frontend/README.md:8–49` | 유지 | [frontend/README.md](../../frontend/README.md#코드-구조와-의존-방향) | `30b6905932a9ea272bb928a189c555a59df36cd594ae9ac7f81b31c254460272` |
| `frontend/README.md:555–561` | 유지 | [frontend/README.md](../../frontend/README.md#현재-기능-연결과-디자인-기준) | `b86fb05db0b7be830455c93929fa86706ae768c9051ea756dbae5c5bee2ef7ed` |
| `frontend/README.md:562–656` | 기존 호환 안내 유지 | [frontend/README.md](../../frontend/README.md#clipback-frontend) | `c65bc3358f9d299b7b997a13206c6416caf325e9514e14a431703defaa07a29e` |
| `backend/README.md:1–11` | 유지 | [backend/README.md](../../backend/README.md#clipback-backend) | `539cfe9cdcdc1a7171a05a28308894b74c1c1ae95786ab4a606f4a776bbddeb1` |
| `backend/README.md:38–68` | 유지 | [backend/README.md](../../backend/README.md#database-migrations) | `55eec00446d88f1b2f6df4de4f2925f2dd1a9fbf23a94fa09856896811de22ec` |
| `backend/README.md:732–746` | 유지 | [backend/README.md](../../backend/README.md#structure) | `e737e5a2441efd6c8ed5c528dd2c42e39c42e8b5b5eebc1c39e9484923e2ac1f` |
| `backend/README.md:815–833` | 유지·기존 호환 안내 유지 | [backend/README.md](../../backend/README.md#railway-deployment) | `442388e93918246ddd78913d515a2d912bbaafdf061f0aec36121a229cc4f8e9` |
| `docs/backend-mvp-plan.md:1–57` | 유지・제목 변경 | [docs/backend-mvp-plan.md](../backend-mvp-plan.md#허투루-백엔드-mvp-진행-현황) | `a5b0ce8698ae8fc25fcfaa61a92ac7f356701855dc3ad510c2b25b96fefc25b3` |
| `docs/backend-mvp-plan.md:97–156` | 유지 | [docs/backend-mvp-plan.md](../backend-mvp-plan.md#5-다음-진행-순서) | `2b9b672aac5f4dc9252ff0d89c66c731f3472a3e33eda5bb6604f92bf24529f5` |
| `docs/content-recommendation-plan.md:1–259` | 유지・제목 변경 | [docs/content-recommendation-plan.md](../content-recommendation-plan.md#콘텐츠-재발견-추천-구현-계획) | `34d5ca5f4bc529854e9f4c4835c6224df28cabbc2d3285a3363c9f0c098d2c3c` |
| `docs/content-recommendation-plan.md:322–375` | 유지 | [docs/content-recommendation-plan.md](../content-recommendation-plan.md#10-구현-단계와-완료-기준) | `6615d5c88f30da2c010370bb1d7e0008791826ae9cd2d0ff577b1b47e6cc000c` |
| `README.md:1–133` | 유지 | [README.md](../../README.md#허투루--huturu) | `52dd1c9c282f9368bb0fb8e8e3f06f2e95d1b5c0a68705dac9ff23070bcdcc83` |
| `frontend/README.md:289–290` | 기존 제목 앵커 유지 | [frontend/README.md](../../frontend/README.md#실행과-검증) | `6b3d4528d6a54c92c764da0d7ade6936b2a4fe92f30703c910af617397beff3c` |
| `backend/README.md:27–37` | 준비·서버 시작 분리, 원문 코드 보존 | [docs/history/2026-10-22-general-docs-structure.md](2026-10-22-general-docs-structure.md#original-3) | `4318a7a1171cda973f0ac1180ffd99a85b1888f5cbd4ddd98b735fca0d9ba6a5` |
| `README.md:134–145` | 용도별 목차 재배치·참조명 갱신 | [README.md](../../README.md#개발-문서) | `6ae63e5d7b4ee37a639459df83602e3a0ee1ece4b2bc18aecf97d3bbac3ec31a` |
| `docs/git-conventions.md:1–161` | 기존 규칙 유지·상세 문서 기준 추가 | [docs/git-conventions.md](../git-conventions.md#git-conventions) | `943ba9822b172a9963aa7c86d7cffa8c516a27719f0320a3c8e869e2fb2d69f5` |
| `docs/category-recommendation-policy.md:1–211` | 정책 유지·API 참조 위치 갱신 | [docs/category-recommendation-policy.md](../category-recommendation-policy.md#카테고리-자동-추천-정책-및-구현-상태) | `bc0eae12f31fa2a4622f99d48b13037c72e3e43c867383ea764e1b8ed57ecb98` |
| `docs/release-process.md:1–82` | 절차 유지·실행 참조 위치 갱신 | [docs/release-process.md](../release-process.md#업데이트-내역과-배포-관리) | `5673c4c87c13df936731fb26a795567c96b3011ac10eb7fddef6569560681954` |

## 기존 앵커 연결

제거·이동한 제목에는 원래 문서에 앵커와 새 위치 안내를 남겼습니다. 이전 이력의 링크는 변경하지 않았으며 현재 안내의 링크는 새 기준 위치로 연결합니다.

| 기존 위치 | 새 위치 |
| --- | --- |
| [frontend/README.md#초기-세션-복원과-재시도](../../frontend/README.md#초기-세션-복원과-재시도) | [docs/frontend/behavior.md#초기-세션-복원과-재시도](../frontend/behavior.md#초기-세션-복원과-재시도) |
| [frontend/README.md#모바일-소셜-로그인](../../frontend/README.md#모바일-소셜-로그인) | [docs/frontend/behavior.md#모바일-소셜-로그인](../frontend/behavior.md#모바일-소셜-로그인) |
| [frontend/README.md#공개-앱-설정](../../frontend/README.md#공개-앱-설정) | [docs/frontend/development.md#공개-앱-설정](../frontend/development.md#공개-앱-설정) |
| [frontend/README.md#검증-범위](../../frontend/README.md#검증-범위) | [docs/frontend/development.md#검증-범위](../frontend/development.md#검증-범위) |
| [frontend/README.md#갱신-토큰-저장](../../frontend/README.md#갱신-토큰-저장) | [docs/frontend/behavior.md#갱신-토큰-저장](../frontend/behavior.md#갱신-토큰-저장) |
| [frontend/README.md#동시-인증-오류와-로그아웃](../../frontend/README.md#동시-인증-오류와-로그아웃) | [docs/frontend/behavior.md#동시-인증-오류와-로그아웃](../frontend/behavior.md#동시-인증-오류와-로그아웃) |
| [frontend/README.md#스크린샷-저장과-인증-재시도](../../frontend/README.md#스크린샷-저장과-인증-재시도) | [docs/frontend/behavior.md#스크린샷-저장과-인증-재시도](../frontend/behavior.md#스크린샷-저장과-인증-재시도) |
| [frontend/README.md#저장된-스크린샷-원본-조회](../../frontend/README.md#저장된-스크린샷-원본-조회) | [docs/frontend/behavior.md#저장된-스크린샷-원본-조회](../frontend/behavior.md#저장된-스크린샷-원본-조회) |
| [frontend/README.md#콘텐츠-저장과-자동-분류](../../frontend/README.md#콘텐츠-저장과-자동-분류) | [docs/frontend/behavior.md#콘텐츠-저장과-자동-분류](../frontend/behavior.md#콘텐츠-저장과-자동-분류) |
| [frontend/README.md#피드-추가-조회와-상세-탐색](../../frontend/README.md#피드-추가-조회와-상세-탐색) | [docs/frontend/behavior.md#피드-추가-조회와-상세-탐색](../frontend/behavior.md#피드-추가-조회와-상세-탐색) |
| [frontend/README.md#콘텐츠-변경과-실패-복구](../../frontend/README.md#콘텐츠-변경과-실패-복구) | [docs/frontend/behavior.md#콘텐츠-변경과-실패-복구](../frontend/behavior.md#콘텐츠-변경과-실패-복구) |
| [frontend/README.md#카테고리-삭제](../../frontend/README.md#카테고리-삭제) | [docs/frontend/behavior.md#카테고리-삭제](../frontend/behavior.md#카테고리-삭제) |
| [frontend/README.md#실행과-검증](../../frontend/README.md#실행과-검증) | [frontend/README.md#빠른-실행](../../frontend/README.md#빠른-실행) |
| [frontend/README.md#상단-안전-영역과-헤더](../../frontend/README.md#상단-안전-영역과-헤더) | [docs/frontend/behavior.md#상단-안전-영역과-헤더](../frontend/behavior.md#상단-안전-영역과-헤더) |
| [frontend/README.md#android-개발-실행](../../frontend/README.md#android-개발-실행) | [docs/frontend/development.md#android-개발-실행](../frontend/development.md#android-개발-실행) |
| [frontend/README.md#ios-개발-실행](../../frontend/README.md#ios-개발-실행) | [docs/frontend/development.md#ios-개발-실행](../frontend/development.md#ios-개발-실행) |
| [frontend/README.md#testflight-권한-설명과-재업로드](../../frontend/README.md#testflight-권한-설명과-재업로드) | [docs/frontend/development.md#testflight-권한-설명과-재업로드](../frontend/development.md#testflight-권한-설명과-재업로드) |
| [frontend/README.md#backend-integration-boundaries](../../frontend/README.md#backend-integration-boundaries) | [docs/frontend/behavior.md#backend-integration-boundaries](../frontend/behavior.md#backend-integration-boundaries) |
| [frontend/README.md#모바일-공유-저장](../../frontend/README.md#모바일-공유-저장) | [docs/frontend/behavior.md#모바일-공유-저장](../frontend/behavior.md#모바일-공유-저장) |
| [frontend/README.md#플랫폼-설정](../../frontend/README.md#플랫폼-설정) | [docs/frontend/development.md#플랫폼-설정](../frontend/development.md#플랫폼-설정) |
| [frontend/README.md#로컬-공유-검증](../../frontend/README.md#로컬-공유-검증) | [docs/frontend/development.md#로컬-공유-검증](../frontend/development.md#로컬-공유-검증) |
| [backend/README.md#mvp-scope](../../backend/README.md#mvp-scope) | [docs/backend/api-contracts.md#mvp-scope](../backend/api-contracts.md#mvp-scope) |
| [backend/README.md#local-development](../../backend/README.md#local-development) | [backend/README.md#빠른-실행](../../backend/README.md#빠른-실행) |
| [backend/README.md#validation](../../backend/README.md#validation) | [docs/backend/testing.md#validation](../backend/testing.md#validation) |
| [backend/README.md#guest-authentication](../../backend/README.md#guest-authentication) | [docs/backend/api-contracts.md#guest-authentication](../backend/api-contracts.md#guest-authentication) |
| [backend/README.md#mobile-social-authentication](../../backend/README.md#mobile-social-authentication) | [docs/backend/api-contracts.md#mobile-social-authentication](../backend/api-contracts.md#mobile-social-authentication) |
| [backend/README.md#apple-ios-authentication](../../backend/README.md#apple-ios-authentication) | [docs/backend/api-contracts.md#apple-ios-authentication](../backend/api-contracts.md#apple-ios-authentication) |
| [backend/README.md#native-mobile-share-authentication-and-retries](../../backend/README.md#native-mobile-share-authentication-and-retries) | [docs/backend/api-contracts.md#native-mobile-share-authentication-and-retries](../backend/api-contracts.md#native-mobile-share-authentication-and-retries) |
| [backend/README.md#my-page-account-and-statistics](../../backend/README.md#my-page-account-and-statistics) | [docs/backend/api-contracts.md#my-page-account-and-statistics](../backend/api-contracts.md#my-page-account-and-statistics) |
| [backend/README.md#content-view-events](../../backend/README.md#content-view-events) | [docs/backend/api-contracts.md#content-view-events](../backend/api-contracts.md#content-view-events) |
| [backend/README.md#today-recommendations](../../backend/README.md#today-recommendations) | [docs/backend/api-contracts.md#today-recommendations](../backend/api-contracts.md#today-recommendations) |
| [backend/README.md#weekly-recommendations](../../backend/README.md#weekly-recommendations) | [docs/backend/api-contracts.md#weekly-recommendations](../backend/api-contracts.md#weekly-recommendations) |
| [backend/README.md#recommendation-exposures](../../backend/README.md#recommendation-exposures) | [docs/backend/api-contracts.md#recommendation-exposures](../backend/api-contracts.md#recommendation-exposures) |
| [backend/README.md#category-summaries](../../backend/README.md#category-summaries) | [docs/backend/api-contracts.md#category-summaries](../backend/api-contracts.md#category-summaries) |
| [backend/README.md#personal-categories-update-and-delete](../../backend/README.md#personal-categories-update-and-delete) | [docs/backend/api-contracts.md#personal-categories-update-and-delete](../backend/api-contracts.md#personal-categories-update-and-delete) |
| [backend/README.md#deploying-existing-data](../../backend/README.md#deploying-existing-data) | [docs/backend/api-contracts.md#deploying-existing-data](../backend/api-contracts.md#deploying-existing-data) |
| [backend/README.md#content-category-validation](../../backend/README.md#content-category-validation) | [docs/backend/api-contracts.md#content-category-validation](../backend/api-contracts.md#content-category-validation) |
| [backend/README.md#content-url-length](../../backend/README.md#content-url-length) | [docs/backend/api-contracts.md#content-url-length](../backend/api-contracts.md#content-url-length) |
| [backend/README.md#tag-replacement](../../backend/README.md#tag-replacement) | [docs/backend/api-contracts.md#tag-replacement](../backend/api-contracts.md#tag-replacement) |
| [backend/README.md#feed-pagination](../../backend/README.md#feed-pagination) | [docs/backend/api-contracts.md#feed-pagination](../backend/api-contracts.md#feed-pagination) |
| [backend/README.md#screenshot-storage](../../backend/README.md#screenshot-storage) | [docs/backend/api-contracts.md#screenshot-storage](../backend/api-contracts.md#screenshot-storage) |
| [backend/README.md#mvp-api-integration-tests](../../backend/README.md#mvp-api-integration-tests) | [docs/backend/testing.md#mvp-api-integration-tests](../backend/testing.md#mvp-api-integration-tests) |
| [backend/README.md#native-share-local-backend-harness](../../backend/README.md#native-share-local-backend-harness) | [docs/backend/testing.md#native-share-local-backend-harness](../backend/testing.md#native-share-local-backend-harness) |
| [docs/backend-mvp-plan.md#허투루-백엔드-mvp-진행-현황](../backend-mvp-plan.md#허투루-백엔드-mvp-진행-현황) | [docs/backend-mvp-plan.md#mvp-범위와-구현-현황](../backend-mvp-plan.md#mvp-범위와-구현-현황) |
| [docs/content-recommendation-plan.md#콘텐츠-재발견-추천-구현-계획](../content-recommendation-plan.md#콘텐츠-재발견-추천-구현-계획) | [docs/content-recommendation-plan.md#콘텐츠-재발견-추천-정책과-구현-현황](../content-recommendation-plan.md#콘텐츠-재발견-추천-정책과-구현-현황) |

## 중복과 출처 차이

- 이번 작업에서는 동일 원문 삭제로 보존 대상을 줄이지 않았습니다. README의 짧은 실행 예시와 상세 검증 명령은 각 문맥을 유지합니다.
- 추천 API는 기존 백엔드 README의 엔드포인트 설명과 추천 정책 문서의 추가 연결 계약을 출처별로 같은 API 문서에 보존했습니다. 원문 표현·조건이 다른 설명을 성공·동일 조건으로 합치지 않았습니다.
- 일반 수동 저장과 네이티브 공유의 중복 방지·재시도 조건은 서로 다른 범위로 유지합니다. 크기 표기는 원문의 서버 `10MB`와 프론트 `기본 10MiB`를 보존하며 실제 제한 값은 코드 설정으로 확인합니다.
- 이전 기준의 누락 증거는 기존 대조표의 고유 경로 1,120개 중 152개라는 당시 결과로 유지합니다. 이번 작업에서 복구·재촬영·운영 성공으로 바꾸지 않았습니다.

## 재구성 전 안내 원문

다음 원문은 실행 예시의 분리·선행 migration·기존 `.env` 보존 안내와 공유 검증 서버 참조 이동으로 재구성했습니다. 현재 실행 순서는 각 README와 상세 문서를 따릅니다. 아래는 기준 커밋의 원문 보존용입니다.

<a id="original-1"></a>

### frontend/README.md:302–307

원문 SHA-256: `6a9b83dea7cc356199dca33bfa490f4e4a1e55bc31cb0d93fd75055075aefbd7`

```bash
flutter run -d chrome --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:8000/api/v1
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

<a id="original-2"></a>

### frontend/README.md:534–538

원문 SHA-256: `3f9e3bd0704bd88d39b95054b541efabd493adf6caffa69a57e2cafaa134cc86`

`SHARE_PREVIEW_SIGNED_OUT=true`를 추가하면 미로그인 초안 복구를 확인할 수 있습니다.
실제 FastAPI·전용 PostgreSQL 검증은 백엔드 README의 `share_live_server`를 실행하고,
주소를 18766 포트로 변경한 뒤 `SHARE_PREVIEW_REAL_BACKEND=true`를 추가합니다.
이 경우 본앱의 게스트 시작 버튼으로 테스트 서버 세션을 발급받습니다.
외부 OAuth·AI/OCR·metadata는 대역이며 실제 공급자 동작이나 운영 저장을 증명하지 않습니다.

<a id="original-3"></a>

### backend/README.md:29–36

원문 SHA-256: `ffe3f6ec0dbb481cca497b68ad9812f78d9171d60a3eade0ec27234f1f8d0181`

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
uvicorn app.main:app --reload
```

## 실제 확인과 미검증

- 임시 검사 스크립트로 대상 기존 문서 8개의 원문 블록 928개를 대조했습니다. 제목 앵커 유지 126개, 같은 문서 유지 514개, 상세 문서 이동 285개, 재구성 전 원문 보존 3개입니다. 원문 코드·JSON·수치·오류·검증 한계의 누락은 없었습니다.
- 기존 Markdown 114개의 앵커 2,066개를 모두 보존했습니다. 상대 Markdown 링크 1,151건과 HTML 이미지 참조 1건에서 새 누락 파일·앵커와 중복 ID가 없었습니다.
- 대상 원문의 링크 188건은 같은 대상 또는 대조표의 새 기준 위치로 연결됩니다. 기존 절대 증거 참조 1,820건도 보존했습니다. 기존 이력 93개와 이전 이관 대조표의 내용, 로컬 AGENTS·편집기 임시 파일의 해시는 유지했습니다.
- 명령이 참조하는 코드·테스트·예제 설정·워크스페이스 19개 경로를 확인했습니다. SDK 조건은 잠금파일, Python·검사 명령은 프로젝트 설정과 CI 정의, 공유 서버의 전용 DB 제한은 서버 코드와 정적으로 대조했습니다.
- 프론트 README는 656→225줄, 백엔드 README는 833→149줄로 정리했습니다. 접힌 기존 앵커 안내를 포함한 길이이며, 상세 내용은 새 문서와 원문 보존 절로 연결됩니다.
- 최종 diff와 `git diff --check`에서 공백 오류·범위 밖 변경·비밀정보·생성 파일의 포함이 없는지 확인했습니다. 검사 스크립트와 원문 스냅샷은 임시 경로에만 두었습니다.

| 안내 대조 시나리오 | 확인 결과 |
| --- | --- |
| 소셜 로그인 설정 찾기 | 프론트 README → 개발 안내의 공개 앱 설정 → 백엔드 소셜 API·서버 설정 연결. 공급자·실기기 확인을 별도 범위로 유지 |
| 전용 PostgreSQL 테스트 | 백엔드 README → 테스트 안내의 Validation·통합 테스트. 명시적 테스트 DB·선행 migration·미설정 skip·잘못된 설정 실패 조건 보존 |
| 공유 대역과 실제 로컬 백엔드 구분 | 프론트 개발 안내의 HTTP fixture 18765와 백엔드 공유 서버 18766을 구분. 후자도 외부 OAuth·AI/OCR·metadata는 대역임을 유지 |
| TestFlight 재업로드 | 배포 절차 → 프론트 개발 안내의 권한·새 빌드 번호·`-t lib/main.dart`·아카이브 업로드. 빌드와 처리·공개 결과를 구분 |

앱 테스트·빌드·시뮬레이터·에뮬레이터·실기기·실제 공급자·운영 서버·원격 CI는 문서 작업이므로 실행하지 않았습니다. 과거 실행 결과와 이번 문서 검사를 구분합니다. 푸시·PR·병합·태그·실제 배포도 수행하지 않았습니다.

## 후속 잔여 문서 정리 (2026-10-22)

<a id="followup-docs-finish"></a>

기준 커밋: `b6384dc5122628aec7b0d2fcb1b098fd4a887a7b`. 원문은 `git show b6384dc5122628aec7b0d2fcb1b098fd4a887a7b:원본경로`로 확인합니다. 앞선 절의 기준·대조표·검증 수치는 당시 결과로 유지합니다.

- 지표의 검증 원문을 기존 Weekly 이력에 출처별로 추가했습니다. SQL·지표 정의·과거 확인일은 유지합니다.
- Figma의 현재 유지 기준과 미확정 사항을 분리했습니다. 노드·DEC·명시적 앵커를 보존하며 승인 범위를 추가하지 않았습니다.
- API 목차·제목과 현재 안내의 참조·표현을 정리했습니다. 원래 API 제목 앵커는 호환 ID로 유지합니다.
- 사용자 변경 이력은 제외합니다. 문서만 변경하며 새 파일·앱 코드·공개 API·설정·버전·CI·미디어·이전 이관 대조표는 변경하지 않습니다.

### 지표 검증 원문 대응

원본 `docs/product-metrics-queries.md:122–126`, SHA-256 `0077ff79a9ce260dbde54cf5462364cb8b5e4a84c62437692b6d20ce4259b889` → [Weekly의 출처별 원문](2026-09-25-weekly-backend.md#metrics-validation-20260925). 기존 출처와 표현이 달라 동일 원문으로 합치지 않았습니다.

### Figma 47개 행 대응

현재 기준과 남은 확인을 각각 연결합니다. 남은 확인이 없는 행은 해당 치수·이동 범위가 확정된 것으로 한정하며 다른 상태의 완료를 뜻하지 않습니다. 원문은 아래 접힌 보존 절에 있으며 hash는 원본 행의 UTF-8(개행 제외)입니다.

| 원본 행 | 현재 유지 기준 | 남은 확인 | 당시 작업 이력 | 원문 SHA-256 |
| --- | --- | --- | --- | --- |
| `docs/figma-ui-alignment-plan.md:83` | [유지 01](../figma-ui-alignment-plan.md#figma-current-01) | [확인 01](../figma-ui-alignment-plan.md#figma-pending-01) | [2026-10-21-original-link](2026-10-21-original-link.md) | `e5e7e8fcd178b465b43c66700fc6b0d2bdc543bd4ab0e10b6adc2913f5becd50` |
| `docs/figma-ui-alignment-plan.md:84` | [유지 02](../figma-ui-alignment-plan.md#figma-current-02) | [확인 02](../figma-ui-alignment-plan.md#figma-pending-02) | [2026-10-19-category-content](2026-10-19-category-content.md) | `ca3c17f044b13c038f62e038ac20ede973362200a8c83296bac771bd8f29387e` |
| `docs/figma-ui-alignment-plan.md:85` | [유지 03](../figma-ui-alignment-plan.md#figma-current-03) | [확인 03](../figma-ui-alignment-plan.md#figma-pending-03) | [2026-10-18-login-layout](2026-10-18-login-layout.md) | `faee2be5c5a50e3899feb25e5cb64b95e84e5a2bd9c45152e3ad12b85fd188c5` |
| `docs/figma-ui-alignment-plan.md:86` | [유지 04](../figma-ui-alignment-plan.md#figma-current-04) | [확인 04](../figma-ui-alignment-plan.md#figma-pending-04) | [2026-10-19-login-progress](2026-10-19-login-progress.md) · [2026-10-19-login-failure](2026-10-19-login-failure.md) | `8a0e7d73ee1d1ce2ca67333d3829043d48fc73781a81182f9e6a4f11735ec0bb` |
| `docs/figma-ui-alignment-plan.md:87` | [유지 05](../figma-ui-alignment-plan.md#figma-current-05) | [확인 05](../figma-ui-alignment-plan.md#figma-pending-05) | [2026-10-19-account-conflict](2026-10-19-account-conflict.md) · [2026-10-19-login-failure](2026-10-19-login-failure.md) | `06b9645b1b09574a903311dff9b36c4cc68ce198aa11741442399a823f5c163f` |
| `docs/figma-ui-alignment-plan.md:88` | [유지 06](../figma-ui-alignment-plan.md#figma-current-06) | [확인 06](../figma-ui-alignment-plan.md#figma-pending-06) | [2026-10-18-home-layout](2026-10-18-home-layout.md) | `850cde7cbbfdc05211ebf2401a0a031782f015748f493dda9d26cea4f9f18ff7` |
| `docs/figma-ui-alignment-plan.md:89` | [유지 07](../figma-ui-alignment-plan.md#figma-current-07) | [확인 07](../figma-ui-alignment-plan.md#figma-pending-07) | [2026-10-18-home-layout](2026-10-18-home-layout.md) | `2ddbe7b081b189308d956e17d581cb67a07e16f2642472ffc7d9a1fc1e433ec6` |
| `docs/figma-ui-alignment-plan.md:90` | [유지 08](../figma-ui-alignment-plan.md#figma-current-08) | [확인 08](../figma-ui-alignment-plan.md#figma-pending-08) | [2026-10-18-home-layout](2026-10-18-home-layout.md) | `34cc7b775208fd2a6d41650816f44678cae384bb15ca2ca0019a8aeeabae8460` |
| `docs/figma-ui-alignment-plan.md:91` | [유지 09](../figma-ui-alignment-plan.md#figma-current-09) | [확인 09](../figma-ui-alignment-plan.md#figma-pending-09) | [2026-10-18-initial-loading](2026-10-18-initial-loading.md) | `725e441e5d66c8b95b15ca21ffeb4bc63228a70fa7776d1df54f023deaecf1e8` |
| `docs/figma-ui-alignment-plan.md:92` | [유지 10](../figma-ui-alignment-plan.md#figma-current-10) | [확인 10](../figma-ui-alignment-plan.md#figma-pending-10) | [2026-10-18-home-layout](2026-10-18-home-layout.md) | `7a96bb5f81f31b4dbebab65e3505c2f185781d5a0aebaa1eb2e1ea5d65fd9564` |
| `docs/figma-ui-alignment-plan.md:93` | [유지 11](../figma-ui-alignment-plan.md#figma-current-11) | [확인 11](../figma-ui-alignment-plan.md#figma-pending-11) | [2026-10-21-today-frontend](2026-10-21-today-frontend.md) · [2026-10-21-weekly-frontend](2026-10-21-weekly-frontend.md) | `4eaae58478f19c312824fd6f9cc3b95176c6d657514c531bef7dbfa9ec402edd` |
| `docs/figma-ui-alignment-plan.md:94` | [유지 12](../figma-ui-alignment-plan.md#figma-current-12) | [확인 12](../figma-ui-alignment-plan.md#figma-pending-12) | [2026-10-18-my-layout](2026-10-18-my-layout.md) · [2026-10-17-detail-layout](2026-10-17-detail-layout.md) | `e04eb7054d01e37f0d96c826287847ad77cacad0a3d0c1298254b0dd539f232d` |
| `docs/figma-ui-alignment-plan.md:95` | [유지 13](../figma-ui-alignment-plan.md#figma-current-13) | [확인 13](../figma-ui-alignment-plan.md#figma-pending-13) | [2026-10-18-account-layout](2026-10-18-account-layout.md) | `67967514053a8b044f2ef12b77ccd0457f0c1b665de792e98db939b29f427d05` |
| `docs/figma-ui-alignment-plan.md:96` | [유지 14](../figma-ui-alignment-plan.md#figma-current-14) | [확인 14](../figma-ui-alignment-plan.md#figma-pending-14) | [2026-10-18-logout-layout](2026-10-18-logout-layout.md) | `ef212e0de4558ee36a3db9879754bc7e569851c1ecabee30f3a6bb13f4eb475f` |
| `docs/figma-ui-alignment-plan.md:97` | [유지 15](../figma-ui-alignment-plan.md#figma-current-15) | [확인 15](../figma-ui-alignment-plan.md#figma-pending-15) | [2026-10-18-account-layout](2026-10-18-account-layout.md) · [2026-10-22-system-back](2026-10-22-system-back.md) | `34cac14580194dc7ddc9d0489cde9bfba61ebf931ee6ef0e21590327331d2ed1` |
| `docs/figma-ui-alignment-plan.md:98` | [유지 16](../figma-ui-alignment-plan.md#figma-current-16) | [확인 16](../figma-ui-alignment-plan.md#figma-pending-16) | [2026-10-18-my-layout](2026-10-18-my-layout.md) | `557eebd51224163afc83aefa82123bae5a3f7aa5cab400470f747ed276769278` |
| `docs/figma-ui-alignment-plan.md:99` | [유지 17](../figma-ui-alignment-plan.md#figma-current-17) | [확인 17](../figma-ui-alignment-plan.md#figma-pending-17) | [2026-10-18-notice-list](2026-10-18-notice-list.md) | `d4bd6107f1b65cf68ce5e110fc30f039f2da352c00221cc32e364b46034d79be` |
| `docs/figma-ui-alignment-plan.md:100` | [유지 18](../figma-ui-alignment-plan.md#figma-current-18) | [확인 18](../figma-ui-alignment-plan.md#figma-pending-18) | [2026-10-18-notice-list](2026-10-18-notice-list.md) | `1b4b539d8fc795b33ec651a0fb1d4a9509613a7c713dc39c6c15da5796264bca` |
| `docs/figma-ui-alignment-plan.md:101` | [유지 19](../figma-ui-alignment-plan.md#figma-current-19) | [확인 19](../figma-ui-alignment-plan.md#figma-pending-19) | [2026-10-21-original-link](2026-10-21-original-link.md) | `926edeaec8a46ce63fdd96cf7b8ba73e5046ea8fb3b3b4ed310523cc6dc1c515` |
| `docs/figma-ui-alignment-plan.md:102` | [유지 20](../figma-ui-alignment-plan.md#figma-current-20) | [확인 20](../figma-ui-alignment-plan.md#figma-pending-20) | [2026-10-17-detail-layout](2026-10-17-detail-layout.md) | `b40bc5ca353f154cd98312769710cfa44dcb35070659b1fe54c2b98d8d946077` |
| `docs/figma-ui-alignment-plan.md:103` | [유지 21](../figma-ui-alignment-plan.md#figma-current-21) | [확인 21](../figma-ui-alignment-plan.md#figma-pending-21) | [2026-10-17-detail-layout](2026-10-17-detail-layout.md) | `2012e2f95040e684a3e7b2db62f9900f40bc27b47deddff49aca45613491eda5` |
| `docs/figma-ui-alignment-plan.md:104` | [유지 22](../figma-ui-alignment-plan.md#figma-current-22) | 해당 행의 추가 미확정 없음 | [2026-10-19-detail-paging](2026-10-19-detail-paging.md) | `a164994b57c0333c5125dcd2dc16326309a817cf8f845ed8714a7b9932b09a99` |
| `docs/figma-ui-alignment-plan.md:105` | [유지 23](../figma-ui-alignment-plan.md#figma-current-23) | [확인 23](../figma-ui-alignment-plan.md#figma-pending-23) | [2026-10-18-card-review](2026-10-18-card-review.md) | `bf31dd981dca0a2fcb206bfb7be8a6f1c6d9bec630f8cd3d09074bf7892e1866` |
| `docs/figma-ui-alignment-plan.md:106` | [유지 24](../figma-ui-alignment-plan.md#figma-current-24) | [확인 24](../figma-ui-alignment-plan.md#figma-pending-24) | [2026-10-18-card-review](2026-10-18-card-review.md) | `78ea131adc48f618a94cd2f9afb9df6c399881a1c0fb0941558cc1f88b8e39c3` |
| `docs/figma-ui-alignment-plan.md:107` | [유지 25](../figma-ui-alignment-plan.md#figma-current-25) | [확인 25](../figma-ui-alignment-plan.md#figma-pending-25) | [2026-10-18-card-review](2026-10-18-card-review.md) | `b8e5abcece0938693a6f96d4a5dd1088cfc7835b507e76af54fb670641363033` |
| `docs/figma-ui-alignment-plan.md:108` | [유지 26](../figma-ui-alignment-plan.md#figma-current-26) | [확인 26](../figma-ui-alignment-plan.md#figma-pending-26) | [2026-10-18-interest-layout](2026-10-18-interest-layout.md) · [2026-10-18-permission-guide](2026-10-18-permission-guide.md) | `c1b4b39b12de6b73f6746ea296bb39526f11de0888ecc853fbf6e88f67606ba7` |
| `docs/figma-ui-alignment-plan.md:109` | [유지 27](../figma-ui-alignment-plan.md#figma-current-27) | [확인 27](../figma-ui-alignment-plan.md#figma-pending-27) | [2026-10-19-figma-closure](2026-10-19-figma-closure.md) · [2026-10-18-interest-layout](2026-10-18-interest-layout.md) | `45ab679162f7bc13c5b9669306ff7f5536273e9c3f39bdfa31b5b2c6dad2b83e` |
| `docs/figma-ui-alignment-plan.md:110` | [유지 28](../figma-ui-alignment-plan.md#figma-current-28) | [확인 28](../figma-ui-alignment-plan.md#figma-pending-28) | [2026-10-15-save-keyboard](2026-10-15-save-keyboard.md) | `e8c561d4cfc3f4475ebcb29dcf0ab71957e0dcdec65bdb3fd058b5e71777a7e3` |
| `docs/figma-ui-alignment-plan.md:111` | [유지 29](../figma-ui-alignment-plan.md#figma-current-29) | [확인 29](../figma-ui-alignment-plan.md#figma-pending-29) | [2026-10-15-paste-button](2026-10-15-paste-button.md) | `4882f2f4ac923e49cde5adb5c2afc335040f18202c2398fa64d685e25ab068fa` |
| `docs/figma-ui-alignment-plan.md:112` | [유지 30](../figma-ui-alignment-plan.md#figma-current-30) | 해당 행의 추가 미확정 없음 | [2026-10-17-photo-frame](2026-10-17-photo-frame.md) | `e7f3ab52a6e4f0569c7abe8964642587f341fb51ecb718cefe007d3059a854d8` |
| `docs/figma-ui-alignment-plan.md:113` | [유지 31](../figma-ui-alignment-plan.md#figma-current-31) | [확인 31](../figma-ui-alignment-plan.md#figma-pending-31) | [2026-10-18-photo-contain](2026-10-18-photo-contain.md) | `29afd579c4ad0e9c337b4c5ca0eb3f901fc2a1220c8c58406fad3aa4b86b1a14` |
| `docs/figma-ui-alignment-plan.md:114` | [유지 32](../figma-ui-alignment-plan.md#figma-current-32) | [확인 32](../figma-ui-alignment-plan.md#figma-pending-32) | [2026-10-17-save-result-layout](2026-10-17-save-result-layout.md) | `74eefb622f2edfac4e6fd6ab9a185627a95007937a4dbe604c6a2f484670d49f` |
| `docs/figma-ui-alignment-plan.md:115` | [유지 33](../figma-ui-alignment-plan.md#figma-current-33) | [확인 33](../figma-ui-alignment-plan.md#figma-pending-33) | [2026-10-16-save-preview-text](2026-10-16-save-preview-text.md) | `cce962c7df866b3ac8896abb942963fb6cb97d63a47381caa2e19a62e6faa522` |
| `docs/figma-ui-alignment-plan.md:116` | [유지 34](../figma-ui-alignment-plan.md#figma-current-34) | [확인 34](../figma-ui-alignment-plan.md#figma-pending-34) | [2026-10-16-save-category-text](2026-10-16-save-category-text.md) | `8adb884b85d4195e2a1eecdbe052d9d3974aa5833f95a1aee56c7e2be25e9050` |
| `docs/figma-ui-alignment-plan.md:117` | [유지 35](../figma-ui-alignment-plan.md#figma-current-35) | [확인 35](../figma-ui-alignment-plan.md#figma-pending-35) | [2026-10-17-category-list](2026-10-17-category-list.md) | `81a6475275b3f194e4cdf7381eb4550592e4dc602675c2c84b122e6148289f04` |
| `docs/figma-ui-alignment-plan.md:118` | [유지 36](../figma-ui-alignment-plan.md#figma-current-36) | [확인 36](../figma-ui-alignment-plan.md#figma-pending-36) | [2026-10-17-category-list](2026-10-17-category-list.md) | `77db483a2e5f73d3f9f0b8cf15502279721f5239ef277a3c35d56b9c9cf39af9` |
| `docs/figma-ui-alignment-plan.md:119` | [유지 37](../figma-ui-alignment-plan.md#figma-current-37) | [확인 37](../figma-ui-alignment-plan.md#figma-pending-37) | [2026-10-17-category-management](2026-10-17-category-management.md) | `fa13af304a4777380cb753311e1a8d74da024ca951b1d068e6ea9c0765311b85` |
| `docs/figma-ui-alignment-plan.md:120` | [유지 38](../figma-ui-alignment-plan.md#figma-current-38) | [확인 38](../figma-ui-alignment-plan.md#figma-pending-38) | [2026-10-17-archive-layout](2026-10-17-archive-layout.md) | `08d9ebd4e0eb58b51dd86b834870d990f8af6d1c3f5765cd26b55bb6d638e1d8` |
| `docs/figma-ui-alignment-plan.md:121` | [유지 39](../figma-ui-alignment-plan.md#figma-current-39) | [확인 39](../figma-ui-alignment-plan.md#figma-pending-39) | [2026-10-17-unclassified-layout](2026-10-17-unclassified-layout.md) | `02d82033727a47df0944c6aff79e42610e92bc0cd1e1daaf893f8328e5c7e4d3` |
| `docs/figma-ui-alignment-plan.md:122` | [유지 40](../figma-ui-alignment-plan.md#figma-current-40) | [확인 40](../figma-ui-alignment-plan.md#figma-pending-40) | [2026-10-17-category-dialogs](2026-10-17-category-dialogs.md) | `fb284de246c2bf73788f7f0375cc4cc6da343ac37cf666c50359dc95bb65ef86` |
| `docs/figma-ui-alignment-plan.md:123` | [유지 41](../figma-ui-alignment-plan.md#figma-current-41) | [확인 41](../figma-ui-alignment-plan.md#figma-pending-41) | [2026-10-18-my-layout](2026-10-18-my-layout.md) · [2026-10-19-login-failure](2026-10-19-login-failure.md) | `3e9f85ad628b2ead809c2c70e08ae4ff3cce9c5a5ff8334116b9b924b549024f` |
| `docs/figma-ui-alignment-plan.md:124` | [유지 42](../figma-ui-alignment-plan.md#figma-current-42) | [확인 42](../figma-ui-alignment-plan.md#figma-pending-42) | [2026-10-18-notification-list](2026-10-18-notification-list.md) | `000fe1318b75b5bf6e3265087e8af91bf8da4efc3b47565078ba08221e36d072` |
| `docs/figma-ui-alignment-plan.md:125` | [유지 43](../figma-ui-alignment-plan.md#figma-current-43) | [확인 43](../figma-ui-alignment-plan.md#figma-pending-43) | [2026-10-13-figma-planning](2026-10-13-figma-planning.md) | `3de40b36c0d308dd5dca49d9fb94cd5579f282a7e09f94da0070dd5b8f1aabd5` |
| `docs/figma-ui-alignment-plan.md:126` | [유지 44](../figma-ui-alignment-plan.md#figma-current-44) | [확인 44](../figma-ui-alignment-plan.md#figma-pending-44) | [2026-10-17-bookmark-layout](2026-10-17-bookmark-layout.md) | `26f8aa1f4a44b0e37e5689dbc4edc7356c5b8597635f8a277ed3d0fc4a260af6` |
| `docs/figma-ui-alignment-plan.md:127` | [유지 45](../figma-ui-alignment-plan.md#figma-current-45) | [확인 45](../figma-ui-alignment-plan.md#figma-pending-45) | [2026-10-22-search-history](2026-10-22-search-history.md) | `a34e4d8883b0d11a924c6e2d0a9f103262e9974f20ff196061cc7ea9999daccc` |
| `docs/figma-ui-alignment-plan.md:128` | [유지 46](../figma-ui-alignment-plan.md#figma-current-46) | [확인 46](../figma-ui-alignment-plan.md#figma-pending-46) | [2026-10-18-tab-icons](2026-10-18-tab-icons.md) | `3dcb1de6b7acbf463c7af24eab88a9049d3eadba13f02747319a73c12ceceeda` |
| `docs/figma-ui-alignment-plan.md:129` | [유지 47](../figma-ui-alignment-plan.md#figma-current-47) | [확인 47](../figma-ui-alignment-plan.md#figma-pending-47) | [2026-10-18-save-add-icon](2026-10-18-save-add-icon.md) | `cf653cd9902ead30180d3fdb2aaac2aa88afb80cc704b5ecb60620e5bd4a91ae` |

<details>
<summary>정리 전 Figma 본문과 47개 행 원문</summary>

출처: `docs/figma-ui-alignment-plan.md:1–135`, 기준 `b6384dc5122628aec7b0d2fcb1b098fd4a887a7b`, 원문 SHA-256 `5001349cd082fc9ee14eb20f411984b8d57ffceff0aecb6bde668ceb8a8627b2`. 상대 링크는 원래 대상으로 보정하고 제목 깊이만 낮췄습니다. 다음 내용은 재구성 전 기록이며 현재 지침은 [현행 Figma 기준](../figma-ui-alignment-plan.md)을 따릅니다.

#### Figma 화면 맞춤 계획

현재 디자인 기준·화면 대응·합의 정책과 확인 필요 상태를 관리합니다.
과거 계획·비교·실행 수치·실패·재촬영 기록은 [작업 이력](README.md)에 보존합니다.
이 정리에서는 Figma를 다시 조회하거나 화면을 실행하지 않았습니다.

#### 상태와 비교 기준

현재 기준은 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 Page 1 (`0:1`) > `261007` (`111:3379`)입니다.
[현재 섹션](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3379)을 사용하며 구현 직전 대상 원본을 다시 확인합니다.
기본 글자 1배율 우선, 기존 OS 안전 영역·콘텐츠 보존·저장 시점과 미확정 디자인 보류 기준을 유지합니다.
확인된 원본의 구현은 현재 로컬 작업 지침을 따르고, 과거 작업의 승인·푸시 예외를 일반 규칙으로 사용하지 않습니다.

#### 변경을 나누는 기준

| 구분 | 포함 범위 | 진행 조건 |
| --- | --- | --- |
| 화면 맞춤 | 여백, 크기, 색, 글자, 아이콘, 일러스트, 문구, 기존 동선의 배치 | 기존 데이터·인증·저장 계약을 유지하며 대상 화면별로 구현 |
| 기능 연결 | 관심사 전달, 추천 연결, 실제 최근 검색어, 원문·썸네일, 오류 복구 | 현재 API와 상태 소유자를 확인하고 필요한 계약을 먼저 정의 |
| 보완 제안 | 이전 `261008`의 M 기록과 Page 1의 M 구조 | 새 기준의 상세 디자인·정책·채택 여부를 확인하고 기존 기능과 겹치는 부분을 재사용 |
| 정책 확인 | 삭제 범위, 게스트 이전, 저장 시점, 총개수 등 | 아래 결정 목록을 해소한 후 의존 작업 진행 |

회색·흰색·노란색 기본 색상, Pretendard, 하단 탭과 추가 버튼, 콘텐츠 목록 카드,
아카이브 탭, 카테고리 생성 시트, 상세 섹션 순서와 카드 스와이프는 이미 구현돼 있다.
기존 위젯과 ViewModel·Repository 구조를 재사용하고 화면 전체를 일괄 재작성하지 않는다.

#### 화면별 차이와 수정 후보

아래는 이관 기준 코드와 기존 승인 기록에 따른 범위입니다. 전체 화면의 새 디자인 대조나 운영 검증 결과는 아닙니다.

| 영역 | 현재 연결·승인 범위 | 남은 경계 |
| --- | --- | --- |
| 공통 스타일·하단 바 | 공통 글자·아이콘·OS 안전 영역과 기존 동선 | 원본 없는 상태와 새 확대 맞춤 |
| 인증·관심사 | 승인된 로그인·진행·취소·실패·충돌·권한 안내·관심사 표현 | 운영 OAuth·대상 계정 정보·소개 원본·선택값 서버 저장 |
| 홈·추천 | Today 상세 탐색, Weekly 카드·카테고리 이동·실제 노출·추천 유입 | 운영 추천 품질·공지 데이터와 목적지 |
| 링크·사진 저장 | 원본 비율 전체 보기, 결과 표현, 제출 입력 기준 대기 | 전용 분석 실패·지연 복구 디자인 |
| 아카이브·분류·즐겨찾기 | 승인된 정상·확인된 빈 상태, 실제 소속·정렬·추가 조회 | 미확정 로딩·오류·일반 빈 상태·총개수 계약 |
| 상세·카드 다시보기 | 승인된 표현·이동, 원문 URL 외부 열기 | 실제 전문·미디어·초기 빈 상태·세션 복원 정책 |
| 검색 | 기존 검색과 기기 내 계정별 최근 검색어 저장·삭제 | 새 전체 집계·미확정 상태 표현 |
| 계정·고객지원 | 승인된 마이·계정·로그아웃, 공지 예제 목록 | 탈퇴 API·실제 운영 공지·문의·네이티브 앱 버전 조회 |
| 시스템 뒤로가기 | 화면별 기존 복귀, Android 홈·로그인·소개 종료 확인 | 전용 팝업 원본 미확보·실기기 검증 |

#### 중복 이름과 확인이 필요한 대응

| 표기 | Page 1 노드와 구분 | 남은 확인 |
| --- | --- | --- |
| A05 | `111:5897` 일반 로그인 실패, `125:3704` 기존 연결 계정·로그인 방법 안내 | 일반 A05는 승인된 일반 소셜 로그인에서 공유 보안 차단 성공 뒤·세션 발급 전 SDK/HTTP 실패에만 사용하며 실제 상태/확인 불가를 표시한다. `125:3704`/설명 `125:3728`의 A05-1은 현재 게스트 연결 시도의409 경고만 승인된 예외로 맞추며 응답 endpoint/원인·대상 계정의 정체를 추정하지 않는다. 대상 계정 정보는 추정하지 않으며 모든409를 같은 상태로 합치지 않는다. |
| C01 | `111:3584` 콘텐츠가 있는 홈, `125:4105` 홈 최초 로딩 | 로딩 설명 `125:4119`는 레이어명이 B05이나 내부 제목은 C01이다. 사용자 확정으로 앱 재실행/기존 계정 로그인 뒤 홈 최초 초기화와 첫 성공 전 수동 재시도에만 전면 프레임을 채택한다. 스켈레톤은 이번에 적용하지 않으며 일반 재조회와 오류 표현은 별도다. |
| D03 | `111:4975` 형식이 무효인 링크, `142:4657` 링크 정보 추출 실패 | 입력 검증과 유효 URL의 추출 실패를 구분한다. |
| D10 | `142:4721` 사진 인식 실패, `142:4898` 분석 지연 | `142:4765`·`142:4942`는 실제 화면이 아닌 설명 프레임이다. 지연 설명의 내부 제목은 D11이므로 대응 확정이 필요하다. |
| E04·빈 미분류 | `111:4569` 카테고리 관리, `142:5097` 미분류 목록 빈 상태 | 설명 `111:5575`·`142:5105`의 레이어명과 내부 화면 번호가 달라 번호만으로 대응하지 않는다. |

#### 구현 전 결정 목록

| ID | 충돌 또는 미확정 사항 | 현재 유지할 동작 / 권장 방향 |
| --- | --- | --- |
| DEC-01 / 확정 | Page 1 E12 `111:4484`도 카테고리 안 콘텐츠까지 삭제한다고 안내 | 사용자가 콘텐츠 보존 방향을 선택했다. 콘텐츠·다른 카테고리를 보존하고 마지막 카테고리 삭제 시 미분류로 이동하는 현재 정책을 유지한다. 승인된 삭제 안내와 현재 콘텐츠 보존 동작을 유지한다. 연쇄 삭제를 추가하지 않는다. |
| DEC-02 | Page 1 A06 `111:3436`의 게스트 안내, A07 `111:5921`·A08 `125:3571`의 이전 흐름과 이전 파일 J-M01 제안 | 현재는 서버 게스트 계정과 소셜 승격이며 기존 소셜 계정 충돌 시 확인 후 계정 전환한다. 로컬 전용 저장·계정 병합·재개 가능한 이전 작업은 별도 설계다. 데이터의 저장 위치와 복구 가능성을 구분해 문구를 정한다. |
| DEC-03 | D05/D09의 결과 카테고리 추가/제거와 확정 시점 | 현재 ‘저장하기’가 API 저장을 수행하고 성공 후 결과를 표시한다. 결과의 ‘닫기’는 저장 확정 버튼이 아니다. 기존 결정은 저장 전 수동 선택·자동 폴링 없이 상세에서 분류를 변경하는 방식이다. 결과 편집을 추가하려면 저장 후 수정인지 저장 전 미리보기인지, 실패·이탈 시 무엇이 이미 저장됐는지 먼저 정한다. |
| DEC-04 | Figma의 ‘총 N개’, 상세의 전체 개수 | 피드 응답은 `items`와 `next_cursor`이며 현재 ‘불러온 N개’는 로드한 범위를 뜻한다. 정확한 집계 경로를 확인·추가하기 전에는 전체 개수로 이름만 바꾸지 않는다. |
| DEC-05 | 자동분류 완료·추천 문구 | 처리 중/미분류/실제 분류 결과를 유지한다. ‘자동으로 분류했어요’를 무조건 표시하지 않는다. Today/Weekly는 현재 추천 정책과 연결 범위를 따른다. 연관 콘텐츠의 서버 선정과 미확정 상태 표현은 별도로 확인한다. |
| DEC-06 / 일부 확정 | 설정 목적지·정렬 기준·고객지원/알림 운영 | 이번 아카이브 카테고리 목록의 설정은 사용자 확정으로 기존 카테고리 관리에 연결하고 마이의 기존 진입을 유지한다. 카테고리 정렬 메뉴/카테고리순 의미·실제 알림 옵션/저장 범위·문의 접수·약관 원문/시행일은 미확정이다. Figma 임시 날짜·예제 문구를 운영 값으로 사용하지 않는다. |
| DEC-07 / 확정 | Page 1 하단 바 `111:3680`은 96px 프레임이며 D07 컨텍스트에도 그려진 인디케이터가 있음 | 사용자가 선택한 `64 + fontExtra + MediaQuery.viewPaddingOf(context).bottom` 한 번 합산을 유지한다. 실제 OS 표시를 사용하고 키보드 높이를 더하거나 가짜 선을 복구하지 않는다. 저장 화면도 버튼 아래 32px + `max(viewInsets.bottom, viewPadding.bottom)` 한 번 적용 기준을 유지한다. 두 줄 라벨·확대 높이·최근 카테고리 한 줄 말줄임 기준도 유지한다. |
| DEC-08 / 확정 | D07 `111:4814`의 예제 확대/잘림과 실제 사진의 비율·전체 노출 | 사용자는 원본 비율을 유지해 사진 전체가 보이는 방향을 선택했다. 입력 프레임 안에서 `BoxFit.contain`·`Alignment.center`로 균일하게 확대/축소하고 남는 공간은 기존 흰 배경을 쓴다. 원본 바이트/파일명을 변환하지 않으며 확대·이동·크롭 편집은 추가하지 않는다. 결과 요약/썸네일의 기존 중앙 cover는 이 결정과 분리해 유지한다. |

정책 근거: [카테고리 삭제 안내](../../frontend/lib/shared/category/category_sheets.dart),
[삭제 서비스](../../backend/app/services/category_service.py),
[인증 흐름](../../frontend/lib/app/app_view_model.dart),
[피드 응답](../../backend/app/schemas/feed.py),
[저장 흐름](../../frontend/lib/features/content/save_content_screen.dart),
[기존 진행 기록](../fe-merge-fixes.md)의 ‘PR 5 시작 — 2026-10-06’과 ‘PR 5 구현·검증 — 2026-10-06’.

#### 디자인 확인 필요

Android 종료 확인은 전용 Figma 원본이 없다. 사용자가 2026-10-22 기존 확인 팝업 표현 재사용과 ‘앱을 종료할까요?’·‘취소/종료’를 승인했다. 홈·일반 로그인·소개에서만 적용하며 새 그림/설명은 추가하지 않는다. 전용 원본은 미확보로 유지하고 [이번 동작·검증 기록](../figma-ui-alignment-plan.md#android-system-back-20261022)과 구분한다.

아래 목록은 기존 Page 1 확인 기록과 사용자 확정 기준을 유지한다. 이번 정리는 새로운 메타데이터 조회가 아니다.
기본 프레임·상세 컨텍스트의 확보, 적용 완료 기록, 상태별 디자인·데이터 계약 확정은 서로 다르다.
아래의 과거 적용·검증 완료는 이번 Page 1 기기 검증을 뜻하지 않는다.

| 대상 화면·상태 | 필요한 디자인/계약 | 관련 Figma 노드 | 보류한 구현 범위와 영향 |
| --- | --- | --- | --- |
| 별도 원문 시트(후속)·기존 SVG 오류 해결 | 새 시트를 추가하려면 확정 디자인·정확한 원본이 필요하다. | F02 `111:3842`·F03 `111:3771`; 별도 시트 원본 미확인 | 2026-10-21 사용자 확정으로 링크는 기존 아이콘에서 외부 앱/브라우저를 직접 연다. 링크 시트와 손상 instagram.svg를 제거해 XML 오류를 해결했다. 사진 원본 시트는 유지하며 새 브랜드 아이콘/시트는 만들지 않았다. |
| F01 일반 카테고리의 미확정 상태 | 빈 목록·미조회·로딩·오류·카테고리 메타정보 미확인의 상태별 원본, 새 정렬 메뉴 디자인 | F01 `111:3968`; 별도 상태 원본 미확보 | 이번은 정상 목록1배율이다. 기존 상태 안내·복구와 최신순/북마크 우선 팝업을 유지한다. ID로 확인되지 않은 색상을 임의 추정하지 않으며, 실제 전체 집계·새 정렬 옵션·새 확대와 다시보기 순서/진행 복원은 별도다. |
| 일반 A02 약관 블록 | 운영 문안·시행일·정확한 링크/동의 정책 | A02 약관 `111:3419`, K05 `111:4629`, DEC-06 | 이번 승인 범위에서 블록/새 문구/링크를 추가하지 않는다. 일반 로그인 외형 맞춤을 약관 적용이나 동의 정책 완료로 보고하지 않는다. |
| 로그인의 일반 외 상태·새 확대 | 계정 연결/onBack/공급자 없음·승인 A03/A04/A05 이외 오류·확대의 상태별 확정 표현 | A02 `111:3407`, A05 `111:5897`, J02 `111:4533`; 그 밖의 전용 원본 미확인 | 일반 진입 `!linkingGuest && onBack == null && providers.isNotEmpty`의 A02와 승인된 발급 전 A05를 구분한다. 일반 소셜 요청의 발급 전 진행/SDK 취소에는 A03/A04를 적용했다. 계정 연결/onBack/공급자 없음·공유 차단/발급 후 저장·Apple 정보/초기화 오류는 기존 경로를 유지하며 A05로 통합하지 않는다. |
| A05 오류 계약·문의 목적지·A05-1 실제 계정 정보 | 운영 지원/안정적인 오류 코드, 실제 연결 대상 정보와 원본 단일 버튼의 계약 | A05 `111:5897`, A05-1 `125:3704`/설명 `125:3728`, K04 `111:4626` | A05의 실제 상태/확인 불가·기존 mock 문의는 유지한다. A05-1은 승인된 기존 게스트 연결409에서 중립 제목·기존 데이터 경고·두 선택만 사용하고 원본의 대상 계정 카드/예제 공급자·가입일은 표시하지 않는다. 실제 대상 조회·원본 단일 버튼 동선·운영 문의/전송·안정적인 오류 코드·그 밖의 연결/발급 후 복구 디자인은 보류한다. |
| C02 안내·공지 카드 및 상세 | K02·K03 본문은 추후 작성 예정이며 상태별 표현도 미정. 본문·카드/상세 구성·표시 상태 확정 | C02 `111:3681`, K02 `111:4667`, K03 `111:4683` | 이번 승인1배율 범위에서도 새 카드/상세 연결을 보류하고 최근 카테고리2개·기존 고정 날짜/이동을 유지한다. 빈 안내의 단일 본문/자연 줄바꿈은 원본 두 문단과 다르며 고정 알림 점도 추가하지 않는다. C02 전체 구조 일치로 보고하지 않는다. |
| 홈 필터 결과 없음 | 전체 저장 콘텐츠 0개와 필터 결과 0개의 구별 및 안내·동선 | C01 `111:3584`, C02 `111:3681`; 전용 확정 노드 미확인 | 필터 빈 목록의 기존 표현 유지. 필터가 적용된 목록만 보고 새 C02를 표시하지 않는다. |
| 홈 북마크 대기 중 카드 이동/비활성 별 탭 | 요청 대기/실패 중 부모 카드 이동 허용·탭 전파·복귀 위치의 확정 정책 | C01 `111:3584`, 최근 카드 `111:3623`; 처리 중 전용 원본 미확인 | 기준 제품의 양 플랫폼에서 비활성 별 재탭이 부모 상세로 전달됨을 확인했다. PUT중복은 차단되지만 상세/열람 요청과 홈 unmount·복귀 rail0이 가능하다. 이번 외형 범위에서 새 이동 잠금/복원 정책을 추가하지 않고 별도 관찰 기록으로 분리한다. |
| 홈 최초 로딩(확정·적용)·스켈레톤 설명의 경계 | 사용자 확정: 세션 확보 뒤 홈 최초 초기화와 첫 성공 전 수동 재시도만 전면 프레임. 스켈레톤·일반 재조회는 이번에 적용하지 않음 | 원본 `125:4105`, 설명 `125:4119`·본문 `125:4122` | 최초 조회의 승인된1배율 전면 캐릭터·세 점을 적용·검증하고 기존900ms/카테고리→홈 피드→사용자→통계와 복구 중 Apple 확인의 완료 시점을 유지한다. 토큰 읽기·OAuth 대기·신규/게스트 온보딩·계정 연결·첫 성공 뒤 재조회는 제외한다. 설명 레이어명 B05/내부 C01 불일치와 과거 미확정 기록은 보존하며 오류·필터/추가 조회의 별도 디자인은 계속 보류한다. |
| 홈 오류·미조회 | 첫 조회 실패·재시도·미조회 상태와 최초 로딩/재조회 구분 | C01 `111:3584`, C02 `111:3681`; Page 1 L-M01 `120:4881`은 구조만 확인 | 오류 보완안의 상세·채택·복귀 동선이 확정될 때까지 기존 표현을 유지한다. 이전 파일 L-M01의 조회·제안 기록을 새 기준 검증으로 사용하지 않는다. |
| 추천·공지 목적지 및 알림 상태 | Today는2026-10-21 사용자 확정으로 버튼 조회→최대5개 상세 탐색을 연결했다. Weekly 카드·실제 노출·추천 카테고리 이동은2026-10-21 승인 범위로 연결했다. 운영 추천 품질·공지 목적지·읽지 않은 알림은 후속이다. | C01 `111:3584`, C02 `111:3681`, K02 `111:4667`, K03 `111:4683` | 새로운 추천 빈/오류 디자인 대신 승인된 기존 SnackBar를 사용한다. Today 조회·버튼·상세를 카드 노출로 기록하지 않으며 고정 알림 점·미확정 공지 본문을 만들지 않는다. |
| 마이·콘텐츠 상세 본문의 글자 배율 2 | 고정 높이·행 배치 안의 확대 문구와 메타데이터/페이지 이동 영역 | J01 `111:4707`, F02 `111:3842`; 확대 전용 디자인 미확인 | 1배율 우선 결정에 따라 새 확대 배치는 후속으로 둔다. 기존 확대 구현·자동 검사는 유지하며 과거 하단 탭 검사를 전체 본문 통과로 보고하지 않는다. |
| 마이·계정 관리의 공급자/미확정 상태 | 공급자별 원본·복수/미연결/게스트/확인중 표시 계약 | J01 `111:4707`, J02 `111:4533` | J01의 이름 아래 기존12px 계정 문구는 유지한다. J02 승인 외형은 실제 문구14px·자연 줄바꿈/높이 확장으로 적용했다. 카카오 포함 모든 배지/브랜드와 원본 없는 상태별 전용 표현은 후속이며 문구 파싱/연결 상태 추정은 추가하지 않는다. |
| 로그아웃 확인의 원본 없는 로딩/오류 표현 | 대기·일반 실패·보안 복구 상태의 별도 확정 디자인 | J03 `111:5767`; 상태별 원본 미확인 | J03 기본 문구/색상·기존 오류 SnackBar를 유지하고 busy 입력만 잠근다. 일반 실패는 확인 화면/수동 재시도, 로컬 세션 삭제 실패는 기존 복구 화면을 우선한다. 새 스피너·실패 전용 화면·새 확대를 임의 추가하지 않는다. J02 자체 시스템 복귀 개선과 구분한다. |
| 계정 관리 연결·복구·탈퇴·시스템 복귀 | 실제 연결 상태 계약·재확인 실행 정책·탈퇴 API/절차·시스템 뒤로가기 | J02 `111:4533`, J04 `111:5780`, J05 `111:5824`, J06 `111:5756` | true/false/null 및 busy의 기존 동작과 연결 취소·헤더 뒤로→마이를 유지한다. J02 시스템 뒤로는 승인된 마이 복귀를 적용했다. 정보 재확인의 새 단일 실행/인증 정책·회원 탈퇴 구현은 보류한다. 승인된 A05-1 경고의 소유 상태/중복 선택 방어는 그 별도 적용 범위다. 기존 확대 자동 검사는 유지하며 J02 본문 확대 완료로 보고하지 않는다. |
| 마이 실제 설정·고객지원·버전 | 실제 알림/권한 저장·공지/문의·약관 운영 문안/목적지와 네이티브 버전 조회 | J01 `111:4707`, K01 `111:4592`, K05 `111:4629`, DEC-06 | 관리/고객지원의 확정 순서와 user.appVersion을 유지한다. 실제 루트의 공지만 K01 별도 목록으로 연결하고 My callback 미주입 시 기존 NoticeSheet fallback을 보존한다. 다른 시트·약관 메뉴/실제 운영 기능/네이티브 버전 조회는 보류한다. |
| 공지 목록의 실제 데이터·상세·새 상태 | 게시일/고정 여부·운영 제목/순서·데이터/API와 상세 본문/목적지·로딩/오류/빈/확대 표현 | K01 `111:4592`, K02 `111:4667`, K03 `111:4683` | K01 승인 범위는 기존 mock 제목3개의 읽기 전용 목록이다. 날짜·핀·화살표·상세 연결을 추가하지 않으며 K02/K03 미작성 본문을 추정하지 않는다. 원본 예제를 운영 데이터로 채우거나 공지 전체 기능 완료로 표시하지 않는다. |
| 기존 소개3장의 낮은 viewport 넘침 | 현재 소개3장 원본과 낮은 높이의 글자/페이지/버튼 배치 | Page 1 `0:1` >261007 `111:3379`에서 소개3장 대응 원본 미확인 | K01 이동 검사 중320×480px에서 기존 소개 흐름의 RenderFlex 아래297px 넘침을 확인했다. 소개는 수정하지 않았으며 인증/소개 구간만 기본812px 높이로 실행하고 My/공지480px 검사는 유지한다. 낮은 소개 레이아웃의 통과로 보고하지 않는다. |
| 상세의 실제 원문·미디어(외부 열기 적용) | 전문 텍스트/미디어·썸네일 계약 | F03 `111:3771`, F02 `111:3842` | 원본 URL의 실제 OS 외부 열기·실패 안내·성공 후 통계는 2026-10-21 적용했다. `contentFromApi.originalText`의 요약 재사용은 유지하며 실제 기사 전문을 확보했다고 표시하지 않는다. 사진 인증 다운로드·contain·재시도를 보존한다. |
| 상세 연관 선정·전체 빈 상태 | 계정 전체 추천·태그/복수 소속 기준·페이지 밖 데이터/오류의 의미 | F02 `111:3842`, F04 `111:3909`, DEC-04·DEC-05 | 기존 같은 첫 카테고리 이름·불러온 순서를 유지한다. 사용자 확정 문구 ‘불러온 목록에 연관 콘텐츠가 없어요.’만 적용하고 미연결 추천을 약속하는 보조 문구는 보류한다. 전체 계정에 연관 콘텐츠가 없다고 판단하거나 실제 추천 API 연결 완료로 보고하지 않는다. |
| 상세 제목 폭의 부모 영역 초과 | Figma 제목343px/부모327px의 오른쪽 확장 의도 | F02 제목 `111:3851`, F03 제목 `111:3780`, F04 제목 `111:3918` | 기존 좌우24px과 실제 가용 폭·전체 내용 표시를 유지한다. 375px을 기기에 강제하거나 제목을 부모 밖으로 확장하지 않으며 절대 좌표 전체 일치로 보고하지 않는다. |
| 상세 페이지 이동 영역 — 현재 원본 적용 | F02/F0416px·F03 펼침8px, 원본 화살표28/32px·터치56px | F02 `111:3890`, F03 `111:3823`, F04 `111:3949` | 이번 독립 기록으로 실제 간격0px/기존28px 다음 아이콘 차이를 재현·수정했다. 펼침/접힘에 따라 간격을 바꾸고 실제 불러온 개수·경계/이동 잠금·공통 탭/OS 안전 영역을 유지한다. API 원문/미디어 계약과 기타 미정 디자인은 별도다. |
| 카드 다시보기 초기 빈 상태·완료 확장 | 처음부터0개인 상태와 새 완료 문구/버튼의 전용 디자인 | G02 `111:5047`, G11 `111:5275`; 초기0개 전용 원본 미확인 | G11 원본대로 소진 시 카드/진행을 숨기고 상단을 유지한다. 초기0개는 기존 EmptyStatePanel/나가기이며 새 안내·완료 동작은 추가하지 않는다. |
| 카드 다시보기 세션·진행·입력 변경 | 무작위 선정/재추첨·순서/진행 복원·입력 축소/교체·전환 잠금 계약 | G02 `111:5047`, G11 `111:5275`; 별도 상태 원본 미확인 | build별 불러온 목록 shuffle/take5·북마크 재빌드/상세 복귀 재추첨 가능·상세 복귀 index0을 유지한다. 실제 누적 열람 정의·새 세션/동기화/잠금 정책은 외형과 분리한다. |
| 카드 다시보기 모션 전체·확대 | 전환 중 회전/곡선·G03 이후 전체 모션·새 배율별 배치 | G02 `111:5047`, G11 `111:5275`; 후속 모션/확대 세부 노드 미확인 | 승인된1배율 정지 스택/기존 드래그 계약만 적용한다. 새 확대·전체 모션 완료로 보고하지 않으며 기존 확대 구현과 자동 회귀 검사는 유지한다. |
| 관심사 저장·기본 공간 생성·실제 OS 권한 | 선택값 API/저장·기본 카테고리 생성/실패/재시도 계약, 실제 권한 요청/상태/거절/설정 동선 | B01 `111:3478`, B02 `111:3530`, B03 `111:3546`, B04 `111:3562`, B05 `111:3393` | B01은 일반 로그인 위 로컬 설명과 확인 뒤 기존 인증만 연결한다. 계속하기를 실제 권한 허용으로 취급하지 않으며 권한 API·상태 추정·요청/거절 표현은 보류한다. B02~B04는 기존 로컬 선택·홈 이동이며 선택값 저장/복원·B05·기본 카테고리 생성은 추가하지 않는다. |
| 기존 온보딩 소개3장 | 현재 소개 문구/상태와 대응하는 정확한 원본·컨텍스트 | Page 1 `0:1` > `261007` `111:3379`에서 대응 원본 미확인. B01 `111:3478`은 권한 안내, B02 `111:3530`/B03 `111:3546`은 관심사 상태 | 기존 소개3장의 문구/이동은 유지한다. A01으로 작업 범위를 전환했으며 B01~B03을 소개3장으로 추정하거나 대체 디자인을 만들지 않는다. 소개 원본·실제 OS 권한·관심사 저장 계약·약관은 별도로 확인한다. 관심사1배율 외형은 아래 B02~B04 적용 기록으로 구분한다. |
| 저장 화면 하단 배치 — 사용자 기준 확정·과거 해당 범위 적용/검증 완료 | 버튼 아래 32px + `max(viewInsets.bottom, viewPadding.bottom)` 한 번 적용, 본문·버튼·토스트 분리 | D01 `111:4765`, D06 `111:4787`, D07 `111:4814`, D05 `111:4902`, D09 `111:4865` | 사용자 기준과 기존 구현을 유지한다. 이전 파일에서 D01/D07을 확보하지 못했던 하단 작업 기록은 보존한다. 현재 D07 확보 사실을 당시 누락의 소급 해소로 바꾸지 않는다. D07 표시 정책은 아래 DEC-08 적용 기록으로 분리하고 전체 배치·편집은 후속이다. |
| 저장 링크 입력의 확대 ‘붙여넣기’ 버튼 — 사용자 기준·과거 적용/검증 완료 | 글자 축소 없이 최대 두 줄·가운데 정렬, 폭64px·최소44px, URL 입력칸의 같은 자연 높이 | 현재 D01 `111:4765`, D02 `111:4945`, D03 무효 `111:4975`; 확대 전용 노드 미확인 | `52132f0`의 비교18건·원본 누락과 이후 261008 스타일 작업의 원본 확보·24쌍 비교는 각각 당시 기록으로 유지한다. 새 배율별 맞춤은 후속이다. |
| D07 사진 선택 후 내부 프레임 — 치수·여백 한정 수정 | 외곽343×437px·내부311×405px·간격16px의 실제 렌더링 재현/기기 실측 | D07 `111:4814`, 외곽 `111:4832`, 내부 `111:4833`; 정확한 원본·컨텍스트 확보 | 기존309×403px·간격17px을 제품 수정 전 검사·양 플랫폼 실제 경계로 재현했다. 외곽 테두리를 페인트 영역으로 옮겨 내부311×405px·간격16px을 적용한다. 당시 치수 검증은 아래 독립 기록을 따르며 사진 비율·잘림 정책은 그 치수 수정에 포함하지 않았다. 현재 D07 표시 기준은 DEC-08과 이번 전체 보기 기록을 따른다. |
| D07 사진 전체 보기 — 사용자 기준 확정 | 실제 선택 사진/에셋 fallback의 비율 유지·전체 노출·중앙 정렬·흰 여백 | D07 `111:4814`, DEC-08 | 기존 샘플용 위치/높이 계수와 `fill`을 제거하고 `contain`/중앙을 적용한다. 외곽437px·내부405px·사방16px 프레임과 원본 저장 입력은 유지하며, 예제 crop과의 차이는 승인 예외다. 실제 검사/새 기기 근거는 아래 이번 독립 기록을 따른다. 새 확대 맞춤/기기 비교는 후속이다. |
| 저장 결과의 사진 비율 및 잘림 — 기존 승인 유지 | 결과 중앙 cover의 적용 범위·원본 없는 다른 상태/확대 표현 | D05 `111:4902`, D09 `111:4865` | 앞선 결과 요약89px·내부57px과 썸네일의 제출 원본 bytes/중앙 cover를 유지한다. Figma 샘플과 잘림 위치가 다를 수 있는 승인 기준이며 D07 전체 보기로 바꾸지 않는다. 결과 전체 배치·카테고리 편집과 원본 없는 상태는 계속 후속이다. |
| 저장 결과 미리보기의 전체 세로 배치 | 한 줄 제목의 제목·출처 배치와 출처 최대 폭 원본 기준·그 밖의 미확정 상태 | D05 `111:4902`, D09 `111:4865` | 제목 컬럼−8px/출처 전체 컬럼·간격14px·카드→카테고리32px을 유지하고 사진89px 요약과 두 줄 제목의 결과5상태를 적용·검증했다. 사진44px 파일명 구조 보류는 이번 적용 영역으로 이동했다. 한 줄 전용 Figma·출처 최대 폭 원본 기준은 계속 확인 필요다. 두 줄 공간 강제 확보·출처 절대 위치 고정과 원본 없는 대체 디자인은 추가하지 않는다. |
| 저장 결과 카테고리의 상태별 배치·편집 | 처리 중·미분류·분류됨 안내와 편집/추가·제거·확정 시점 | D05 `111:4902`, D09 `111:4865`, DEC-03·DEC-05 | 기존 상태 문구를 유지해 짧은 안내는 제목 옆·긴 안내는 아래에 놓는 자연 Wrap8/8/중앙과 정확한 SVG를 적용·검증했다. 그룹→행16px·행55px·상세 변경 안내와 저장 시점을 유지했다. 추가/제거·편집과 읽기 전용 정책 변경은 이번 범위가 아니다. 사진 처리 중은 디자인이 없어 프리뷰에서도 실행하지 않는다. |
| E01 복수 소속·긴 카테고리 — 사용자 기준 확정 | 실제 소속을 모두 보이는 자연 Wrap와 높이 증가, 긴 이름 한 줄 말줄임·실제 색/순서 | E01 `111:4117`; 복수 소속 전용 원본 미확보 | 사용자 기준으로 Wrap8/8·최소22px와 우측 버튼의 예약 폭을 적용한다. 한 행 카드는173px이며 추가 Wrap 높이만큼 본문/선/날짜를 함께 내린다. 실제 분류를 예제 한 개로 줄이거나 새 대체 Figma를 만들지 않는다. 검증 결과는 이번 독립 기록을 따른다. |
| E01 개수·정렬의 기존 의미 | 불러온 목록과 계정 전체 집계의 구별, 기존 최신순/북마크 우선의 동작 | E01 `111:4117`, DEC-04 | API 피드는 기존 ‘불러온 N개’를 유지하고 Figma의 ‘총 6개’를 그대로 복사하지 않는다. 기존 정렬 팝업/서버 조회 순서·스크롤 초기화 정책을 보존하고 이번에는 글자와 정확한 접힌 화살표만 맞춘다. E02/E03의 읽기 전용 최신순·메뉴 보류는 별개다. |
| 카테고리 목록의 정렬 메뉴·화살표 | 정렬 선택지·기준·기본값·동작과 메뉴의 확정 디자인 | E02 `111:4133`, E03 `111:4160`, DEC-06 | 기존 읽기 전용 ‘최신순’과 시각/ID/null 정렬을 유지한다. 새 화살표·클릭/드롭다운을 임의 추가하지 않는다. |
| 아카이브의 미선택 탭 굵기 | 원본/컨텍스트에서 충돌하는 굵기의 최종 기준 | E01 `111:4117`, E02 `111:4133`, E03 `111:4160`의 전체/카테고리 탭 | E01도 기존600을 유지하고 색상/확정된 크기·간격만 맞춘다. 미선택 굵기까지 완전 일치로 표시하지 않는다. |
| 전체보기·카테고리·미분류의 미조회/오류/미확정 빈 상태 | 실제 조회 완료·집계 누락과0의 구별·오류 복구 및 상태별 원본 | E01 `111:4117`, E02 `111:4133`, E03 `111:4160`, E06 `111:4525`; 빈 미분류 `142:5097`은이번 독립 기록에서 적용 | 실제 미분류 ID의 조회 완료/소진/오류 없음/0만 빈 원본을 적용했다. 메타 집계 누락·초기 미조회·로딩/오류/추가 페이지가 있는 상태를0으로 판단하지 않으며 기존 표현/복구를 유지한다. 전체보기/일반 목록의 미확정 빈 상태와 새 미조회/로딩/오류 표현은 디자인 확인 전까지 보류한다. |
| 관리 시트의 미정 상태·배경 효과·자유 색상 선택 | 미조회/오류/전체 빈 상태의 확정 디자인, 배경 효과 적용 범위, 자유색 선택 UI/확정·취소 동작 | E04 `111:4569`, E08 `111:4236`, E09 `111:4287`, E10 `111:4376`, E11 `111:4427`·색 버튼 `111:4479`, E12 `111:4484` | E08~E12 본체1배율은 이번 독립 기록으로 적용했다. 사용자 선택으로 기존 배경 효과·8색 RGB/초기색·E09에도 무지개 버튼과 고정코랄 동작을 유지한다. 실제 자유 선택기와 미정 상태의 대체 디자인을 만들지 않는다. 삭제는 콘텐츠 보존 안내·중앙/자연 높이를 유지하는 승인 예외다. 새 확대 맞춤은 후속이다. |
| 알림 설정·문의 본문 | 실제 알림 옵션/저장 상태, 문의 입력·접수·실패 및 운영 계약 | J07 `111:4566`, K04 `111:4626`; Page 1 J-M02 `120:4576`·J-M03 `120:4599`·K-M03 `120:4769`·K-M06 `120:4836`은 구조만 확인 | 기본 본문은 미작성이다. A05의 문의는 승인 예외로 기존 mock ContactSheet의 정적 안내만 재사용하며 운영 문의 연결이나 K04 구현 완료가 아니다. 이전261008 M 제안은 별도 기록으로 보존하고 Page 1 보완안의 상세·채택·API·운영 기준이 확정되기 전 새 화면은 구현하지 않는다. |
| 알림 운영 상태·목적지 | 실제 조회/읽음/삭제/상세 이동, 로딩·오류·조회 완료0 판정, 설정 저장/권한 안내 | C03-1 `125:4173`, C03-2 `111:5410`, J07 `111:4566` | 이번에는 기존 제목/시간3개의 읽기 전용 별도 목록과 명시적 빈 위젯만 적용한다. 홈의 콘텐츠0을 알림0으로 추정하지 않으며 루트 빈 전환·고정 읽지 않은 점·행 목적지·API·운영 설정은 보류한다. 설정은 기존 ReminderSheet를 유지하며 두 원본의 공통 헤더/OS 표시와 실제 OS 여백 차이를 구분한다. |
| 약관·개인정보 실제 문안 | 운영 서비스와 일치하는 최종 문안·시행일·링크 | K05 `111:4629`, 설명 `111:5715` | 본문은 존재하지만 임시 시행일 등이 있으므로 운영 문안 확정으로 간주하지 않는다. DEC-06 확인 후 적용한다. |
| 즐겨찾기 정렬·집계·별도 상태 | 정렬 선택지/메뉴·정확한 전체 집계와 미조회/오류 등 상태별 확정 원본 | I01 `111:4091`, I02 `111:4103`, DEC-04 | 사용자 선택으로 최신순은 읽기 전용 글자만·화살표/메뉴는 보류하고 불러온 개수를 유지한다. 실제 조회 완료0만 I02를 적용하며 원본 없는 상태의 기존 안내/재시도는 유지한다. |
| 검색 기록·집계·원본 없는 상태 | 서버 동기화·정확한 전체 집계와 기록 읽기/쓰기 오류·미조회/로딩 원본 | H01 `111:3991`, H02 `111:4070`, H03 `111:4043`, DEC-04 | 기기 기록은 제출 시 추가·최신순 최대5개·개별 삭제·로그아웃 후 계정별 보존으로 확정하고 2026-10-22에 적용했다. 기록0개는 제목과 빈 목록을 유지하며 새 안내를 만들지 않는다. 읽기/쓰기 실패는 검색을 막지 않는 메모리 대응이고 새 오류 UI·서버 동기화·전체 집계·새 확대는 보류한다. |
| 공통 하단 탭 상태별 아이콘 — 1배율 적용/검증 완료 | 네 탭의 선택 채움형/미선택 윤곽형과 원본 계층 | C01 하단 `111:3680`, E01 하단 `111:4132`, I01 하단 `111:4093`, J01 하단 `111:4764` | 원본 SVG10개와 아카이브 상태의 별 좌표 차이·마이의 투명 베이스/중앙 Group을 보존했다. 새20/관련97/전체1452·양 플랫폼 각13기록의 원본/배치/동작을 검증했다. 완료는 네 탭 아이콘이며 기존 라벨/크기·OS 안전 영역·저장 버튼은 유지한다. 새 확대 맞춤은 후속이며 더하기는 별도 적용 기록을 따른다. |
| 공통 하단 저장 버튼 더하기 — 1배율 적용/검증 완료 | 동일 원본38.5px/선3px·기존 버튼 치수/탭 보존 | C01 하단 `111:3680`, E01 하단 `111:4132`, I01 하단 `111:4093`, J01 하단 `111:4764`의 `TAP_FAB`/plus | 네 보관 원본의 동일 bytes로 하단 전용 SVG를 등록했다. 일반 plus/FloatingAddButton과72px 버튼·돌출22px·색상/탭·OS 안전 영역은 유지한다. 이번 집중/관련117·전체1452·양 플랫폼 각13기록과 새 홈2쌍/영상2개로 검증했다. 현재 Figma 재조회는 transport 오류로 실패했으며19:55:59~19:56:05 KST의 정확한 원본을 사용했다. 이전 네 탭 작업의 제외 기록은 당시 범위로 보존한다. |

#### 기록과 변경 규칙

화면별 변경·Before/After/Figma 출처·플랫폼 결과·실패·한계는 같은 작업 기록에 한 번만 적습니다.
현재 화면 계약이나 확인 필요 항목이 달라질 때 이 문서를 갱신하고 해당 기록을 연결합니다.
이전 Figma 캐시는 현재 원본의 대체 자료로 사용하지 않습니다.

</details>

### 표현 정리 전 원문

적용 범위와 참조를 구체화한 문단의 원문을 보존합니다. 해당 문단의 과거 검증·미검증 문구를 새 실행 결과로 갱신하지 않았습니다.

<a id="followup-original-01"></a>

#### docs/frontend/behavior.md:35

원문 SHA-256: `f737d8185016d287ee6db3b51bd34a5e84a4983ec3dab2955213f5321474b6ee`

- 게스트의 계정 연결은 `/auth/social/{provider}/upgrade`를 사용해 기존 콘텐츠를 유지합니다.
  이미 연결된 소셜 계정으로 409가 오면 게스트 데이터를 합치지 않는다는 경고를 표시합니다.
  **기존 계정으로 전환**을 확인한 경우에만 SDK 인증부터 다시 시작합니다. 취소하면 게스트를 유지합니다.
- 계정당 소셜 공급자는 한 종류입니다. 회원 화면에 다른 공급자를 추가 연결하는 기능은 없습니다.
  Apple 계정은 이번 범위에서 iOS로만 로그인할 수 있습니다. 같은 이메일의 Google·카카오 계정을 자동으로 합치지 않습니다.
- 게스트 승격의 401은 일회용 코드를 자동 재전송하지 않고 `/users/me`로 게스트 세션을 별도 확인합니다.
  정상 게스트는 유지하며, 다시 연결하려면 새 SDK 인증부터 시작합니다.
- SDK에서 사용자가 취소하면 화면과 세션을 유지합니다. 카카오톡 취소·동의 거절은 카카오계정 로그인으로
  이어지지 않습니다. 카카오톡 미설치 또는 취소 이외의 실패 때만 계정 로그인으로 진행합니다.
- Google·카카오의 ID token을 백엔드에 전달합니다. 카카오는 OpenID Connect 설정이 필요하며
  `idToken`이 없으면 오류를 표시합니다. access token을 대신 보내지 않습니다.
- Apple은 서버 challenge의 nonce를 네이티브 인증에 전달하고 identity token·authorization code·challenge ID를
  백엔드에 전송합니다. 최초 제공되는 이름만 함께 보냅니다. 재시도와 계정 전환은 새 challenge·code를 사용합니다.
- 성공한 Apple 로그인의 사용자 식별자는 `clipback.apple_user_id`에 별도 저장합니다. 기존
  `clipback.session` JSON 형식은 유지합니다. 앱 복원·포그라운드 복귀·네이티브 취소 알림에서
  Apple credential state를 확인합니다. `revoked`·`notFound`가 확인되면 로그인 선택으로 돌아가고,
  조회 실패·로컬 식별자 없음은 취소로 판단하지 않습니다.
- 일반 로그아웃은 Clipback 세션과 기기 SDK 상태를 정리합니다. Google은 `signOut`, 카카오는
  로컬 token manager `clear`를 사용합니다. 공급자 연결 해제·동의 철회·회원 탈퇴는 하지 않습니다.

<a id="followup-original-02"></a>

#### docs/frontend/behavior.md:91

원문 SHA-256: `ccf80fd65227989d24ecaaecb3794c9cfd2c2d506b8b9385cb3eae6e0ab20aef`

- 만료된 access token으로 업로드가 401을 받으면 공통 refresh를 기다리고, 갱신 토큰 저장 시도가 끝난 뒤
  같은 계정으로 업로드를 한 번만 재전송합니다. 일반 API 요청과 겹쳐도 하나의 갱신을 공유합니다.
- 파일 바이트·파일명·카테고리·태그를 보존해 매 시도마다 새로운 multipart 요청을 구성합니다.
  복수 카테고리·태그는 각각 반복 form part로 모두 보내며, 빈 목록은 생략합니다.
- 링크·사진 저장의 최종 401은 저장된 세션 삭제 후 로그인 선택으로 돌아갑니다.
  자동 게스트 생성·다른 계정으로 재저장은 하지 않습니다. 인증 오류 이외의 저장 실패는 입력과 선택 사진을 유지합니다.
- 업로드 전송 대기와 응답 본문 수신은 각각 10초입니다. 일반 HTTP 오류·연결 실패·시간 초과에는
  자동 재전송하지 않습니다. 실패 후 사용자가 다시 저장할 수 있으며 저장 중 중복 제출은 차단합니다.
- 시간 초과·연결 종료·세션 변경은 서버 저장을 취소하지 않습니다. 서버에서 이미 저장됐다면 수동 재시도로
  중복 콘텐츠가 생길 수 있으며, 이번 변경은 서버 중복 저장 방지 기능을 추가하지 않습니다.

<a id="followup-original-03"></a>

#### docs/frontend/development.md:87

원문 SHA-256: `af1b042166132cb47b414b349cc746907cbc2e56cece5941a067053f86e7814c`

기본 분석·테스트 명령은 [README의 기본 검증](../../frontend/README.md#기본-검증)을 따릅니다. 아래는 각 테스트의 범위이며 이번 문서 정리에서 실행한 결과가 아닙니다.

<a id="followup-original-04"></a>

#### docs/frontend/development.md:89

원문 SHA-256: `ae9fa333746f207580261bce843316edd074fc1073d8ae45ed7264ea37d7e08b`

세션 복원·저장·동시 갱신 회귀 테스트는 `test/session_restore_test.dart`, `test/session_persistence_test.dart`,
`test/session_refresh_test.dart`에서 HTTP와 저장소 오류를 대체해 확인합니다.
`test/screenshot_auth_test.dart`는 실제 multipart 본문과 파일 선택 대역으로 업로드·저장 실패를 검증합니다.
`test/content_auto_category_test.dart`는 선택 없는 요청과 실제 서버 분류·YouTube 처리 상태 표시를 검증합니다.
`test/feed_pagination_test.dart`는 커서·필터·북마크 우선·실패 재시도·늦은 응답·상세 경계 탐색을 검증합니다.
`test/screenshot_asset_test.dart`와 `test/screenshot_asset_api_test.dart`는 원본 표시·다운로드 인증·시간 초과·화면 전환 경합을 검증합니다.
`test/content_mutation_test.dart`는 변경 중 잠금·실패 복구·늦은 조회·계정 전환·삭제 성공 시점과 상태 보존을 검증합니다.
삭제 응답 직후 화면에 남아 있는 카드를 눌러도 상세 열기가 거부되면 목록에 머물고, 다른 콘텐츠를 대신 표시하지 않는지도 확인합니다.
`test/category_delete_test.dart`는 삭제 안내·진행·실패 보존·전체 분류·동시 변경·늦은 응답과 조회 재시도를 검증합니다.
`test/app/account_stats_regression_test.dart`와 `test/data/user_repository_test.dart`는 프로필 재조회 시
이미 받은 서버 통계를 보존하고, 계정 초기화 때만 기존 통계를 비우는 경계를 검증합니다.
토큰 저장은 플랫폼 저장 대역과 캐시 초기화 후 읽기도 검증합니다.
실제 PostgreSQL·Chrome 검증 결과와 미검증 범위는 위 진행 문서에 별도로 기록합니다.

<a id="followup-original-05"></a>

#### docs/backend-mvp-plan.md:5

원문 SHA-256: `38775822287cdcbdbdfdda71024fc8e5f5f7c0d14752c81197072bd6a588fd2d`

- 승인 범위: iOS Apple·Google·Kakao, Android Google·Kakao. 네이버 신규 인증은 제외하고 기존 identity 데이터는 보존한다.
- 첫 실행·로그아웃·최종 인증 만료는 로그인/게스트 선택 화면으로 이동한다. 게스트 생성은 명시적으로 선택할 때만 수행한다.
- 계정당 제공자 하나를 사용하며, 게스트 승격은 사용자 ID·저장 데이터를 보존한다. 기존 계정 충돌은 경고 후 새 공급자 인증으로 계정을 전환하고 데이터를 병합하지 않는다.
- Apple은 5분 일회용 서버 challenge/nonce, 인가코드 교환, 암호화된 공급자 refresh token, 앱 복귀 credential state와 24시간 간격의 요청 시점 재검증을 구현한다.
- Kakao Native/REST audience 허용 목록을 추가하고 기존 REST API key 설정은 호환을 유지한다.
- 완료 조건: 인증·세션·충돌 자동 테스트, 전용 PostgreSQL migration/동시성 검증, Flutter 분석·테스트·Android/iOS 빌드, 설정 및 실행 문서 갱신.
- 공급자 콘솔 등록·키 설정·실제 기기 OAuth 성공은 별도 확인한다. 다중 제공자 연결·데이터 병합·웹 소셜 로그인·계정 탈퇴·스토어 출시는 이번 범위 밖이다.

<a id="followup-original-06"></a>

#### docs/content-recommendation-plan.md:16

원문 SHA-256: `5dd46e0787f2ac3aad8379d8e8643104cb72e8cf7a3c48e5509d7c616b4b9000`

기존 복수 카테고리, 영구 삭제, 별도 상세 열람 POST, 이벤트 기반 마이페이지 누적 통계를 유지한다.
자동 분류용 `CategoryRecommendationService`와 이번 재발견 추천은 별도 기능이다.
PUSH 발송, CATEGORY_RANDOM 전용 기능, 관리자 설정 화면, ML 모델, 콘텐츠 상태 체계 신설은 범위에 포함하지 않는다.

<a id="followup-original-07"></a>

#### docs/content-recommendation-plan.md:271

원문 SHA-256: `47405c7e697c5aa979a663fc7c507cc1af0084f3762bb7709768ee87564c8a9f`

| 단계 | 작업 | 검증 기준 | 상태 |
| --- | --- | --- | --- |
| 1 | DB·마이그레이션·집계 초기화 | 빈 DB 및 기존 데이터 적용, 기존 열람 수 초기화, 미확인 과거 분류 유지, 제약·삭제 호환 | 구현 — 당시 실행 결과는 작업 이력 참조 |
| 2 | 저장·열람 이벤트 수집 확장 | 모든 저장 경로의 실제 복수 분류, 반복 진입과 재시도 구분, 롤백·누적 통계 유지 | 구현 — 당시 실행 결과는 작업 이력 참조 |
| 3 | Today 선정·일별 배치·조회 API | Stage 경계, 점수·필터·추첨, 일별 유지·삭제·복귀, 동시 배치 생성 | 구현 — 당시 실행 결과는 작업 이력 참조 |
| 4 | 콘텐츠·카테고리 노출 기록 API | 실제 노출만 집계, 재시도·동시 요청 중복 방지, 열람과 분리, 사용자 격리 | 구현 — 당시 실행 결과는 작업 이력 참조 |
| 5 | Weekly 집계·카드·조회 API | 7일 경계, 고유 열람·분류 이동·삭제, 동점·중복·재발견·빈 결과 | 구현 — 당시 실행 결과는 작업 이력 참조 |
| 6 | 프론트 연동 | 실제 표시·진입, 재렌더·재시도, 카드 유형, 당일 삭제·갱신 동작 | 승인 범위 연결 — Today 상세 탐색·Weekly 카드/카테고리 이동·실제 노출·추천 유입. 운영 품질은 별도 |
| 7 | 통합 검증·문서·배포 확인 | 전체 회귀, DB migration·CI, 배포 후 저장·노출·열람 흐름을 각각 확인 | 운영 통합·공급자·실기기 확인 필요. 이번 정리에서 재검증하지 않음 |

<a id="followup-original-08"></a>

#### docs/category-recommendation-policy.md:198

원문 SHA-256: `0a93b4ef81009fae538ee5e04f1462b7a39712f0f2915d928209dcf781bd285b`

설정과 테스트 코드는 저장소 기준이며 실제 운영 설정·공급자 품질을 보장하지 않는다.
이번 문서 정리에서는 테스트나 실제 공급자 호출을 재실행하지 않았다.

<a id="followup-original-09"></a>

#### docs/railway-deployment.md:7

원문 SHA-256: `f2e1c8b3a32216b7b0656ab179485f3794bca7c89e1a9bd2d9fc846dbe905482`

이 문서는 설정·배포·백업·복구 절차입니다. 당시 배포 보고는 [과거 운영 기록](2026-09-21-railway-status.md)에 보존합니다.
실제 운영 환경의 상태는 [배포 기록](../release-process.md)과 해당 실행의 근거로 확인합니다.
이번 문서 정리에서는 운영 서비스에 접속하거나 설정을 변경하지 않았습니다.

### 후속 검증 결과

- 기존 파일 11개만 변경하고 새 저장소 파일은 만들지 않았습니다. 임시 스냅샷·검사 스크립트는 저장소 밖에서 사용했습니다.
- 대상 문서의 원문 단위 900개를 대조했습니다. 제목·앵커 131개, 현재 문서 유지 752개, 보존 기록에서 확인한 원문 17개이며 누락은 없었습니다. SQL을 포함한 코드 블록 32개는 변경 전과 동일합니다.
- Figma 원문 47개 행의 해시·현재 기준·근거 링크를 모두 대조했습니다. 화면별 확인 사항 45개와 기존 Android 전용 원본 미확보 항목을 유지했고, DEC-02~06의 미확정 계약은 확인 목록으로 분리했습니다. 치수·페이지 이동 범위가 확정된 두 행은 해당 범위로 한정합니다.
- 기존 Markdown의 앵커 2,147개를 보존했습니다. 상대 Markdown 링크 1,444건·HTML 이미지 참조 1건에서 누락 파일·앵커·중복 ID가 없었습니다. API 주요 절 목차와 두 기존 제목의 호환 앵커도 확인했습니다.
- 원문 링크 209건은 같은 대상 또는 두 API 제목의 새 앵커로 연결됩니다. 기존 절대 증거 참조 1,820건을 보존했고, 이전 이관 대조표와 로컬 AGENTS·편집기 임시 파일의 해시도 유지했습니다.
- Weekly 이력과 이 문서의 기존 본문은 바꾸지 않고 출처·후속 결과만 추가했습니다. 다른 작업 이력·이전 Figma 캐시·과거 확인일과 운영 상태는 변경하지 않았습니다. 기존 누락 증거를 복구·검증 성공으로 바꾸지 않았습니다.
- 일반 수동 링크·스크린샷 요청에 중복 방지 키를 보내지 않는 범위와 iOS Apple 지원 범위를 코드에 정적으로 대조했습니다. 네이티브 공유의 별도 중복 방지 계약은 유지했습니다. 이번 검사에서 실행한 앱·공급자 검증은 없습니다.
- 최종 diff·비밀정보 패턴 검사·`git diff --check`를 확인했습니다. 앱 테스트·빌드·시뮬레이터·실기기·실제 공급자·운영 서버·원격 CI는 문서 작업이므로 실행하지 않았습니다. 푸시·PR·병합·태그·실제 배포도 수행하지 않았습니다.
