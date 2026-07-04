class MetadataClient:
    async def extract_from_url(self, url: str) -> dict[str, str | None]:
        return {"url": url, "title": None, "description": None, "source": None}

