"""Executed inside the running API container by check_deployment.py, not pytest."""

import asyncio
import base64
import json
import os
import urllib.request

from sqlalchemy import text

from app.core.config import settings
from app.db.session import AsyncSessionLocal
from app.integrations.storage_client import LocalStorageClient
from app.models.content_asset import AssetType, ContentAsset

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="
)


def request(path, token=None, payload=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        f"http://127.0.0.1:{os.environ['PORT']}/api/v1/{path}",
        headers=headers,
        data=json.dumps(payload).encode() if payload is not None else None,
    )
    with urllib.request.urlopen(req, timeout=5) as response:
        return response.read()


async def seed():
    tokens = json.loads(request("auth/guest", payload={}))
    token = tokens["access_token"]
    categories = json.loads(request("categories", token))
    category = next(item for item in categories if item["name"] != "미분류")
    content = json.loads(
        request(
            "contents",
            token,
            {
                "content_type": "screenshot",
                "source": "screenshot",
                "title": "Persistence check",
                "category_ids": [category["id"]],
            },
        )
    )
    storage_key = "deployment-check/screenshot.png"
    # Avoid external OCR: prepare the corresponding asset using the real schema/storage.
    async with AsyncSessionLocal() as session:
        asset = ContentAsset(
            content_id=content["id"],
            asset_type=AssetType.SCREENSHOT,
            storage_key=storage_key,
            mime_type="image/png",
        )
        session.add(asset)
        await session.flush()
        asset_id = asset.id
        await session.commit()
    await LocalStorageClient(settings.storage_root).save_file(storage_key, PNG)
    return {
        "token": token,
        "content_id": content["id"],
        "asset_id": asset_id,
        "saved_at": content["saved_at"],
    }


async def verify(state):
    assert json.loads(request("health/ready")) == {"status": "ok"}
    content = json.loads(request(f"contents/{state['content_id']}", state["token"]))
    assert content["title"] == "Persistence check"
    assert content["saved_at"] == state["saved_at"]
    assert content["assets"][0]["id"] == state["asset_id"]
    assert request(f"uploads/assets/{state['asset_id']}", state["token"]) == PNG
    async with AsyncSessionLocal() as session:
        assert await session.scalar(text("SELECT count(*) FROM users")) == 1
    return {"verified": True}


if __name__ == "__main__":
    import sys

    state = json.loads(sys.argv[1]) if len(sys.argv) > 1 else None
    print(json.dumps(asyncio.run(verify(state) if state else seed())))
