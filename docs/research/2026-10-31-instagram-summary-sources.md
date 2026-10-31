# Instagram 릴스·게시물 자동 요약: 정보 획득 방법 조사

- 조사·확인일: 2026-10-31 (아래 모든 URL은 이 날짜에 조회했다)
- 목적: 제품 결정 인터뷰를 위한 사실 정리. 권고안이 아니라 출처가 있는 선택지 비교다.
- 표기: **[직접 관찰]**은 이번에 curl로 직접 확인한 결과다. **[미확인]**은 1차 출처로 확인하지 못한 내용이다.
  법률 해석은 조사자의 독해이며 법률 자문이 아니다.

## TL;DR

| 방법 | 얻는 정보 | 요건 | ToS 위험 | 안정성 | 비용 |
| --- | --- | --- | --- | --- | --- |
| A. 공식 Graph API (Business Discovery) | 캡션, media_type, media_url(조건부), children, permalink, 좋아요·댓글 수 | 우리 쪽 IG 프로페셔널 계정과 Facebook Login, URL이 아니라 **username으로만** 조회, 대상이 비즈니스·크리에이터 계정이어야 함 | 낮음(공식). 다만 "남의 게시물 요약" 용도가 허용 목적인지는 [미확인] | 개인 계정 게시물은 불가. URL에서 media를 바로 찾는 엔드포인트가 없음 | API 무료, 심사·비즈니스 인증 부담 |
| B. oEmbed (`instagram_oembed`) | 임베드용 `html`과 provider 정보뿐. 캡션·썸네일·작성자 필드는 2025-11-03 제거 | 2026-05-15부터 토큰 없이 호출 가능. 시간당 1,000회 | **높음**: 문서가 프론트엔드 표시 외 용도(추출·저장·분석)를 명시적으로 금지 | 비공개·연령 제한·임베드 비활성 계정은 불가 | 무료 |
| C. 공개 페이지 HTML 메타(og 태그, 현재 방식) | og:title·og:description에 캡션 앞부분과 좋아요·댓글 수, og:image(썸네일), 일부 영상은 og:video(mp4) | 없음. 단 브라우저 UA로는 og 태그가 오지 않았음 | **높음**: ToS가 비로그인 자동 수집도 금지. robots.txt가 `*`에 `Disallow: /` | UA·IP·시점에 따라 달라짐 | 무료 |
| D. 미디어 내려받아 Gemini에 전달 | 영상·오디오·이미지 전체 | C로 얻은 CDN URL 또는 비공식 엔드포인트 | **가장 높음**: 자동 수집 금지와 다운로드 보호 우회 소지 | CDN URL 만료, 저작권 음원 릴스는 og:video 없음 | Gemini 토큰 비용 |
| E. Gemini URL context로 instagram.com 읽기 | 문서상 HTML·이미지 가능, 영상·오디오는 불가 | Gemini API | C와 같은 수집 문제에 Google 측 페처가 더해짐 | instagram.com에서 동작하는지 [미확인] | 가져온 내용이 입력 토큰으로 과금 |
| F. 유료 서드파티 스크래핑 API | 업체에 따라 캡션·미디어 | 계약 | C·D와 같은 ToS 위험 | 업체에 의존 | 유료 |
| G. 사용자 기기 공유 데이터 | 공유 시트로 받는 URL과 텍스트. 내용 정보는 [미확인] | 이미 구현 | 없음 | — | 없음 |

## 1. Instagram 공식 API

### Basic Display API 종료
- Instagram Platform 변경 로그의 2024-12-04 항목:
  "The Instagram Basic Display API has been deprecated. All requests to the Instagram Basic Display API will return an error message."
  — https://developers.facebook.com/documentation/instagram-platform/changelog.md
- 개인 계정이 서드파티 앱에 자기 미디어를 제공하던 공식 경로는 2024-12-04부터 없다.

### 현재 Instagram API 범위
- "The Instagram Platform is a collection of APIs that allows your app to access data for Instagram professional accounts, including business and creator accounts."
  — https://developers.facebook.com/documentation/instagram-platform/overview.md
