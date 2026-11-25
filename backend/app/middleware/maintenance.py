"""Raw ASGI admission spans streaming and response background completion."""
from starlette.responses import JSONResponse

from app.services.maintenance import MaintenanceAdmissionError


class MaintenanceMiddleware:
    def __init__(self, app, state, prefix):
        self.app, self.state = app, state
        self.allowed = {
            prefix + path for path in ("/health", "/health/ready", "/health/ai-consent")
        }

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("path") in self.allowed:
            return await self.app(scope, receive, send)
        try:
            async with self.state.maintenance.operation("http"):
                await self.app(scope, receive, send)
        except MaintenanceAdmissionError:
            await JSONResponse({"detail": {"code": "service_maintenance"}}, status_code=503)(
                scope, receive, send)
