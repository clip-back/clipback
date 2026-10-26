"""Independent private listener. It never starts the public API lifespan or workers."""

import asyncio
import hashlib
import secrets

from fastapi import Depends, FastAPI, Header, HTTPException, Response
from pydantic import BaseModel, Field

from app.core.operator_source_config import SourceSettings
from app.integrations.operator_source import SourceError, SourceReader


class OriginalRead(BaseModel):
    storage_key: str = Field(min_length=1, max_length=1024)


def create_operator_app(config=None, *, maintenance=None):
    config = config or SourceSettings()
    reader = SourceReader(config)
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)

    async def authorize(authorization: str = Header(default=""),
                        x_source_id: str = Header(default="")):
        expected = "Bearer " + config.operator_read_key.get_secret_value()
        if not secrets.compare_digest(authorization.encode(), expected.encode()):
            raise HTTPException(403, detail="operator_forbidden")
        if x_source_id != config.operator_source_id:
            raise HTTPException(409, detail="source_identity_mismatch")

    async def source_call(call, *args):
        try:
            return await asyncio.to_thread(call, *args)
        except SourceError as exc:
            raise HTTPException(exc.status, detail=exc.code) from None

    @app.get("/source", dependencies=[Depends(authorize)])
    async def identify():
        return await source_call(reader.identify)

    @app.post("/source/read", dependencies=[Depends(authorize)])
    async def read(body: OriginalRead):
        content = await source_call(reader.read, body.storage_key)
        return Response(content, media_type="application/octet-stream", headers={
            "X-Source-ID": config.operator_source_id,
            "X-Content-Size": str(len(content)),
            "X-Content-SHA256": hashlib.sha256(content).hexdigest(),
            "Cache-Control": "no-store",
        })

    from app.api.operator_maintenance import install_control
    install_control(app, config, maintenance)
    return app
