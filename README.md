# 허투루 · Huturu

**저장한 콘텐츠를 다시 발견하고 활용하도록 돕는 콘텐츠 아카이빙·리마인드 앱**

SNS, 블로그, 유튜브에서 발견한 링크와 스크린샷을 한곳에 모으고,
분류·검색·재노출을 통해 잊고 있던 정보를 다시 꺼내 볼 수 있도록 만듭니다.

<img src="frontend/assets/figma/home-character.png" alt="허투루 캐릭터" width="96" />

`2026.05 ~ 현재` · `3인 사이드 프로젝트` · `MVP 개발 중`

## 왜 만들었나요?

유용한 콘텐츠를 저장해도 어디에 저장했는지 찾기 어렵거나, 저장했다는 사실을 잊곤 합니다.
허투루는 **저장 이후 다시 찾고 활용하는 경험**에 집중합니다.

| 구분 | 기획 과정 |
| --- | --- |
| 초기 가설 | 필요한 콘텐츠를 저장하고 분류할 수단이 부족하다 |
| 사용자 조사 | 103명 설문에서 이미 콘텐츠를 저장하지만 다시 활용하기 어렵다는 문제 확인 |
| 문제 재정의 | 저장한 콘텐츠를 다시 발견하고 활용하지 못한다 |
| 제품 방향 | 저장·분류에 재노출·재탐색 경험을 연결한다 |

## 핵심 경험

**저장 → 다시 발견 → 탐색 → 재열람**

| 경험 | 제공하려는 가치 |
| --- | --- |
| 간편한 저장 | 링크 직접 입력·공유와 스크린샷으로 콘텐츠를 한곳에 모으기 |
| 자동 분류 | AI 분류와 직접 수정으로 정리 부담 줄이기 |
| 다시 발견 | 오늘의 콘텐츠·관심 카테고리 기반 추천으로 잊었던 정보 다시 만나기 |
| 목적 있는 탐색 | 카테고리·검색·북마크로 필요한 콘텐츠 찾기 |
| 다시 활용 | 요약·원본·관련 콘텐츠를 확인하며 정보 활용으로 연결하기 |

## 기획과 팀

3인 팀의 개발 리소스 안에서 핵심 경험을 구현하도록 MVP 범위를 정하고,
PRD·IA·User Flow·화면 정책을 공통 개발 기준으로 정리했습니다.

