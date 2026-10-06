async def request(api, method, path, *, status=200, **kwargs):
    response = await api.request(method, f"/api/v1/{path}", **kwargs)
    assert response.status_code == status, response.text
    return response.json() if response.content else None


async def guest(api):
    tokens = await request(api, "POST", "auth/guest", status=201)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    user = await request(api, "GET", "users/me", headers=headers)
    return headers, tokens, user


async def link(api, headers, **overrides):
    payload = {"original_url": "https://example.com/article", **overrides}
    return await request(api, "POST", "contents", headers=headers, json=payload, status=201)