- 로그인 방식은 세 가지다. 신규 통합에는 Unified Login을 권장하고, 그 밖에 Instagram Login과 Facebook Login이 있다(같은 문서).
- IG Media 조회(`GET /<IG_MEDIA_ID>`)의 제한:
  "This API returns only data for media owned by Instagram professional accounts. It can not be used to get data for media owned by personal Instagram accounts."
  — https://developers.facebook.com/documentation/instagram-platform/reference/instagram-media.md
- **URL이나 shortcode로 임의 게시물을 조회하는 엔드포인트는 공식 문서에서 찾지 못했다.**
  `GET /<IG_MEDIA_ID>`는 미디어 ID가 필요하다. 문서에는 URL·shortcode를 ID로 바꾸는 방법이 없다.

### Business Discovery
- "Allows you to get data about other Instagram Business or Creator IG Users." 조회 대상은
  `business_discovery.username(<USERNAME>)`처럼 **username으로만** 지정한다.
  — https://developers.facebook.com/documentation/instagram-platform/instagram-graph-api/reference/ig-user/business_discovery.md
- 호출은 "the Instagram Business or Creator IG User who is making the query"에서 한다. 즉 **우리 쪽에도 IG 프로페셔널 계정이 필요**하다.
- 필요 권한: `instagram_basic`, `instagram_manage_insights`, `pages_read_engagement`가 있는 Facebook User 토큰.
  Business Manager로 Page 역할을 받았다면 `ads_management` 또는 `ads_read`가 추가로 필요하다(같은 문서).
- 레퍼런스 문서는 "Available for the Instagram API with Facebook Login"이라고 한다.
  안내 문서는 Unified Login에서도 쓸 수 있다고 한다. Instagram Login 전용 권한(`instagram_business_*`)에서는 지원한다는 문구를 찾지 못했다.
  — https://developers.facebook.com/documentation/instagram-platform/instagram-api-with-facebook-login/business-discovery.md
- 제한: "Data about age-gated Instagram professional accounts will not be returned."
  비즈니스·크리에이터가 아닌 개인 계정은 조회 대상이 아니다.
- media 필드: IG Media 레퍼런스에서 `caption`(Public, "Available for Instagram API with Facebook Login only"),
  `media_type`(`CAROUSEL_ALBUM`/`IMAGE`/`VIDEO`), `media_url`, `permalink`, `thumbnail_url`(VIDEO만),
  `media_product_type`(`FEED`/`REELS` 등)이 Public이다. 필드 확장으로 읽을 수 있다
  ("Public fields can be read via field expansion"). 변경 로그도 `business_discovery{media{children}}`처럼
  캐러셀 children을 필드 확장으로 읽는 경우를 언급한다.
- `media_url` 누락 조건(2026-07-30 변경 로그, 모든 버전 적용):
  저작권·라이선스 음원이 들어간 영상(Instagram 음원 라이브러리 음원 포함)과 저작권 침해로 표시된 영상은 `media_url`이 빠진다.
  릴스 소유자가 "Allow people to download your reels"를 끈 경우에도 business discovery 같은 타인 미디어 조회에서 `media_url`이 빠진다.
  "Image media and carousel containers are not affected, though a carousel's video children can be."
  — https://developers.facebook.com/documentation/instagram-platform/changelog.md
- 특정 URL의 게시물을 찾으려면 username으로 media 목록을 페이지 단위로 넘기며 `permalink`를 대조해야 한다.
  이는 문서 내용에서 추론한 것이며, 공식 문서가 안내하는 사용 패턴은 아니다.

### 심사·접근 수준
- "Advanced Access is the access level required if your app serves Instagram professional accounts that you don't own or manage ... This access level requires App Review and Business Verification."
  자기 계정만 쓰는 앱은 Standard Access로 충분하다는 설명도 있다.
  — https://developers.facebook.com/documentation/instagram-platform/overview.md ,
  https://developers.facebook.com/documentation/instagram-platform/app-review.md
