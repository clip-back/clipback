---
status: accepted
---

# 자동 요약 종류별 처리는 한 module에 모으되 worker 생성자·앱 조립·로그 이름은 그대로 둔다

자동 요약 종류(유튜브 영상·인스타그램 게시물)별 지식인 대상 판별, 작업 초기 상태, 모델, 스위치, 요약 실행, 성공 provider 이름을
`app/services/summary_kinds.py`의 종류별 adapter로 모은다. 공통 결과 타입·오류·결과 검증은 client가 import하는 말단 module
`app/integrations/summary.py`에 둔다. 이 리팩터링은 `/api/v1` 응답, DB 스키마, 로그, 환경 변수를 바꾸지 않는 것을 전제로 하며,
그 전제를 지키기 위해 아래 대안을 채택하지 않았다. 2026-11-01 설계 인터뷰에서 합의했으며, 구현 완료를 뜻하지 않는다.

## 검토한 대안

- **`main.py`에서 종류 목록을 조립해 worker에 넘기기**: worker 생성자가 종류 이름을 몰라도 되지만, `main.py`가
  operator-recovery 검사 대상이고 테스트 5곳의 생성자 호출이 바뀐다. 새 종류를 추가할 때는 어느 쪽이든 client가 앱 수명 주기의
  자원을 받아야 해서 `main.py`를 고쳐야 하므로 얻는 locality가 작다. 그래서 `SummaryWorker(session_factory, client, config,
  *, instagram_client=..., maintenance=...)`와 `enabled_kinds()`를 유지하고 worker 안에서 종류 목록을 만든다.
- **결과 검증을 worker로 모으기**: 결과 검증 실패 시 로그에 남는 값이 종류마다 다르다. 유튜브는 `provider`가 없고, 인스타그램은
  `openai`와 usage·이미지 진단을 남긴다. 검증 입력도 다르다. 유튜브는 모델 출력 JSON을 해석한 원래 값을, 인스타그램은 Pydantic이
  변환한 값을 검증하므로 숫자 문자열 같은 `category_id`의 결과가 다르다. worker로 옮기면 이 로그와 결과가 바뀐다. 검증 구현은
  한 함수로 두고, 각 adapter가 기존 파싱을 마친 값으로 지금 위치에서 호출한다.
- **로그 이벤트 이름을 종류 중립 이름으로 바꾸기**: 인스타그램 작업도 `youtube_summary_*` 이벤트를 쓰는 것은 의도된 것이다.
  운영 문서에 "이벤트 이름은 종류와 관계없이 같고 `kind`로 구분한다"는 계약이 있고, 저장소 밖 알림·검색 규칙은 확인할 수 없다.
  이름 변경은 운영 확인 뒤 별도 동작 변경으로 다룬다. 같은 이유로 `YOUTUBE_SUMMARY_ENABLED`도 유지한다. 이 스위치는 실제로
  유튜브 종류만 켜고 끄므로 이름도 맞다.
- **새 package 만들기**: operator-recovery 경로 필터가 `backend/app/**/__init__.py`를 포함한다. 기존 package에 파일을 추가한다.
- **유튜브·인스타그램의 사용자 입력 판정 통일**: 유튜브는 저장 payload의 제목·요약으로, 인스타그램은 호출자가 넘긴 사용자 입력
  여부로 덮어쓰기 여부를 정한다. 인스타그램 payload에는 메타데이터 보강값이 이미 들어 있어서 하나로 합치면 동작이 바뀐다.
  이 계산은 링크 저장 준비 정리에서 다룬다.

## 재검토 조건

세 번째 자동 요약 종류를 추가할 때, 운영 쪽에서 로그 이름 변경을 확인했을 때, 링크 저장 준비를 한 module로 정리할 때
이 결정을 다시 검토한다.
