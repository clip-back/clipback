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
