"""Loopback-only HTTP fixtures for Dart + both native share implementations.

No external requests, tokens or provider credentials. Run with Python 3.11+.
POST /__test/control sets next_save_status/save_delay_seconds/lose_response.
GET /__test/state exposes fixture counts for repeatable UI assertions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import threading
import time
from datetime import datetime, timedelta, timezone
from email.parser import BytesParser
from email.policy import default
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

CATEGORY = {"id": 99, "name": "미분류", "color": "#B5BDC3", "is_default": True}
LOCK = threading.Lock()
RECEIPTS: dict[str, tuple[str, dict]] = {}
CONTROL: dict = {}


def content(ident: int, url: str | None = None) -> dict:
    return {
        "id": ident, "categories": [CATEGORY], "tags": [], "assets": [],
        "content_type": "link" if url else "screenshot",
        "source": "youtube" if url else "screenshot",
        "title": f"공유 확인 콘텐츠 {ident}", "summary": "로컬 테스트 서버에서 저장한 항목입니다.",
        "original_url": url, "is_favorite": False, "summary_status": "not_requested",
        "saved_at": datetime.now(timezone.utc).isoformat(), "last_viewed_at": None,
    }


RECORDS = [content(i, f"https://www.youtube.com/watch?v=dQw4w9WgXcQ&fixture={i}")
           for i in range(90, 0, -1)]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, value=None, status=200):
        body = json.dumps(value, ensure_ascii=False).encode() if value is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.removeprefix("/api/v1")
        query = parse_qs(parsed.query)
        if path == "/__test/state":
            return self.reply({"saved": len(RECEIPTS), "records": len(RECORDS)})
        if path == "/users/me":
            return self.reply({"id": 7, "display_name": "공유 테스트 계정", "email": None,
                               "is_guest": True, "linked_providers": [],
                               "created_at": "2026-10-12T00:00:00Z"})
        if path == "/users/me/stats":
            return self.reply({"saved_count": len(RECORDS), "reopened_count": 0})
        if path == "/categories":
            return self.reply([{**CATEGORY, "content_count": len(RECORDS)}])
        if path == "/feed":
            records = list(RECORDS)
            term = query.get("q", [""])[0]
            records = [row for row in records if term in row["title"]]
            if query.get("is_favorite") == ["true"]:
                records = []
            offset = int(query.get("cursor", [0])[0])
            limit = int(query.get("limit", [20])[0])
            end = offset + limit
            return self.reply({"items": records[offset:end],
                               "next_cursor": str(end) if end < len(records) else None})
        if path.startswith("/contents/"):
            row = next((row for row in RECORDS if str(row["id"]) == path.split("/")[-1]), None)
            return self.reply(row or {"detail": "없는 테스트 항목"}, 200 if row else 404)
        return self.reply({"detail": "Unsupported fixture route"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path.removeprefix("/api/v1")
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if path == "/__test/control":
            with LOCK:
                CONTROL.update(json.loads(body))
            return self.reply({"ok": True})
        if path in ("/auth/guest", "/auth/refresh") or path.startswith("/auth/social/"):
            return self.reply({"access_token": "local-share-fixture-access",
                               "refresh_token": "local-share-fixture-refresh", "expires_in": 3600,
                               "refresh_expires_in": 86400, "is_new_user": False}, 201)
        if path == "/auth/share-credential":
            return self.reply({"share_token": "local-share-fixture-credential", "user_id": 7,
                               "session_id": 11,
                               "expires_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()})
        if path == "/auth/logout":
            return self.reply(status=204)
        if path.endswith("/view") or path == "/metrics/events":
            return self.reply({})
        if path not in ("/contents/share", "/uploads/screenshots", "/contents"):
            return self.reply({"detail": "Unsupported fixture route"}, 404)
        if not self.headers.get("Authorization", "").startswith("Bearer "):
            return self.reply({"detail": "본앱에서 로그인 상태를 확인해 주세요."}, 401)
        key = self.headers.get("Idempotency-Key", "")
        value = json.loads(body) if "application/json" in self.headers.get("Content-Type", "") else {}
        fingerprint_input = (json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
                             if "application/json" in self.headers.get("Content-Type", "") else body)
        if path == "/uploads/screenshots":
            message = BytesParser(policy=default).parsebytes(
                b"Content-Type: " + self.headers["Content-Type"].encode() + b"\r\n\r\n" + body)
            parts = [(part.get_param("name", header="content-disposition"), part.get_payload(decode=True))
                     for part in message.iter_parts()]
            fingerprint_input = b"".join((name or "").encode() + data for name, data in parts)
        fingerprint = hashlib.sha256(path.encode() + fingerprint_input).hexdigest()
        with LOCK:
            status = CONTROL.pop("next_save_status", 201)
            detail = CONTROL.pop("next_save_detail", None)
            delay = CONTROL.pop("save_delay_seconds", 0)
            lose = CONTROL.pop("lose_response", False)
            if key in RECEIPTS:
                old_hash, row = RECEIPTS[key]
                return self.reply(row if old_hash == fingerprint else {"detail": "공유 입력이 달라졌어요."},
                                  201 if old_hash == fingerprint else 409)
            if status != 201:
                return self.reply({"detail": detail if detail is not None else (
                    "본앱에서 로그인 상태를 확인해 주세요." if status == 401
                    else "테스트 저장 실패. 다시 시도해 주세요.")}, status)
            row = content(1000 + len(RECEIPTS), value.get("url") or value.get("raw_text"))
            RECORDS.insert(0, row)
            if key:
                RECEIPTS[key] = (fingerprint, row)
        if delay:
            time.sleep(delay)
        if lose:
            self.close_connection = True
            return
        return self.reply(row, 201)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=18765)
    args = parser.parse_args()
    print(f"Local share fixtures ready on 127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
