# Clipback Flutter Share Receiver

Instagram 공유 시트에서 실제로 전달되는 Android share payload를 확인하고,
Clipback backend의 `POST /api/v1/contents/share`로 보내는 테스트용 Flutter 앱입니다.

## What It Tests

- Android `ACTION_SEND`, `ACTION_SEND_MULTIPLE`
- `Intent.EXTRA_TEXT`, `EXTRA_SUBJECT`, `EXTRA_TITLE`
- 공유 stream URI metadata
- Android referrer 기반 source app 추정
- Backend guest token 자동 발급 및 Bearer 인증
- Backend `/api/v1/contents/share` 저장 요청

이 앱은 테스트 harness입니다. production Flutter 앱 구조나 디자인을 목표로 하지 않습니다.

## Run Backend

실기기에서 접근하려면 backend를 `0.0.0.0`으로 실행합니다.

```bash
docker compose up -d postgres

cd backend
source .venv/bin/activate
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --reload
```

## Backend URL

앱 화면에서 backend base URL을 입력합니다.

```text
Android Emulator: http://10.0.2.2:8000
Physical Device:  http://<your-mac-lan-ip>:8000
```

Mac의 Wi-Fi IP는 아래 명령으로 확인할 수 있습니다.

```bash
ipconfig getifaddr en0
```

## Run App

```bash
cd tools/share_receiver_flutter
flutter run
```

## Instagram Test Flow

1. Android 기기에 Instagram과 이 테스트 앱을 설치합니다.
2. Instagram 게시글 또는 Reel에서 공유 버튼을 누릅니다.
3. 공유 대상에서 `Clipback Share Receiver`를 선택합니다.
4. 앱 화면에서 raw payload, 추출 URL, attachment metadata를 확인합니다.
5. `Send to Backend` 버튼을 누르면 guest token을 자동 발급하고
   `/api/v1/contents/share` 저장을 확인합니다.

## Notes

- Instagram이 항상 URL을 주는 것은 아닐 수 있습니다.
- sender package/referrer는 Android 버전과 공유 방식에 따라 비어 있을 수 있습니다.
- image/video stream은 URI metadata만 표시하고 업로드하지 않습니다.
- guest token은 테스트 앱 실행 중 메모리에만 유지하며 refresh하지 않습니다.
- iOS Share Extension은 별도 구현이 필요합니다.
