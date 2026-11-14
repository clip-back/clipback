"""Raw ASGI request body limit: reject by Content-Length before reading, else while receiving."""
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse

MIB = 1024 * 1024


class BodySizeLimitMiddleware:
    def __init__(self, app, upload_path, screenshot_max_bytes):
        self.app = app
        self.upload_path = upload_path
        # The upload keeps its existing image error so released apps show the same message.
        self.upload = (screenshot_max_bytes + MIB,
                       {"code": "image_file_too_large", "limit_bytes": screenshot_max_bytes})
        self.default = (MIB, {"code": "request_body_too_large", "limit_bytes": MIB})

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        limit, detail = self.upload if scope["path"] == self.upload_path else self.default
        # uvicorn rejects non-numeric Content-Length with 400 before the app is called.
        declared = dict(scope["headers"]).get(b"content-length")
        if declared is not None and int(declared) > limit:
            return await JSONResponse({"detail": detail}, status_code=413)(scope, receive, send)
        received = 0

        async def limited_receive():
            nonlocal received
            message = await receive()
            received += len(message.get("body", b""))
            if received > limit:
                raise HTTPException(413, detail=detail)
            return message

        await self.app(scope, limited_receive, send)