- Clipback 사용자의 계정을 연결하지 않고 운영자 계정 토큰 하나로 사용자 요청을 대신 조회하는 구성이 Standard Access의 의도("intended for apps that will only be used by people who have roles on them")와 맞는지는 [미확인]이다. 해석이 필요하다.
- Platform Terms 3.a.viii는 "Processing Platform Data for purposes other than the applicable permitted purposes set forth in Meta's Developer Docs"를 금지한다(§4 참조). Business Discovery 문서는 용도를 "get basic metadata and metrics about other Instagram professional accounts"라고만 설명한다. 요약 생성이 허용 목적인지는 [미확인]이다.

## 2. oEmbed

- 문서: https://developers.facebook.com/documentation/instagram-platform/oembed.md
  (레퍼런스: https://developers.facebook.com/docs/graph-api/reference/instagram-oembed/)
- **토큰**: 2026-05-15 변경 로그는 "You can now call Instagram oEmbed API without an access token."라고 한다(모든 버전).
  — https://developers.facebook.com/documentation/instagram-platform/changelog.md
  - 반면 기능 레퍼런스 "Meta oEmbed Read"(2025-04-08 도입, 기존 oEmbed Read는 2025-11-03 폐지)에는 아직 앱 검수와 비즈니스 인증이 필요하다는 문구가 남아 있다.
    — https://developers.facebook.com/docs/features-reference/meta-oembed-read
    토큰 없는 호출에도 이 요건이 적용되는지는 [미확인]이다.
- **요청 한도**: "You can make up to 1,000 requests every hour."
- **현재 응답 필드**: 레퍼런스의 기본 필드는 `html`, `provider_name`, `provider_url`, `type`, `version`, `width` 6개뿐이다.
  - 2025-04-08 공지: "The `author_name`, `author_url`, `thumbnail_url`, `thumbnail_width`, and `thumbnail_height` fields will be removed from the ... Instagram post oEmbed response ... on November 3, 2025."
  - `title`(캡션) 필드는 현재 레퍼런스에 없다. 제거 시점을 명시한 1차 출처는 찾지 못했다 [미확인].
- **[직접 관찰]** `https://graph.facebook.com/v26.0/instagram_oembed?url=https://www.instagram.com/p/fA9uwTtkSN/`를
  토큰 없이 호출하자 HTTP 200이 왔다. 키는 위 6개였다. `html`(약 6.4KB)의 텍스트는
  "View this post on Instagram"뿐이었고 캡션 본문은 없었다. 캡션은 embed.js가 브라우저에서 렌더링하는 것으로 보인다.
- **지원 URL**: `/p/{shortcode}/`(단일 이미지·캐러셀), `/reel/{shortcode}/`(영상·릴스), 프로필.
  "Posts on private, inactive, and age-restricted Instagram accounts are not supported." 임베드를 끈 계정과 Stories도 지원하지 않는다.
  `/tv/`는 문서에 언급이 없다.
- **사용 제한(원문)**:
  > The Instagram oEmbed endpoint is **only** meant to be used for embedding Instagram content in websites and apps. It is not to be used for any other purpose. **Using metadata and page, post, or video content (or their derivations) from the endpoint for any purpose other than providing a front-end view of the page, post, or video is strictly prohibited**. This prohibition encompasses consuming, manipulating, extracting, or persisting the metadata and content, including but not limited to deriving information about pages, posts, and videos from the metadata for analytics purposes.
- 결론적 사실: oEmbed로 요약에 쓸 데이터를 얻는 것은 문서상 금지된다. 앱 상세 화면에 원본 게시물을 임베드해 보여주는 용도는 허용 범위다.

## 3. 공개 페이지 HTML 메타데이터 (현재 Clipback 방식)

현재 구현(`backend/app/integrations/metadata_client.py`)은 UA `ClipbackBot/0.1`로 GET한다.
리다이렉트는 3회, 응답은 1MB, 시간은 5초로 제한한다. 제목은 `og:title` → `twitter:title` → `<title>` 순서로,
설명은 `og:description` → `twitter:description` → `description` 순서로 고른다. `og:image`·`og:video`는 읽지 않는다.

**[직접 관찰]** (2026-10-31, 로컬 개발 머신 네트워크, Instagram 요청 7회)
- `https://www.instagram.com/p/fA9uwTtkSN/`(2015년 영상 게시물)
  - UA `ClipbackBot/0.1`과 `facebookexternalhit/1.1`: HTTP 200, 약 554KB. 서버 렌더링된 메타 태그가 있었다.
    - `og:title`: `Diego Moreno Quinteiro on Instagram: "Wii Gato (Lipe Sleep)"`
    - `og:description`·`description`: `3,695 likes, 70 comments - diegoquinteiro on June 16, 2015: "Wii Gato (Lipe Sleep)".`
    - `og:image`: `scontent-*.cdninstagram.com/...jpg?stp=..._s640x640...` (640px 썸네일, 서명 쿼리 포함)
    - `og:video`·`og:video:secure_url`: `scontent-*.cdninstagram.com/o1/v/...mp4?...`, `og:type=video`
    - `og:url`: `https://www.instagram.com/diegoquinteiro/reel/fA9uwTtkSN/`
  - 데스크톱 Chrome UA: HTTP 200, 약 508KB. **og 태그가 전혀 없는** JS 셸이었다.
- `https://www.instagram.com/reel/DKcalTzoftf/`(2025년 릴스, 공개 계정), UA `ClipbackBot/0.1`
  - og:title·og:description에 캡션 전문(짧은 캡션)과 "38K likes, 369 comments"가 있었다. og:image는 있었다.
  - **og:video는 없었고** `og:type=article`이었다. 저작권 음원 영향인지는 [미확인]이다.
  - 페이지 내 JSON의 `"caption"`은 null이었다.
- `https://www.instagram.com/instagram/`(프로필), 브라우저 UA: og 태그와 게시물 링크가 없었다.
- `/reel/DKcalTzoftf/embed/captioned/`(문서화되지 않은 임베드 페이지): HTML 안에 캡션 텍스트가 있었다.

정리와 주의
- 요약에 쓸 수 있는 정보는 캡션(og:description에 일부 또는 전부), 작성자 username, 게시일, 좋아요·댓글 수, 대표 이미지 1장이다.
  영상 본문·음성·캐러셀의 2번째 이후 장은 메타 태그에 없다(관찰한 범위 기준).
- 긴 캡션의 잘림 여부와 캐러셀의 og:image 선택 규칙은 이번 표본(짧은 캡션 2건)으로는 [미확인]이다.
- 결과는 UA, 요청 IP, 시점, 계정 설정에 따라 달라질 수 있다. 데이터센터 IP(Railway 운영 서버)에서 로그인 벽이나 차단이 생기는지는 [미확인]이다. 이번 관찰은 로컬 네트워크에서 소량 요청한 결과일 뿐이다.
- `https://www.instagram.com/robots.txt` **[직접 관찰]** 첫머리:
  > Collection of data on Instagram through automated means is prohibited unless you have express written permission from Instagram and may only be conducted for the limited purpose contained in said permission. All authorized user-agents listed on this page must comply with Meta's Automated Data Collection Terms

  `User-agent: *`에는 `Disallow: /`가 있다. `Google-Extended`, `GPTBot`, `ClaudeBot` 등도 전체 Disallow다.
  `facebookexternalhit`과 `Googlebot` 같은 허가된 UA만 일부 경로를 허용받는다. `ClipbackBot`은 `*` 규칙에 해당한다.

## 4. 약관

### Instagram 이용 약관 (Terms of Use)
- 공식 페이지 https://help.instagram.com/581066165581870 은 JS로 렌더링돼 직접 추출하지 못했다.
  아래 문구는 Open Terms Archive가 2026-10-30에 기록한 사본에서 인용했다.
  — https://github.com/OpenTermsArchive/contrib-versions/blob/main/Instagram/Terms%20of%20Service.md
  - 4.2: "**You can't attempt to create accounts or access or collect information in unauthorized ways.** This includes creating accounts or accessing or collecting information in an automated way without our express permission, regardless of whether such automated access or collection is undertaken while logged-in to an Instagram account."
  - 4.2: "**You can't sell, license, or purchase any account or data obtained from us or our Service, regardless of whether such data was obtained while logged-in to an Instagram account.**"
  - 4.2: "**You can't do, or attempt to do, anything to circumvent, by-pass, or override any technological measures that control or limit access to the Service or data.**"
  - 4.2: Meta Platform Terms and Developer Policies 위반도 금지한다.
- 같은 사본 상단에 "We're updating our Terms of Use. These updates go into effect on January 20, 2027."라는 공지가 있다.
  새 약관(https://help.instagram.com/2159268501666222)의 내용은 [미확인]이다.
- 참고(2차 출처): 2024-01 Meta v. Bright Data 판결은 당시 약관이 로그아웃 상태의 공개 데이터 스크래핑을 금지한다고 해석할 수 없다고 봤다
  (TechCrunch https://techcrunch.com/2024/01/24/court-rules-in-favor-of-a-web-scraper-bright-data-which-meta-had-used-and-then-sued).
  현재 약관에는 위와 같이 "regardless of whether ... logged-in" 문구가 있다. 이 문구가 언제 추가됐는지는 [미확인]이다.

### Meta Automated Data Collection Terms
- https://www.facebook.com/legal/automated_data_collection_terms ("Effective October 7, 2024")
  - "You will not engage in Automated Data Collection without first obtaining Meta's express written permission"
  - 약관에 동의하는 것만으로는 허가가 되지 않는다. 허가는 "must be obtained separately through Meta's formal authorization process"로 받아야 한다.
  - 수집 데이터의 이전·판매·라이선스를 금지한다. 계열사를 포함한 제3자 제공도 금지한다.
  - "Automated Data Collection"의 정의: "the collection of data from Meta Company Products via the use of automated or programmatic tools"
  - Instagram이 "Meta Company Products"에 포함되는지는 이 페이지 안에서 직접 정의하지 않는다(Facebook 약관 정의를 따름).
    다만 Instagram robots.txt가 이 약관을 명시적으로 참조한다.

### Meta Platform Terms (API로 얻은 "Platform Data"에 적용)
- https://developers.facebook.com/terms/dfc_platform_terms/ ("Last updated February 3, 2026")
  - 정의: "any information, data, or other content you obtain from us, through Platform or through your App"
  - 3.a 금지 행위: iv "Selling, licensing, or purchasing Platform Data.", v "Processing Platform Data without valid User consent in order to build or augment user profiles", viii "Processing Platform Data for purposes other than the applicable permitted purposes set forth in Meta's Developer Docs."
  - AI·머신러닝·모델 학습을 직접 언급한 조항은 **찾지 못했다**. 관련 가능성이 있는 것은 v와 viii다.
  - 5.a 서비스 제공자(예: Gemini를 처리자로 쓰는 경우): 서비스 제공자는 사전에 서면으로 "Use Platform and Process Platform Data solely for you and at your direction ... for no other individual or entity and for no other purpose, including for the Service Provider's own purposes"에 동의해야 한다.
    Gemini 무료 등급은 입력을 제품 개선에 쓴다(§5). 이 조건과 충돌할 소지가 있다는 것은 조사자의 해석이다.
  - 3.d 보존: 정당한 사업 목적에 더는 필요하지 않거나 사용자가 삭제를 요청하면 삭제해야 한다.
- Meta Developer Policies (https://developers.facebook.com/devpolicy/ , "Last updated February 3, 2026")
  - 6.1 "Comply with any requirements or restrictions imposed on usage of Instagram user photos and videos"
  - 6.2 "Don't use the Instagram Platform to simply display User Content, import or backup content" without Meta's prior permission.

## 5. Gemini API

- **영상 입력 방법**(https://ai.google.dev/gemini-api/docs/video-understanding , 2026-10-13 갱신)
  - File API(유료 20GB, 무료 2GB), GCS 등록(파일당 2GB), 인라인(<100MB. 본문에는 "under 20MB total request size"라는 문구도 있어 문서 안에서 불일치), YouTube URL.
  - YouTube URL은 "You can only upload public videos". 무료 등급은 하루 8시간 제한이 있고, 2.5 이후 모델은 요청당 최대 10개다. 미리보기 기능이며 무료다.
  - YouTube 외에 **instagram.com 같은 플랫폼 페이지 URL을 영상 입력으로 받는다는 문구는 없다.**
- **외부 URL 입력**(https://ai.google.dev/gemini-api/docs/file-input-methods , 2026-10-07 갱신)
  - "You can pass publicly accessible HTTPS URLs or pre-signed URLs directly in your request." 파일당 최대 15MB이고 요청 시점에 가져온다. Gemini 2.0 계열은 지원하지 않는다.
  - 지원 MIME에 video/mp4, image/jpeg, text/html 등이 있다. 문서 예시는 `uri`와 `mime_type`을 함께 넘긴다.
  - 로그인·유료 장벽 URL은 피하라고 안내한다. 안전성 검사에 걸리면 `URL_RETRIEVAL_STATUS_UNSAFE`가 반환된다.
  - 기술적으로는 og:video의 CDN mp4 URL(15MB 이하)이나 og:image를 넘길 수 있어 보인다. 실제 호출 검증은 하지 않았다 [미확인].
    이 경우 수집 주체는 Google 페처지만, Clipback이 메타 태그에서 URL을 자동 추출하는 단계는 그대로 남는다(§4).
- **URL context 도구**(https://ai.google.dev/gemini-api/docs/url-context , 2026-10-13 갱신)
  - Gemini 3.5 Flash-Lite를 지원한다. 요청당 URL 20개, URL당 34MB까지다.
    지원 형식은 HTML·JSON·텍스트·PNG/JPEG/BMP/WebP·PDF다.
    **비지원**은 유료 장벽 콘텐츠, YouTube, Google Workspace 파일, "Video and audio files"다.
  - 공개 URL만 되고 로그인 필요 페이지는 피하라고 안내한다. 내부 인덱스 캐시를 먼저 보고, 없으면 실시간으로 가져온다.
  - 소셜 미디어·instagram.com에 대한 언급은 없다. 실제로 동작하는지, 페처 UA가 무엇인지(robots.txt의 `*`·`Google-Extended` Disallow 적용 여부)는 [미확인]이다.
    URL context로는 릴스의 영상·음성을 분석할 수 없다(영상 비지원).
- **이미지 입력**(https://ai.google.dev/gemini-api/docs/image-understanding , 2026-09-23 갱신)
  - 이미지 한 장은 양변 ≤384px이면 258토큰이다. 더 크면 768×768 타일 하나당 258토큰이다. 요청당 최대 3,600장이고, 인라인 요청은 총 20MB까지다.
    Gemini 3는 `media_resolution`으로 토큰 상한을 조절한다.
- **영상 토큰**: 1FPS로 샘플링한다. 프레임당 66토큰(low) 또는 258토큰이고, 오디오는 초당 32토큰이다. 기본 설정에서 약 100토큰/초다(video-understanding 문서).
- **가격**(https://ai.google.dev/gemini-api/docs/pricing , 2026-10-30 갱신): `gemini-3.5-flash-lite` 유료 입력은 1M 토큰당 $0.30(텍스트·이미지·영상·오디오 동일), 출력은 $2.50다. 무료 등급이 있다.
  URL context 도구 자체는 무료이고, 가져온 내용은 입력 토큰으로 과금한다.
  예: 60초 릴스는 약 6,000 입력 토큰이고 입력 비용은 약 $0.0018이다(문서 수치로 계산한 추정).
- **데이터 사용**(https://ai.google.dev/gemini-api/terms , 2026-04-28 갱신): 무료(Unpaid) 서비스는 "Google uses the content you submit ... to provide, improve, and develop"이다.
  유료 서비스는 프롬프트를 제품 개선에 쓰지 않는다.

## 6. 기타 방법

- **미디어 다운로드 후 Gemini 전송**
  - 기술: §3에서 관찰했듯 비로그인 HTML에도 og:video(mp4)와 og:image CDN URL이 있는 경우가 있다.
    그 URL을 내려받아 File API·인라인으로 보내거나 외부 URL로 넘길 수 있다. 다만 저작권 음원 릴스로 보이는 사례에서는 og:video가 없었다.
    CDN URL에는 서명·만료 쿼리가 있다(`oe=` 등; 만료 동작 [미확인]). 캐러셀 2번째 이후 장은 메타 태그로 얻을 수 없었다.
  - 약관: Instagram ToS 4.2의 자동 수집 금지와 기술적 접근 통제 우회 금지(§4), Automated Data Collection Terms가 해당될 수 있다.
    공식 API도 2026-07-30부터 다운로드를 끈 릴스와 저작권 음원 영상의 `media_url`을 숨긴다(§1). 이 보호를 비공식 경로로 우회하는 형태가 된다는 것은 조사자의 해석이다.
- **유료 서드파티 스크래핑 API**: Instagram 게시물·릴스 데이터를 파는 스크래핑 서비스가 존재한다.
  예: Bright Data, Apify의 Instagram 스크래퍼. 상세 조사는 하지 않았다.
  Instagram ToS의 "can't sell, license, or purchase any ... data obtained from us or our Service" 조항과 자동 수집 금지에 걸릴 위험이 있다.
  판매자·구매자 모두에게 해당할 수 있다는 것은 조사자의 해석이다.
- **Instagram 임베드 페이지**(`/embed/captioned/`): HTML에 캡션이 있었다 [직접 관찰]. 문서화되지 않은 경로라 C와 같은 위험이 있다.

## 7. 사용자 기기가 공유하는 데이터

- Instagram 앱이 iOS·Android 공유 시트에 무엇을 넘기는지(URL만인지, URL과 텍스트인지, 미디어도 넘기는지) 설명한 **공식 문서는 찾지 못했다 [미확인]**.
- 저장소에서 확인한 사실:
  - iOS Share Extension 활성화 규칙(`frontend/ios/ShareExtension/Info.plist`): `NSExtensionActivationSupportsText`, `NSExtensionActivationSupportsWebURLWithMaxCount=1`, `NSExtensionActivationSupportsImageWithMaxCount=1`.
  - Android(`frontend/android/app/src/main/AndroidManifest.xml`): `android.intent.action.SEND`, `text/plain`.
  - 서버(`backend/app/services/share_intake_service.py`): `url`을 먼저 쓰고, 없으면 `raw_text`의 첫 URL을 쓴다. `/share/` 단축 URL은 리다이렉트를 따라가 정규화한다.
    테스트에는 `https://www.instagram.com/reel/ABC/?igsh=x` 형태가 쓰인다(`backend/tests/api/test_contents.py`).
- 공유 시트로 캡션 본문이나 미디어 파일이 같이 오는지는 실기기에서 페이로드를 기록해 봐야 확정할 수 있다.

## 확인하지 못한 사항

- Meta oEmbed Read 기능의 앱 검수·비즈니스 인증 요건이 2026-05-15 "토큰 없이 호출 가능" 변경 뒤에도 적용되는지. 토큰 없는 호출의 요청 한도가 시간당 1,000회 그대로인지.
- oEmbed `title`(캡션) 필드의 정확한 제거 시점.
- Business Discovery로 얻은 캡션·미디어를 AI 요약에 쓰는 것이 "permitted purposes"에 해당하는지. 운영자 계정 토큰 하나로 서비스 사용자의 요청을 처리해도 되는지.
- og:description의 긴 캡션 잘림 규칙, 캐러셀의 og:image 선택, 릴스에서 og:video가 빠지는 정확한 조건.
- 운영 서버(데이터센터 IP)에서 요청할 때의 로그인 벽·차단·요청 한도.
- Gemini URL context와 외부 URL 입력이 instagram.com 페이지나 cdninstagram.com 미디어를 실제로 가져오는지, 그 페처의 UA와 robots.txt 준수 여부. API 키 비용 문제로 호출 실험은 하지 않았다.
- 2027-01-20 시행 예정인 새 Instagram 이용 약관의 변경 내용.
- Instagram 앱이 iOS·Android 공유 시트로 넘기는 실제 페이로드(URL·텍스트·`igsh` 파라미터·미디어 포함 여부).