| 담당 | 역할 |
| --- | --- |
| [정지윤](https://github.com/just-stopyoon) · PM / Product Design | 사용자 리서치, 문제 정의, MVP 우선순위, 제품 사양·화면 설계 |
| [이현규](https://github.com/leegusrb) · Backend | API·데이터 모델·인증·콘텐츠 처리 구현 |
| [박상규](https://github.com/sangkyu39) · Frontend / AI | 앱 화면·사용자 흐름·AI 알고리즘 구현 |

## 현재 개발 현황

게스트·모바일 소셜 인증과 회원 탈퇴, 링크·사진·네이티브 공유 저장과 자동 분류, 검색·카테고리·즐겨찾기, Today·Weekly 추천, 마이 통계가 연결돼 있습니다.
공지는 서버에서 받고(실패하면 마지막 목록, 아직 받은 적이 없으면 앱 안 공지 2건) 문의는 외부 폼으로 열며, 알림 전달 기능은 아직 없습니다. 운영·실기기 검증은 각 배포 기록을 따릅니다.

현재 범위는 [백엔드 MVP 현황](docs/backend-mvp-plan.md)과 [프론트 개발 안내](frontend/README.md),
작업 당시 결과와 한계는 [작업·검증 이력](docs/history/README.md)을 확인하세요.

## 앞으로 검증할 것

핵심 가설은 **저장한 콘텐츠를 다시 노출하면 실제 재열람으로 이어지는가**입니다.

- 저장 이후 다시 열람한 콘텐츠의 비율
- 추천 노출 → 콘텐츠 상세 → 원본 확인으로 이어지는 흐름
- 카테고리 탐색과 추천의 사용 패턴

백엔드에는 저장·열람·추천 노출 이벤트 수집 구조가 구현되어 있습니다.
출시 후 실제 행동 데이터를 확인하며 제품과 추천 기준을 개선할 계획입니다.
이벤트 정의와 분석 쿼리는 [제품 지표 문서](docs/product-metrics-queries.md)에 정리되어 있습니다.

## 기술 구성

| 영역 | 기술 |
| --- | --- |
| App | Flutter · Dart |
| Backend | Python · FastAPI · SQLAlchemy |
| Database | PostgreSQL · Alembic |
| 콘텐츠 처리 | 이미지 OCR · AI 카테고리 분류 · YouTube·인스타그램 비동기 요약 |
| 개발·배포 | Docker · GitHub Actions · Railway 배포 구성 |

## 저장소 구조

```text
frontend/  Flutter 앱과 화면·API 연동
backend/   FastAPI 서버, 데이터 모델, 마이그레이션, 테스트
docs/      제품 정책, 구현 현황, 지표, 배포·운영 문서
```

<details>
<summary><b>로컬 실행 안내</b></summary>

### Backend

의존성 설치와 환경 변수 준비는 [백엔드 설정 안내](backend/README.md#빠른-실행)를 따릅니다.
저장소 루트에서 PostgreSQL을 실행합니다. 호스트 포트는 `5433`입니다.

```bash
docker compose up -d postgres
```

환경 준비 후 마이그레이션과 API 서버를 실행합니다.

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
uvicorn app.main:app --reload
```

API 문서: `http://127.0.0.1:8000/docs`

### Frontend

지원 Flutter SDK, API 연결과 기기별 실행 조건은 [프론트엔드 안내](frontend/README.md)를 따릅니다.

```bash
cd frontend
flutter pub get --enforce-lockfile
flutter run
```

</details>

## 개발 문서

현재 실행·구조·API 안내는 README, 합의한 동작은 정책 문서, 상세 작업·검증 결과는 이력 폴더에서 관리합니다.
같은 작업 결과는 한 번만 기록하고 기준 문서에서는 링크로 연결합니다. 사용자용 변경 내용은 CHANGELOG,
실제 공개·배포 결과는 배포 기록으로 구분합니다.

### 시작·개발

- [백엔드 설정·실행](backend/README.md)
- [앱 구현·실행·검증 범위](frontend/README.md)
- [프론트 동작·상태 처리](docs/frontend/behavior.md)
- [프론트 설정·실행·검증](docs/frontend/development.md)
- [백엔드 API 목록·계약](docs/backend/api-contracts.md)

### 정책·디자인

- [MVP 현황·범위 결정](docs/backend-mvp-plan.md)
- [카테고리 추천 정책](docs/category-recommendation-policy.md)
- [콘텐츠 재발견 추천 설계](docs/content-recommendation-plan.md)
- [이미지 보관 정책·구현 범위 제안](docs/image-storage-policy.md)
- [제품 이벤트·지표](docs/product-metrics-queries.md)
- [YouTube·인스타그램 저장·요약·worker](docs/youtube-summary.md)
- [Figma 화면 기준·디자인 확인 필요](docs/figma-ui-alignment-plan.md)
- [시작 화면 에셋 출처](frontend/ios/Runner/Assets.xcassets/SplashA01Brand.imageset/README.md)

### 검증·운영·배포

- [백엔드 테스트·전용 DB·로컬 공유 서버](docs/backend/testing.md)
- [iOS 네이티브 공유 검증](frontend/ios/ShareVerification/README.md)
- [Android 네이티브 공유 검증](frontend/android/SHARE_TESTING.md)
- [Railway 배포·복구](docs/railway-deployment.md)
- [사용자 업데이트 내역](CHANGELOG.md)
- [업데이트 내역 작성·배포 절차](docs/release-process.md)
- [실제 배포 기록 양식](docs/releases/TEMPLATE.md)

### 협업·이력

- [Git 협업 규칙](docs/git-conventions.md)
- [에이전트 이슈 관리](docs/agents/issue-tracker.md) · [분류 라벨](docs/agents/triage-labels.md) · [도메인 문서 규칙](docs/agents/domain.md)
- [도메인 용어집](GLOSSARY.md) · [원본 이미지 보관 결정](docs/adr/0001-preserve-account-image-originals.md)
- [작업·검증 이력과 원문 이관 대조표](docs/history/README.md)
- [PR 템플릿](.github/pull_request_template.md)
- [FE 기존 경로 안내](docs/fe-merge-fixes.md)
- [이전 Figma 캐시](docs/history/2026-09-07-figma-design-cache.md)
